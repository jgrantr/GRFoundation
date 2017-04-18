//
//  GRJsonParser.h
//  Pods
//
//  Created by Grant Robinson on 4/18/17.
//
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, GRJsonParserState) {
	GRJPSRoot,
	GRJPSInObject,
	GRJPSInArray,
};

@interface GRJsonParser : NSObject

@property (nonatomic) BOOL ignoreNulls;

+ (id) JSONObjectFromData:(NSData *)data error:(NSError *__autoreleasing *)error;

@end
