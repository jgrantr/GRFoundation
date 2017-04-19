//
//  GROMapper.m
//  Pods
//
//  Created by Grant Robinson on 4/15/17.
//
//

#import "GROMapper.h"
#import <objc/runtime.h>

#import "Logging.h"

#define PROPERTY_MAP_PREFIX @"GROMapperPropertyFor_"
#define ARRAY_CLASS_PREFIX @"GROMapperArrayClassFor_"
#define CONVERTER_BLOCK_PREFIX @"GROMapperConvertBlockFor_"
#define CUSTOM_MAPPING_PREFIX @"GROMapperCustomMappingBlockFor"

typedef NS_ENUM(NSInteger, GROJsonType) {
	GROJsonTypeUnknown,
	GROJsonTypeObject,
	GROJsonTypeArray,
	GROJsonTypeString,
	GROJsonTypeTypeNumber,
	GROJsonTypeNull,
};

typedef NS_ENUM(NSInteger, GROTargetType) {
	GROTargetTypeUnknown,
	GROTargetTypeCustomObject,
	GROTargetTypeArray,
	GROTargetTypeBasicOrWrappedValue,
};

static GROJsonType jsonType(id source) {
	if ([source isKindOfClass:[NSString class]]) {
		return GROJsonTypeString;
	}
	else if ([source isKindOfClass:[NSNumber class]]) {
		return GROJsonTypeTypeNumber;
	}
	else if ([source isKindOfClass:[NSDictionary class]]) {
		return GROJsonTypeObject;
	}
	else if ([source isKindOfClass:[NSArray class]]) {
		return GROJsonTypeArray;
	}
	else if (source == (id)[NSNull null]) {
		return GROJsonTypeNull;
	}
	else {
		return GROJsonTypeUnknown;
	}
}

static GROTargetType targetType(id source) {
	if ([source isKindOfClass:[NSDictionary class]]) {
		return GROTargetTypeCustomObject;
	}
	else if ([source isKindOfClass:[NSArray class]]) {
		return GROTargetTypeArray;
	}
	else {
		return GROTargetTypeBasicOrWrappedValue;
	}
}

static NSError * errorWithCodeAndDescription(NSInteger code, NSString *format, ...) {
	va_list varArgs;
	va_start(varArgs, format);
	NSString *str = [[NSString alloc] initWithFormat:format arguments:varArgs];
	va_end(varArgs);
	
	return [NSError errorWithDomain:@"GROMapper" code:code userInfo:@{NSLocalizedDescriptionKey: str}];
}

static Class classForProperty(objc_property_t property) {
	if (property != NULL) {
		const char *attr = property_getAttributes(property);
		// per the Apple doc, the attribute string will start with a T and the 2nd character is the 'encode' type
		// which for an Objective-C object will be '@'
		if (attr[1] == '@' && attr[2] == '"') {
			/**
			  * it is an object type (not a block, which is encoded as 'T@?')
			  * grab the type name from the attributes
			  *
			  * String will look like this: T@"<class name>"
			  */
			int startPos =  3, endPos = startPos;
			while (attr[endPos] != '\0' && attr[endPos] != '"') {
				endPos++;
			}
			return NSClassFromString([[NSString alloc] initWithBytes:attr+startPos length:endPos - startPos encoding:NSUTF8StringEncoding]);
		}
		// if we get to here, it was either an Objective-C Block, or a non-object type (struct, etc)
		return nil;
	}
	return nil;
}

static Class classForKeyWithTarget(NSString *key, id target) {
	Class targetClass = [target class];
	SEL selector = NSSelectorFromString([ARRAY_CLASS_PREFIX stringByAppendingString:key]);
	if (class_respondsToSelector(targetClass, selector)) {
		IMP imp = [target methodForSelector:selector];
		Class (*func)(id, SEL) = (void *)imp;
		Class classForKey = func(target, selector);
		return classForKey;
	}
	return nil;
}

@implementation GROMapper

@synthesize ignoreNulls;

- (instancetype) init {
	self = [super init];
	if (self) {
		ignoreNulls = YES;
	}
	return self;
}

+ (instancetype) mapper {
	return [[GROMapper alloc] init];
}

+ (id) map:(id)source to:(Class)clazz error:(NSError *__autoreleasing *)error {
	return [[self mapper] mapSource:source to:clazz error:error];
}

