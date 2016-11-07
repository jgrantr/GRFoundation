//
//  UIImage+ColorReplacement.h
//
//  Created by Grant Robinson on 9/26/12.
//
//

#import <UIKit/UIKit.h>

@interface UIImage (ColorReplacement)

+ (UIImage *) imageWithSize:(CGSize)size color:(UIColor *)color;
+ (UIImage *) imageWithSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius color:(UIColor *)color;
+ (UIImage *) overlayImage:(UIImage *)overlay onTopOfImage:(UIImage *)underlay;

+ (UIImage *) imageFromAttributedString:(NSAttributedString *)str;

- (UIImage *) maskWithImage:(UIImage *)maskImage;
- (UIImage *) maskWithImage:(UIImage *)maskImage andUnderlayImage:(UIImage *)underlay;
- (UIImage *)imageByRemovingColor:(UIColor *)color;
- (UIImage *)imageByRemovingColorsWithMinColor:(UIColor *)minColor maxColor:(UIColor *)maxColor;
- (UIImage *)imageByReplacingColor:(UIColor *)color withColor:(UIColor *)newColor;
- (UIImage *)imageByReplacingColorsWithMinColor:(UIColor *)minColor maxColor:(UIColor *)maxColor withColor:(UIColor *)newColor;

- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize;

- (UIImage *)resizedImage:(CGSize)newSize
	 interpolationQuality:(CGInterpolationQuality)quality;
- (UIImage *)resizedImageWithContentMode:(UIViewContentMode)contentMode
								  bounds:(CGSize)bounds
					interpolationQuality:(CGInterpolationQuality)quality;


- (UIImage *)applyLightEffect;
- (UIImage *)applyExtraLightEffect;
- (UIImage *)applyDarkEffect;
- (UIImage *)applyTintEffectWithColor:(UIColor *)tintColor;

- (UIImage *)applyBlurWithRadius:(CGFloat)blurRadius tintColor:(UIColor *)tintColor saturationDeltaFactor:(CGFloat)saturationDeltaFactor maskImage:(UIImage *)maskImage;

- (UIImage *) rotatedImage;

@end
