//
//  NSData+GRExtensions.h
//  GRFoundation
//
//  Created by Grant Robinson on 8/4/18.
//

#import <Foundation/Foundation.h>

@interface NSData (GRExtensions)

/**
 Using the given secret, creates a HMAC-SHA1 digest of the contents and returns
 the raw binary digest.

 @param secret the secret to use for creating the digest
 @return the binary HMAC-SHA1 digest of the contents
 */
- (NSMutableData *) hmacSHA1UsingSecret:(NSData *)secret;

@end
