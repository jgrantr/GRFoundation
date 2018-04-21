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

NSString *GROMapperErrorDomain = @"net.mr-r.GROMapper";


#define PROPERTY_MAP_PREFIX @"GROMapperPropertyFor_"
#define KEY_MAP_PREFIX @"GROMapperKeyFor_"
#define ARRAY_CLASS_PREFIX @"GROMapperArrayClassFor_"
#define CONVERTER_BLOCK_PREFIX @"GROMapperConvertBlockFor_"
#define CUSTOM_MAPPING_PREFIX @"GROMapperCustomMappingBlockFor_"
#define JSON_CONVERSION_PREFIX @"GROMapperConvertToJSONFor_"

typedef NS_ENUM(NSInteger, GROJsonType) {
	GROJsonTypeUnknown,
	GROJsonTypeObject,
	GROJsonTypeArray,
	GROJsonTypeString,
	GROJsonTypeNumber,
	GROJsonTypeNull,
};

typedef NS_ENUM(NSInteger, GROSourceType) {
	GROSourceTypeUnknown,
	GROSourceTypeDictionary,
	GROSourceTypeArray,
	GROSourceTypeCustomObject,
	GROSourceTypeString,
	GROSourceTypeNumber,
	GROSourceTypePrimitive,
	GROSourceTypeNull,
	GROSourceTypeNeedsConversionBlock,
	GROSourceTypeInconvertibleValue,
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
		return GROJsonTypeNumber;
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

static GROSourceType sourceObjectType(id source) {
	if (source == nil) {
		return GROSourceTypeNull;
	}
	if ([source isKindOfClass:[NSString class]]) {
		return GROSourceTypeString;
	}
	else if ([source isKindOfClass:[NSNumber class]]) {
		return GROSourceTypeNumber;
	}
	else if (source == [NSNull null]) {
		return GROSourceTypeNull;
	}
	else if ([source isKindOfClass:[NSArray class]]) {
		return GROSourceTypeArray;
	}
	else if ([source isKindOfClass:[NSDictionary class]]) {
		return GROSourceTypeDictionary;
	}
	return GROSourceTypeCustomObject;
}

static GROSourceType sourceTypeFromAttributes(const char *attr) {
	switch (attr[1]) {
		case 'v':
			// can't convert a void
			return GROSourceTypeInconvertibleValue;
			break;
		case '#':
			// can't convert a class object
			return GROSourceTypeInconvertibleValue;
			break;
		case ':':
			// can't convert a selector
			return GROSourceTypeInconvertibleValue;
			break;
		case '[':
		case '{':
		case '(':
			// look for a custom conversion block
			return GROSourceTypeNeedsConversionBlock;
			break;
		case 'b':
			// a bit-field, need a custom conversion block
			return GROSourceTypeNeedsConversionBlock;
			break;
		case '^':
			// a pointer to a type, not sure how we would convert that, unless it is with a custom conversion block
			return GROSourceTypeNeedsConversionBlock;
			break;
		case '?':
			// an unknown type
			return GROSourceTypeNeedsConversionBlock;
			break;
		case '@':
			if (attr[2] == '"' || attr[2] == ',') {
				// it is an object
				return GROSourceTypeCustomObject;
			}
			else if (attr[2] == '?') {
				// it is a block
				return GROSourceTypeInconvertibleValue;
			}
			else {
				// something else?
				return GROSourceTypeInconvertibleValue;
			}
			break;
	}
	// if we fall out of the switch, it is a primitive type that can/will be wrapped
	return GROSourceTypePrimitive;
}

static NSError * errorWithCodeAndDescription(NSInteger code, NSString *format, ...) {
	va_list varArgs;
	va_start(varArgs, format);
	NSString *str = [[NSString alloc] initWithFormat:format arguments:varArgs];
	va_end(varArgs);
	
	return [NSError errorWithDomain:GROMapperErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: str}];
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

+ (id) jsonObjectFrom:(id)object error:(NSError *__autoreleasing *)error {
	return [[self mapper] jsonObjectFor:object error:error];
}

- (id) mapSource:(id)source to:(Class)clazz error:(NSError *__autoreleasing *)error {
	id rootObj = nil;
	@try {
		if (source == nil) @throw errorWithCodeAndDescription(GROMapperErrorCodeSourceJSONIsNil, @"source JSON object is nil");
		if (clazz == nil) @throw errorWithCodeAndDescription(GROMapperErrorCodeMappingClassIsNil, @"Class to map to cannot be nil");
		
		switch (jsonType(source)) {
			case GROJsonTypeUnknown:
				@throw errorWithCodeAndDescription(GROMapperErrorCodeInvalidRootJSONObject, @"source object is an invalid JSON type (passed in %@)", source);
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
			case GROJsonTypeNumber:
				@throw errorWithCodeAndDescription(GROMapperErrorCodeInvalidRootJSONObject, @"Cannot map a JSON basic type (string, number, etc).  Root of the JSON must be an array or object.");
				break;
			case GROJsonTypeNull:
				// if they pass in null, the resulting object should map to nil
				break;
		}
	} @catch (NSError *thrown) {
		if (error) {
			*error = thrown;
		}
		rootObj = nil;
	} @catch (NSException *exception) {
		NSError *toRaise = nil;
		if ([exception.name isEqualToString:NSUndefinedKeyException]) {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
			userInfo[NSLocalizedDescriptionKey] = exception.reason;
			toRaise = [NSError errorWithDomain:GROMapperErrorDomain code:GROMapperErrorCodeNotKeyValueCodingCompliant userInfo:userInfo];
		}
		else {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
			userInfo[NSLocalizedDescriptionKey] = exception.reason;
			toRaise = [NSError errorWithDomain:GROMapperErrorDomain code:GROMapperErrorCodeGeneralError userInfo:userInfo];
		}
		if (error) {
			*error = toRaise;
		}
		rootObj = nil;
	}@finally {
		
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
						continue;
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
					valueToSet = actualValue;
					break;
				}
			}
			if (valueToSet || !ignoreNulls) {
				[target setValue:valueToSet forKey:propertyName];
			}
		}
	}
}

