//
//  GRURLBuilder.h
//
//  Created by Grant Robinson on 8/23/10.
//  Copyright 2010 Grant Robinson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GRURLBuilder;

@interface GRURLBuilder : NSObject <NSFastEnumeration>

+ (GRURLBuilder *) builder;
+ (GRURLBuilder *) builderWithBuilder:(GRURLBuilder *)builder;
+ (GRURLBuilder *) builderFromQueryString:(NSString *)queryString;
- (NSString *) urlString;
- (NSString *) jsonString;
- (NSUInteger) count;
- (void) addDictionary:(NSDictionary *)dict;
// use the new subscripting operators to add objects, like so:
// builder[@"myKey"] = myValue;
- (id) objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

- (void)enumerateKeysAndObjectsUsingBlock:(void (NS_NOESCAPE ^)(NSString *key, id obj, BOOL *stop))block;

@end
