//
//  GRImageMetadata.m
//  GRFoundation
//
//  Created by Grant Robinson on 3/23/19.
//

#import "GRImageMetadata.h"

#import "Logging.h"

static BOOL isValidType(id obj) {
	static dispatch_once_t onceToken;
	static NSSet<Class> *lookup;
	dispatch_once(&onceToken, ^{
		lookup = [NSSet setWithArray:@[
			[NSNumber class],
			[NSString class],
			[NSDictionary class],
			[NSArray class],
		]];
	});
	for (Class clazz in lookup) {
		if ([obj isKindOfClass:clazz]) {
			return YES;
		}
	}
	return NO;
}

@interface GRImageMetadata ()

@property (nonatomic, assign, nonnull) CGMutableImageMetadataRef metadata;

@end

@implementation GRImageMetadata

+ (instancetype) withMetadata:(CGImageMetadataRef)metadata {
	GRImageMetadata *obj = [[self alloc] init];
	CGMutableImageMetadataRef mutable = CGImageMetadataCreateMutableCopy(metadata);
	if (mutable != NULL) {
		obj.metadata = (CGMutableImageMetadataRef _Nonnull)mutable;
	}
	return obj;
}

- (void) dealloc {
	if (_metadata != NULL) {
		CFRelease(_metadata);
		_metadata = NULL;
	}
}

- (NSString *) description {
	return (__bridge_transfer NSString *)CFCopyDescription(_metadata);
}

- (id) objectForKeyedSubscript:(NSString *)key {
	NSString *value = (__bridge_transfer NSString *)CGImageMetadataCopyStringValueWithPath(_metadata, NULL, (__bridge CFStringRef)key);
	return value;
}

- (void) setObject:(id)obj forKeyedSubscript:(NSString *)key {
	if (!isValidType(obj)) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"object being set into a CGImageMetadataRef must be a string, number, array, or dictionary (passed in type was %@)", NSStringFromClass([obj class])] userInfo:@{}];
	}
	BOOL success = CGImageMetadataSetValueWithPath(_metadata, NULL, (__bridge CFStringRef)key, (__bridge CFTypeRef)obj);
	if (!success) {
		DDLogWarn(@"unable to set value '%@' for path '%@'", obj, key);
	}
}

- (void) enumerateTagsUsingBlock:(GRTagEnumerationBlock)block {
	[self enumerateTagsAtPath:nil recursive:NO usingBlock:block];
}

- (void) enumerateTagsAtPath:(NSString *)path usingBlock:(GRTagEnumerationBlock)block {
	[self enumerateTagsAtPath:path recursive:NO usingBlock:block];
}

- (void) enumerateTagsAtPath:(NSString *)path recursive:(BOOL)recursive usingBlock:(GRTagEnumerationBlock)block {
	NSDictionary *options = @{(NSString *)kCGImageMetadataEnumerateRecursively : @(recursive)};
	CGImageMetadataEnumerateTagsUsingBlock(self.metadata, (CFStringRef)path, (CFDictionaryRef)options, ^bool(CFStringRef  _Nonnull path, CGImageMetadataTagRef  _Nonnull tag) {
		NSString *name = (__bridge_transfer NSString *)CGImageMetadataTagCopyName(tag);
		id value = (__bridge_transfer id)CGImageMetadataTagCopyValue(tag);
		return block((__bridge NSString *)path, name, value);
	});
}

@end