- (id) mapSource:(id)source to:(Class)clazz error:(NSError *__autoreleasing *)error {
	id rootObj = nil;
	@try {
		if (source == nil) @throw errorWithCodeAndDescription(-1, @"source JSON object is nil");
		if (clazz == nil) @throw errorWithCodeAndDescription(-2, @"Class to map to cannot be nil");
		switch (jsonType(source)) {
			case GROJsonTypeUnknown:
				break;
			case GROJsonTypeObject:
				rootObj = [[clazz alloc] init];
				[self map:source toObject:rootObj];
				break;
			case GROJsonTypeArray:
			{
				NSArray *sourceArray = source;
				if (sourceArray.count == 0) {
					rootObj = [NSArray array];
				}
				else if (jsonType(sourceArray.firstObject) == GROJsonTypeObject) {
					rootObj = [NSMutableArray arrayWithCapacity:sourceArray.count];
					[self map:sourceArray toArray:rootObj withClass:clazz];
				}
				else {
					// do nothing - it is an array of basic types (or should be)
					rootObj = source;
				}
				break;
			}
			case GROJsonTypeString:
			case GROJsonTypeTypeNumber:
			case GROJsonTypeNull:
				@throw errorWithCodeAndDescription(-3, @"Cannot map a JSON basic type (string, number, etc).  Root of the JSON must be an array or object.");
		}
	} @catch (NSError *thrown) {
		if (error) {
			*error = thrown;
		}
		rootObj = nil;
	} @finally {
		
	}
	return rootObj;
}

- (void) map:(NSDictionary <NSString*,id> *)source toObject:(id)target {
	Class targetClass = [target class];
	id nullInstance = [NSNull null];
	for (NSString *key in source.allKeys) {
		@autoreleasepool {
			id origValue = source[key];
			if (ignoreNulls && origValue == nullInstance) {
				// we will ignore it at the end, short-circuit the whole process and move on
				continue;
			}
			SEL customMappingSelector = NSSelectorFromString([CUSTOM_MAPPING_PREFIX stringByAppendingString:key]);
			if (class_respondsToSelector(targetClass, customMappingSelector)) {
				IMP imp = class_getMethodImplementation(targetClass, customMappingSelector);
				id (*func)(id, SEL) = (void *)imp;
				void (^customMappingBlock)(id original) = func(target, customMappingSelector);
				if (customMappingBlock) {
					customMappingBlock(origValue);
					continue;
				}

			}
			// first, grab the property using only the key
			NSString *propertyName = key;
			objc_property_t property = class_getProperty(targetClass, key.UTF8String);
			if (!property) {
				// if that is not found, try a mapping
				SEL selector = NSSelectorFromString([PROPERTY_MAP_PREFIX stringByAppendingString:key]);
				if (class_respondsToSelector(targetClass, selector)) {
					IMP imp = class_getMethodImplementation(targetClass, selector);
					NSString* (*func)(id, SEL) = (void *)imp;
					propertyName = func(target, selector);
					property = class_getProperty(targetClass, propertyName.UTF8String);
				}
			}
			if (property == NULL) {
				// if there is no property, ignore it and move on.
				continue;
			}
			id actualValue = origValue;
			SEL conversionSelector = NSSelectorFromString([CONVERTER_BLOCK_PREFIX stringByAppendingString:key]);
			if (class_respondsToSelector(targetClass, conversionSelector)) {
				IMP imp = class_getMethodImplementation(targetClass, conversionSelector);
				id (*func)(id, SEL) = (void *)imp;
				id (^converterBlock)(id original) = func(target, conversionSelector);
				if (converterBlock) {
					actualValue = converterBlock(origValue);
				}
			}
			id valueToSet = nil;
			switch (targetType(actualValue)) {
				case GROTargetTypeUnknown:
					// can't hit this case currently
					break;
				case GROTargetTypeCustomObject:
				{
					Class propertyClass = classForProperty(property);
					if (!propertyClass) {
						// we have a custom object (aka a dict) and the property we are setting has no class
						// which means it is either a block or a primitive type, no mapping is therefore possible
						DDLogWarn(@"cannot map value of type '%@' to a block or primitive type for property %@", NSStringFromClass([actualValue class]), propertyName);
					}
					else if ([actualValue isKindOfClass:propertyClass]) {
						// the value we are setting matches the property's class, just do a direct set
						valueToSet = actualValue;
					}
					else {
						valueToSet = [[propertyClass alloc] init];
						[self map:actualValue toObject:valueToSet];
					}
					break;
				}
				case GROTargetTypeArray:
				{
					NSArray *array = actualValue;
					if (array.count == 0) {
						valueToSet = [NSArray array];
					}
					else if (jsonType(array.firstObject) == GROJsonTypeObject) {
						valueToSet = [NSMutableArray arrayWithCapacity:array.count];
						Class arrayClass = classForKeyWithTarget(key, target);
						[self map:actualValue toArray:valueToSet withClass:arrayClass];
					}
					else {
						// do nothing - it is an array of basic (or wrapped) types (or should be)
						valueToSet = actualValue;
					}
					break;
				}
				case GROTargetTypeBasicOrWrappedValue:
				{
					break;
				}
			}
			[target setValue:valueToSet forKey:propertyName];
		}
	}
}

- (void) map:(NSArray *)source toArray:(NSMutableArray *)array withClass:(Class)clazz {
	if (source == nil) @throw errorWithCodeAndDescription(-5, @"source array is nil");
	if (array == nil) @throw errorWithCodeAndDescription(-6, @"target array is nil");
	for (id item in source) {
		id targetItem = [[clazz alloc] init];
		if (!targetItem) @throw errorWithCodeAndDescription(-7, @"could not create object from class: %@", clazz);
		[array addObject:targetItem];
		[self map:item toObject:targetItem];
	}
}

@end
