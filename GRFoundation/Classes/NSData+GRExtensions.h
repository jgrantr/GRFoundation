//
//  NSData+GRExtensions.h
//  GRFoundation
//
//  Created by Grant Robinson on 8/4/18.
//

#import <Foundation/Foundation.h>

@class GRImageMetadata;

@interface NSData (GRExtensions)

@property (nonatomic, readonly) GRImageMetadata *imageMetadata;

/**
 Creates a new data object by taking the given image metadata and replacing it.  Please note that this
 will NOT merge the image metadata, but will replace it entirely.  To merge the given metadata with the existing
 metadta, please use dataByMergingImageMetadata: instead.

 @param imageMetadata the image metadata that will replace the existing metadata
 @return a new NSData object that has the given image metadata embedded in it
 */
- (NSData *) dataByUpdatingImageMetadata:(GRImageMetadata *)imageMetadata;

/**
 Creates a new data object by taking the given image metadata and merging it with the existing metadata.
 To instead replace ALL the metadata, please use dataByUpdatingImageMetadata: instead.

 @param imageMetadata the image metadata to merge with the existing metadata
 @return a new NSData object that has the given image metadata merged and embedded within it
 */
- (NSData *) dataByMergingImageMetadata:(GRImageMetadata *)imageMetadata;

/**
 Using the given secret, creates a HMAC-SHA1 digest of the contents and returns
 the raw binary digest.

 @param secret the secret to use for creating the digest
 @return the binary HMAC-SHA1 digest of the contents
 */
- (NSMutableData *) hmacSHA1UsingSecret:(NSData *)secret;


@end
