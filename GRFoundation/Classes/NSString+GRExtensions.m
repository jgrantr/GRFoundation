//
//  NSString+GRExtensions.m
//  GRFoundation
//
//  Created by Grant Robinson on 8/4/18.
//

#import "NSString+GRExtensions.h"
#import "NSData+GRExtensions.h"

@implementation NSString (GRExtensions)

- (NSString *) hmacSHA1UsingSecret:(NSData *)secret {
	return [[[self dataUsingEncoding:NSUTF8StringEncoding] hmacSHA1UsingSecret:secret] base64EncodedStringWithOptions:0];
}

@end
