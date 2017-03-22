//
//  UIColor+HexColor.m
//  Pods
//
//  Created by Grant Robinson on 3/22/17.
//
//

#import "UIColor+HexColor.h"
#import "LoadableCategory.h"
#import "Logging.h"

MAKE_CATEGORIES_LOADABLE(UIColor_HexColor);

@implementation UIColor (HexColor)

+ (UIColor *) colorFromHexString:(NSString *)hexColor {
	if (hexColor == nil) {
		return nil;
	}
	NSScanner *scanner = [NSScanner scannerWithString:hexColor];
	BOOL hasAlpha = NO;
	NSRange hexMark = [hexColor rangeOfString:@"0x"];
	NSRange hashMark = [hexColor rangeOfString:@"#"];
	NSUInteger noAlphaLen = 6;
	if (hexMark.location != NSNotFound) {
		noAlphaLen = 8;
	}
	else if (hashMark.location != NSNotFound) {
		noAlphaLen = 7;
	}
	hasAlpha = hexColor.length > noAlphaLen;
	if (hashMark.location != NSNotFound) {
		[scanner setScanLocation:1];
	}
	unsigned int hexValue = 0;
	[scanner scanHexInt:&hexValue];
	unsigned int red, green, blue, alpha;
	if (hasAlpha) {
		red = (hexValue >> 24) & 0xff;
		green = (hexValue >> 16) & 0xff;
		blue = (hexValue >> 8) & 0xff;
		alpha = hexValue & 0xff;
	}
	else {
		alpha = 255;
		red = (hexValue >> 16) & 0xff;
		green = (hexValue >> 8) & 0xff;
		blue = hexValue & 0xff;
	}
	DDLogVerbose(@"parsed color values are: %d(red) %d(green) %d(blue) %d(alpha)", red, green, blue, alpha);
	UIColor *color = [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:alpha/255.0];
	return color;
}

@end