- (void) map:(NSArray *)source toArray:(NSMutableArray *)array withClass:(Class)clazz {
	if (source == nil) @throw errorWithCodeAndDescription(GROMapperErrorCodeSourceArrayIsNil, @"source array is nil");
	if (array == nil) @throw errorWithCodeAndDescription(GROMapperErrorCodeTargetArrayIsNil, @"target array is nil");
	for (id item in source) {
		id targetItem = [[clazz alloc] init];
		if (!targetItem) @throw errorWithCodeAndDescription(GROMapperErrorCodeCouldNotCreateInstanceOfMappedClass, @"could not create object from class: %@", clazz);
		[array addObject:targetItem];
		[self map:item toObject:targetItem];
	}
}

- (id) jsonObjectFor:(id)source error:(NSError *__autoreleasing *)error {
	id rootObj = nil;
	@try {
		if (source == nil) @throw  errorWithCodeAndDescription(GROMapperErrorCodeSourceObjectIsNil, @"object to convert to JSON is nil");
		
		rootObj = [self convertToJSON:source];
		
	} @catch (NSError *thrown) {
		if (error) {
			*error = thrown;
		}
		rootObj = nil;
	} @catch (NSException *exception) {
		NSError *toRaise = nil;
		if ([exception.name isEqualToString:NSUndefinedKeyException]) {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
			userInfo[NSLocalizedDescriptionKey] = exception.reason;
			toRaise = [NSError errorWithDomain:GROMapperErrorDomain code:GROMapperErrorCodeNotKeyValueCodingCompliant userInfo:userInfo];
		}
		else {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
			userInfo[NSLocalizedDescriptionKey] = exception.reason;
			toRaise = [NSError errorWithDomain:GROMapperErrorDomain code:GROMapperErrorCodeGeneralError userInfo:userInfo];
		}
		if (error) {
			*error = toRaise;
		}
		rootObj = nil;
	} @finally {
		
	}
	return rootObj;
}

