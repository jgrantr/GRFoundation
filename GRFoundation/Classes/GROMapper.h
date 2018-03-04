//
//  GROMapper.h
//  Pods
//
//  Created by Grant Robinson on 4/15/17.
//
//

#import <Foundation/Foundation.h>

extern NSString *GROMapperErrorDomain;

typedef NS_ENUM(NSInteger, GROMapperErrorCode) {
	GROMapperErrorCodeUnknown,
	GROMapperErrorCodeSourceJSONIsNil,
	GROMapperErrorCodeMappingClassIsNil,
	GROMapperErrorCodeInvalidRootJSONObject,
	GROMapperErrorCodeSourceArrayIsNil,
	GROMapperErrorCodeTargetArrayIsNil,
	GROMapperErrorCodeCouldNotCreateInstanceOfMappedClass,
	/** The error that is thrown when a key value coding operation fails. The error's user info dictionary will contain at least two entries:
	 - @"NSTargetObjectUserInfoKey": the receiver of the failed KVC message.
	 - @"NSUnknownUserInfoKey": the key that was used in the failed KVC message.
	 
	 */
	GROMapperErrorCodeNotKeyValueCodingCompliant,
	GROMapperErrorCodeGeneralError,
	/** The source object to conver to JSON is nil */
	GROMapperErrorCodeSourceObjectIsNil,
};

// mapping macros for dict -> object

#define GROMap(key, property) XGROMap(key, property)
#define XGROMap(key, property) -(NSString*) GROMapperPropertyFor_##key { return @#property; } - (NSString *) GROMapperKeyFor_##property { return @#key; }

#define GROArrayClass(property, clazz) XGROArrayClass(property, clazz)
#define XGROArrayClass(property, clazz) -(Class) GROMapperArrayClassFor_##property { return [clazz class]; }

#define GROConvertValue(key, block) -(id(^)(id)) GROMapperConvertBlockFor_##key { return block; }

#define GROCustomMapping(key, block) -(void(^)(id)) GROMapperCustomMappingBlockFor_##key { return block; }

#define GROConvertToJSON(property, block) XGROConvertToJSON(property, block)
#define XGROConvertToJSON(property, block) -(id(^)(void)) GROMapperConvertToJSONFor_##property { return block; }


/**
  * Class for mapping a JSON object (aka, an NSDictionary or NSArray) to an Objective-C object.
  *
  * Also provides the revers-mapping, and can take a KVC-compliant Objective-C object and turn it into an equivalent NSDictionary
  * that will then be suitable for serializing to JSON.
  *
  * Please not that because of the pre-processor macros, if you wish to return a dictionary literal (or some other piece of code in your block that contains commas)
  * from a GROConvertValue or GROConvertToJSON block, you will need to encapsulate it in parantheses, like this:
  *
  * GROConvertToJSON(myProperty, ^id {
  *     return (@{@"value1" : @(1), @"value2" : @(2)});
  * })
  *
  */
@interface GROMapper : NSObject

@property (nonatomic) BOOL ignoreNulls;

+ (instancetype) mapper;

+ (id) map:(id)object to:(Class)clazz error:(NSError *__autoreleasing *)error;

+ (id) jsonObjectFrom:(id)object error:(NSError *__autoreleasing *)error;

- (id) mapSource:(id)object to:(Class)clazz error:(NSError *__autoreleasing *)error;

- (void) map:(NSDictionary <NSString*,id> *)source toObject:(id)target;

- (id) jsonObjectFor:(id)object error:(NSError *__autoreleasing *)error;

@end
