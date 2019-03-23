//
//  GRImageMetadata.h
//  GRFoundation
//
//  Created by Grant Robinson on 3/23/19.
//

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

typedef BOOL(^GRTagEnumerationBlock)(NSString *path, NSString *name, id value);

/**
 An object-oriented wrapper around the CGImageMetadataRef class.  Uses the keyed subscripting
 to provide access to the XMP metadata for an image. Regular Objective-C objects are returned
 and should be passed in to set values.  The only valid values for an XMP tag are the following:
     * NSArray
     * NSDictionary
     * NSString
     * NSNumber
 */
@interface GRImageMetadata : NSObject

+ (instancetype) withMetadata:(CGImageMetadataRef)metadata;

@property (nonatomic, readonly) CGMutableImageMetadataRef metadata;

- (void) enumerateTagsUsingBlock:(GRTagEnumerationBlock)block;
- (void) enumerateTagsAtPath:(NSString *)path usingBlock:(GRTagEnumerationBlock)block;
- (void) enumerateTagsAtPath:(NSString *)path recursive:(BOOL)recursive usingBlock:(GRTagEnumerationBlock)block;

- (id) objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

@end
