//
//  GROMapper.h
//  Pods
//
//  Created by Grant Robinson on 4/15/17.
//
//

#import <Foundation/Foundation.h>

#define GROMap(key, property) XGROMap(key, property)
#define XGROMap(key, property) -(NSString*) GROMapperPropertyFor_##key { return @#property; }

#define GROArrayClass(property, clazz) XGROArrayClass(property, clazz)
#define XGROArrayClass(property, clazz) -(Class) GROMapperArrayClassFor_##property { return [clazz class]; }

#define GROConvertValue(key, block) -(id(^)(id)) GROMapperConvertBlockFor_##key { return block; }

#define GROCustomMapping(key, block) -(void(^)(id)) GROMapperCustomMappingBlockFor_##key { return block; }

@interface GROMapper : NSObject

@property (nonatomic) BOOL ignoreNulls;

+ (instancetype) mapper;

+ (id) map:(id)object to:(Class)clazz error:(NSError *__autoreleasing *)error;

- (id) mapSource:(id)object to:(Class)clazz error:(NSError *__autoreleasing *)error;

@end
