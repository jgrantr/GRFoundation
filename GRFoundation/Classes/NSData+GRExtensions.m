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
	unsigned char result[CC_SHA1_DIGEST_LENGTH];
	const void *bytes = secret.bytes;
	size_t secretLength = (size_t)secret.length;
	CCHmac(kCCHmacAlgSHA1, bytes, secretLength, [self bytes], self.length, &result);
	return [[NSMutableData alloc] initWithBytes:&result length:CC_SHA1_DIGEST_LENGTH];
}

@end
