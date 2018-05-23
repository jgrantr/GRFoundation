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

// mapping macros for object -> dict

#define GROConvertToJSON(property, block) XGROConvertToJSON(property, block)
#define XGROConvertToJSON(property, block) -(id(^)(void)) GROMapperConvertToJSONFor_##property { return block; }


/**
 A protocol for configuring only certain properties of a class to be included or excluded when converting to JSON.
 You should never define both of these methods for a given class. excludePropertiesFromJSON will be preferred and used if both are defined.
 
 Thie protocol can either be adopted formally, or informally.  Either way, the selectors will be called if they exist.
 */
@protocol GROMapperConfig <NSObject>

@optional

/**
 Return a set of properties that should be excluded when mapping to JSON.

 @return the set of property names to exclude from the JSON
 */
+ (NSSet<NSString*> *) excludePropertiesFromJSON;

/**
 Return a set of properties that should be included in the JSON when performing a mapping.  If this method returns non-nil, ONLY
 the properties in this set will be included (which is sometimes easier when you have only 1 or two properties you want to include.

 @return the set of property names to include in the JSON
 */
+ (NSSet<NSString*> *) includePropertiesInJSON;

@end

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


/**
 Whether to ignore null values from the JSON object.  Default value is YES.
 */
@property (nonatomic) BOOL ignoreNulls;

+ (instancetype) mapper;


/**
 Map a JSON dictionary created from NSJSONSerialization to a KVC-compliant object

 @param object the dictionary or array to map
 @param clazz the class object to use for the converted object
 @param error an out pointer that holds any error encountered during conversion
 @return an instance of the clazz object passed in, or nil if an error occurs during mapping
 */
+ (id) map:(id)object to:(Class)clazz error:(NSError *__autoreleasing *)error;


/**
 Create a dictionary representation of a KVC-compliant object.  The mapping is as follows:
 
 C primitives (BOOL, int, double, etc) -> NSNumber
 const char * -> NSString
 NSString -> NSString
 NSNumber -> NSNumber
 id -> NSDictionary (property names are keys, property values mapped using above rules)
 
 If the property of an object does not fall into one of the above types, it needs a custom conversion block to be included in the serialization

 @param object the object to convert
 @param error an out pointer that holds an error encountered during conversion
 @return a mutable dictionary or array (depending on the type of object passed in) that contains the converted object
 */
+ (id) jsonObjectFrom:(id)object error:(NSError *__autoreleasing *)error;


/**
 Maps a source object (should be either a dictionary or an array) to an instance of clazz.

 @param object the dictionary or array to map
 @param clazz the class object to use for the converted object
 @param error an out pointer that holds any error encountered during conversion
 @return an instance of the clazz object passed in, or nil if an error occurs during mapping
 */
- (id) mapSource:(id)object to:(Class)clazz error:(NSError *__autoreleasing *)error;

- (void) map:(NSDictionary <NSString*,id> *)source toObject:(id)target;

- (id) jsonObjectFor:(id)object error:(NSError *__autoreleasing *)error;

@end
