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
 
 Access to properties is provided using keyed subscripting, so on an instance of this class, it can be used as follows:

 metadata[@"photoshop:DateCreated"] = @"2019-01-05T22:45:32";
 NSString *dateCreatedStr = metadata[@"photoshop:DateCreated"];
 
 */
@interface GRImageMetadata : NSObject

/**
 Creates an instance using the given CGImageMetadataRef.  A mutable copy is made of the passed in object.

 @param metadata the metadata to wrap
 @return a class instance backed by a mutable copy of the given CGImageMetadataRef, or nil if the passed in object is NULL or can't be copied.
 */
+ (instancetype) withMetadata:(CGImageMetadataRef)metadata;
/**
 Creates an empty instance

 @return a class instance backed by a CGMutableImageMetadataRef, or nil if one can' be created
 */
+ (instancetype) metadata;

@property (nonatomic, readonly) CGMutableImageMetadataRef metadata;

/**
 Enumerates through all the tags in the container using the given block.  The block is called with the path, name, and value of each tag.

 @param block a block to be called for each tag
 */
- (void) enumerateTagsUsingBlock:(GRTagEnumerationBlock)block;

/**
 Enumerates through all the tags starting at the given path.  Passing in a path that is nil or the empty string will start the enumeration
 at the root path.

 @param path the path to start at
 @param block a block to be called for each tag
 */
- (void) enumerateTagsAtPath:(NSString *)path usingBlock:(GRTagEnumerationBlock)block;

/**
 Enumerates through all tags in the container, starting at path.  If recursive is YES, the enumeration will be recursive.  Otherwise, only direct children of the starting path will be enumerated.

 @param path the path to start at
 @param recursive set to YES for all tags, NO for only direct children
 @param block a block to be called for each tag
 */
- (void) enumerateTagsAtPath:(NSString *)path recursive:(BOOL)recursive usingBlock:(GRTagEnumerationBlock)block;

/**
 Register's an XML namespace for the given prefix.  This method must be called before attempting to access any tag values by their path for
 unknown prefixes.  All standard prefixes and prefixes in the wrapped container are pre-registered.

 @param xmlNamespace the xml namespace for the data
 @param prefix the prefix to associae with the namespace
 @return nil if the registration is successful, and an error otherwise
 */
- (NSError *) registerNamespace:(NSString *)xmlNamespace forPrefix:(NSString *)prefix;

- (id) objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

@end
