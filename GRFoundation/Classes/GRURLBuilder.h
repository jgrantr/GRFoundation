//
//  GRURLBuilder.h
//
//  Created by Grant Robinson on 8/23/10.
//  Copyright 2010 Grant Robinson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GRURLBuilder;

@interface GRURLBuilder : NSObject

+ (GRURLBuilder *) builder;
+ (GRURLBuilder *) builderWithBuilder:(GRURLBuilder *)builder;
+ (GRURLBuilder *) builderFromQueryString:(NSString *)queryString;
- (NSString *) urlString;
- (NSString *) jsonString;
- (NSUInteger) count;
- (void) addDictionary:(NSDictionary *)dict;
// use the new subscripting operators to add objects, like so:
// builder[@"myKey"] = myValue;
- (id) objectForKeyedSubscript:(id <NSCopying>)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

@end
