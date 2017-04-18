//
//  GRJson.h
//  Pods
//
//  Created by Grant Robinson on 4/17/17.
//
//

#import <Foundation/Foundation.h>


@protocol GRJsonDelegate <NSObject>

@required
- (void) json_null;
- (void) json_bool:(BOOL)boolVal;
- (void) json_number:(const unsigned char *)numberVal length:(unsigned long)len;
- (void) json_string:(NSString *)strVal;
- (void) json_object_begin;
- (void) json_object_key:(NSString *)key;
- (void) json_object_end;
- (void) json_array_begin;
- (void) json_array_end;


@end


@interface GRJson : NSObject

- (instancetype) initWithData:(NSData *)data delegate:(id<GRJsonDelegate>)delegate;

@property (nonatomic, strong) NSData *data;
@property (nonatomic, weak) id<GRJsonDelegate> delegate;

- (BOOL) parse:(NSError *__autoreleasing *)error;

@end