- (id) convertToJSON:(id)source {
	id convertedObj = nil;
	switch (sourceObjectType(source)) {
		case GROSourceTypeUnknown:
			break;
		case GROSourceTypeDictionary:
		{
			NSDictionary *sourceDict = source;
			convertedObj = [NSMutableDictionary dictionaryWithCapacity:10];
			NSMutableDictionary *convertedDict = convertedObj;
			[sourceDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
				convertedDict[key] = [self convertToJSON:obj];
			}];
			break;
		}
		case GROSourceTypeArray:
		{
			NSArray *sourceArray = source;
			convertedObj = [NSMutableArray arrayWithCapacity:10];
			NSMutableArray *convertedArray = convertedObj;
			for (id object in sourceArray) {
				[convertedArray addObject:[self convertToJSON:object]];
			}
			break;
		}
		case GROSourceTypeCustomObject:
		{
			convertedObj = [self convertCustomObject:source];
			break;
		}
		case GROSourceTypeString:
			convertedObj = source;
			break;
		case GROSourceTypeNumber:
			convertedObj = source;
			break;
		case GROSourceTypePrimitive:
			break;
		case GROSourceTypeNull:
			convertedObj = [NSNull null];
			break;
		case GROSourceTypeNeedsConversionBlock:
			break;
		case GROSourceTypeInconvertibleValue:
			break;
	}
	return convertedObj;
}

- (NSMutableDictionary *) convertCustomObject:(id)customObj {
	Class customClass = [customObj class];
	unsigned int count = 0;
	objc_property_t *propList = class_copyPropertyList(customClass, &count);
	NSMutableDictionary *convertedObj = [NSMutableDictionary dictionaryWithCapacity:count];
	for (int i = 0; i < count; i++) {
		objc_property_t property = propList[i];
		const char *attr = property_getAttributes(property);
		NSString *propName = [NSString stringWithUTF8String:property_getName(property)];
		GROSourceType propType = sourceTypeFromAttributes(attr);
		if (propType == GROSourceTypeInconvertibleValue) {
			DDLogInfo(@"property '%@' (@encode-type '%s') from class '%@' cannot be converted to JSON", propName, attr, NSStringFromClass(customClass));
			continue;
		}
		NSString *key = propName;
		// first check to see if there should be a different name for this object in the JSON
		SEL selector = NSSelectorFromString([KEY_MAP_PREFIX stringByAppendingString:propName]);
		if ([customObj respondsToSelector:selector]) {
			IMP imp = class_getMethodImplementation(customClass, selector);
			NSString* (*func)(id, SEL) = (void *)imp;
			key = func(customObj, selector);
		}
		selector = NSSelectorFromString([JSON_CONVERSION_PREFIX stringByAppendingString:propName]);
		if ([customObj respondsToSelector:selector]) {
			IMP imp = class_getMethodImplementation(customClass, selector);
			id (*func)(id, SEL) = (void *)imp;
			id (^converterBlock)(void) = func(customObj, selector);
			if (converterBlock) {
				id value = converterBlock();
				if (value && jsonType(value) != GROJsonTypeUnknown) {
					convertedObj[key] = value;
				}
				else if (value) {
					DDLogWarn(@"converter block for '%@' returned an invalid JSON value ('%@') of type %@", propName, value, NSStringFromClass([value class]));
				}
			}
			else {
				DDLogWarn(@"converter block for '%@' didn't return a valid block, value will not be converted", propName);
			}
			continue;
		}
		else if (propType == GROSourceTypePrimitive) {
			convertedObj[key] = [customObj valueForKey:propName];
		}
		else if (propType == GROSourceTypeCustomObject) {
			convertedObj[key] = [self convertToJSON:[customObj valueForKey:propName]];
		}
		else if (propType == GROSourceTypeNeedsConversionBlock) {
			DDLogInfo(@"property '%@' with @encode-type '%s' will not be converted to JSON because no conversion block was specified", propName, attr);
		}
	}
	if (propList) {
		free(propList);
	}
	return convertedObj;
}

@end
