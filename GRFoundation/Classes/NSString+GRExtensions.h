//
//  NSString+GRExtensions.h
//  GRFoundation
//
//  Created by Grant Robinson on 8/4/18.
//

#import <Foundation/Foundation.h>

@interface NSString (GRExtensions)

/**
 Using the passed-in secret, creates a HMAC-SHA1 digest from self, and returns the base64-encoded
 string.

 @param secret the secret used to make the digest
 @return a base-64 encoded string of the digest
 */
- (NSString *) hmacSHA1UsingSecret:(NSData *)secret;

@end
