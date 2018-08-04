//
//  NSData+GRExtensions.m
//  GRFoundation
//
//  Created by Grant Robinson on 8/4/18.
//

#import "NSData+GRExtensions.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation NSData (GRExtensions)

- (NSMutableData *) hmacSHA1UsingSecret:(NSData *)secret {
	NSMutableData *result = [NSMutableData dataWithCapacity:CC_SHA1_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA1, [secret bytes], secret.length, [self bytes], self.length, [result mutableBytes]);
	return result;
}

@end
