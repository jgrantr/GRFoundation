//
//  NSData+GRExtensions.m
//  GRFoundation
//
//  Created by Grant Robinson on 8/4/18.
//

#import "NSData+GRExtensions.h"
#import "GRImageMetadata.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import <ImageIO/ImageIO.h>

#import "Logging.h"

@implementation NSData (GRExtensions)

- (GRImageMetadata *) imageMetadata {
	CGImageSourceRef source = NULL;
	source = CGImageSourceCreateWithData((__bridge CFDataRef)self, NULL);
	
	GRImageMetadata *metadataWrapper = nil;
	if (source != NULL) {
		CGImageMetadataRef imageMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, NULL);
		if (imageMetadata != NULL) {
			metadataWrapper = [GRImageMetadata withMetadata:imageMetadata];
			CFRelease(imageMetadata);
		}
		else {
			DDLogWarn(@"unable to copy source image metadata");
		}
	}
	
	if (source != NULL) {
		CFRelease(source);
	}
	
	return metadataWrapper;
}

- (NSData *) dataByUpdatingImageMetadata:(GRImageMetadata *)imageMetadata {
	return [self dataByUpdatingImageMetadata:imageMetadata merge:NO];
}

- (NSData *) dataByMergingImageMetadata:(GRImageMetadata *)imageMetadata {
	return [self dataByUpdatingImageMetadata:imageMetadata merge:YES];
}

- (NSData *) dataByUpdatingImageMetadata:(GRImageMetadata *)imageMetadata merge:(BOOL)merge {
	CGImageSourceRef source = NULL;
	source = CGImageSourceCreateWithData((__bridge CFDataRef)self, NULL);
	
	NSMutableData *imageData = [NSMutableData dataWithCapacity:self.length];
	CFStringRef UTI = CGImageSourceGetType(source); //this is the type of image (e.g., public.jpeg)
	CGImageDestinationRef destination = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, UTI, 1, NULL);
	
	if (destination != NULL) {
		CFErrorRef error = NULL;
		NSDictionary<NSString *, id> *options = @{
			(__bridge NSString *)kCGImageDestinationMetadata : (__bridge id)imageMetadata.metadata,
			(__bridge NSString *)kCGImageDestinationMergeMetadata : @(merge),
		};
		BOOL success = CGImageDestinationCopyImageSource(destination, source, (CFDictionaryRef)options, &error);
		if (!success) {
			DDLogError(@"error updating image metadata: %@", error);
			imageData = nil;
		}
	}
	else {
		DDLogError(@"unable to create image destination");
	}
	
	if (destination != NULL) {
		CFRelease(destination);
	}
	if (source != NULL) {
		CFRelease(source);
	}
	
	return imageData;
}


- (NSMutableData *) hmacSHA1UsingSecret:(NSData *)secret {
	unsigned char result[CC_SHA1_DIGEST_LENGTH];
	const void *bytes = secret.bytes;
	size_t secretLength = (size_t)secret.length;
	CCHmac(kCCHmacAlgSHA1, bytes, secretLength, [self bytes], self.length, &result);
	return [[NSMutableData alloc] initWithBytes:&result length:CC_SHA1_DIGEST_LENGTH];
}

@end
