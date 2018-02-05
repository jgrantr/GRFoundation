//
//  UIDevice+Hardware.m
//
//  Created by Grant Robinson on 1/25/12.
//  Copyright (c) 2012 Grant Robinson. All rights reserved.
//

#import "UIDevice+Hardware.h"
#import <sys/sysctl.h>
#import "LoadableCategory.h"

MAKE_CATEGORIES_LOADABLE(UIDevice_Hardware);

#if TARGET_OS_IPHONE
static char *propertyName = "hw.machine";
#else
static char *propertyName = "hw.model";
#endif

@implementation UIDevice(Hardware)

/*
 Platforms
 
 iFPGA ->        ??
 
 iPhone1,1 ->    iPhone 1G, M68
 iPhone1,2 ->    iPhone 3G, N82
 iPhone2,1 ->    iPhone 3GS, N88
 iPhone3,1 ->    iPhone 4/AT&T, N89
 iPhone3,2 ->    iPhone 4/Other Carrier?, ??
 iPhone3,3 ->    iPhone 4/Verizon, TBD
 iPhone4,1 ->    (iPhone 4S/AT&T), TBD
 iPhone4,2 ->    (iPhone 4S/Verizon), TBD
 iPhone4,3 ->    (iPhone 4S/???)
 iPhone5,1 ->    iPhone Next Gen, TBD
 iPhone5,1 ->    iPhone Next Gen, TBD
 iPhone5,1 ->    iPhone Next Gen, TBD
 
 iPod1,1   ->    iPod touch 1G, N45
 iPod2,1   ->    iPod touch 2G, N72
 iPod2,2   ->    Unknown, ??
 iPod3,1   ->    iPod touch 3G, N18
 iPod4,1   ->    iPod touch 4G, N80
 
 // Thanks NSForge
 iPad1,1   ->    iPad 1G, WiFi and 3G, K48
 iPad2,1   ->    iPad 2G, WiFi, K93
 iPad2,2   ->    iPad 2G, GSM 3G, K94
 iPad2,3   ->    iPad 2G, CDMA 3G, K95
 iPad2,5   ->    iPad Mini WiFi
 iPad2.6   ->    iPad GSM
 iPad2,7   ->    iPad CDMA
 iPad3,1   ->    (iPad 3G, WiFi)
 iPad3,2   ->    (iPad 3G, GSM)
 iPad3,3   ->    (iPad 3g, CDMA)
 iPad4,1   ->    (iPad 4G, WiFi)
 iPad4,2   ->    (iPad 4G, GSM)
 iPad4,3   ->    (iPad 4G, CDMA)

 
 AppleTV2,1 ->   AppleTV 2, K66
 
 i386, x86_64 -> iPhone Simulator
 */

#pragma mark sysctlbyname utils
- (NSString *) getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
	
    free(answer);
    return results;
}

- (NSString *) specificModel {
	static NSDictionary *lookup = nil;
	if (lookup == nil) {
		lookup = @{
			@"iPhone1,1"  : @"iPhone",
			@"iPhone1,2"  : @"iPhone 3G",
			@"iPhone2,1"  : @"iPhone 3GS",
			@"iPhone3,1"  : @"iPhone 4 GSM",
			@"iPhone3,2"  : @"iPhone 4",
			@"iPhone3,3"  : @"iPhone 4 Verizon",
			@"iPhone4,1"  : @"iPhone 4S GSM",
			@"iPhone4,2"  : @"iPhone 4S CDMA",
			@"iPhone4,3"  : @"iPhond 4S",
			@"iPhone5,1"  : @"iPhone 5 GSM",
			@"iPhone5,2"  : @"iPhone 5 CDMA",
			@"iPhone5,3"  : @"iPhone 5c",
			@"iPhone5,4"  : @"iPhone 5c",
			@"iPhone6,1"  : @"iPhone 5s GSM",
			@"iPhone6,2"  : @"iPhone 5s",
			@"iPhone7,1"  : @"iPhone 6 Plus",
			@"iPhone7,2"  : @"iPhone 6",
			@"iPhone8,1"  : @"iPhone 6s",
			@"iPhone8,2"  : @"iPhone 6s Plus",
			@"iPhone8,4"  : @"iPhone SE",
			@"iPhone9,1"  : @"iPhone 7 (CDMA+GSM/LTE)",
			@"iPhone9,2"  : @"iPhone 7 Plus (CDMA+GSM/LTE)",
			@"iPhone9,3"  : @"iPhone 7 (GSM/LTE)",
			@"iPhone9,4"  : @"iPhone 7 Plus (GSM/LTE)",
			@"iPhone10,1" : @"iPhone 8 (CDMA/LTE)",
			@"iPhone10,2" : @"iPhone 8 Plus (CDMA/LTE)",
			@"iPhone10,3" : @"iPhone X (CDMA/LTE)",
			@"iPhone10,4" : @"iPhone 8 (CDMA+GSM/LTE)",
			@"iPhone10,5" : @"iPhone 8 Plus (CDMA+GSM/LTE)",
			@"iPhone10,6" : @"iPhone X (CDMA+GSM/LTE)",
			@"iPod1,1"    : @"iPod Touch 1G",
			@"iPod2,1"    : @"iPod Touch 2G",
			@"iPod2,2"    : @"iPod Touch",
			@"iPod3,1"    : @"iPod Touch 3G",
			@"iPod4,1"    : @"iPod Touch 4G",
			@"iPod5,1"    : @"iPod Touch 5G",
			@"iPod7,1"    : @"iPod Touch 6G",
			@"iPad1,1"    : @"iPad",
			@"iPad2,1"    : @"iPad 2 WiFi",
			@"iPad2,2"    : @"iPad 2 GSM",
			@"iPad2,3"    : @"iPad 2 CDMA",
			@"iPad2,4"    : @"iPad 2",
			@"iPad2,5"    : @"iPad Mini WiFi",
			@"iPad2,6"    : @"iPad Mini GSM",
			@"iPad2,7"    : @"iPad Mini CDMA",
			@"iPad3,1"    : @"iPad 3rd Gen WiFi",
			@"iPad3,2"    : @"iPad 3rd Gen GSM",
			@"iPad3,3"    : @"iPad 3rd Gen CDMA",
			@"iPad3,4"    : @"iPad 4th Gen WiFi",
			@"iPad3,5"    : @"iPad 4th Gen GSM",
			@"iPad3,6"    : @"iPad 4th Gen GSM+CDMA",
			@"iPad4,1"    : @"iPad Air WiFi",
			@"iPad4,2"    : @"iPad Air Cellular",
			@"iPad4,3"    : @"iPad Air Cellular",
			@"iPad4,4"    : @"iPad Mini 2 WiFi",
			@"iPad4,5"    : @"iPad Mini 2 Cellular",
			@"iPad4,6"    : @"iPad Mini 2",
			@"iPad4,7"    : @"iPad Mini 3 WiFi",
			@"iPad4,8"    : @"iPad Mini 3 Cellular",
			@"iPad4,9"    : @"iPad Mini 3",
			@"iPad5,1"    : @"iPad Mini 4 (WiFi)",
			@"iPad5,2"    : @"iPad Mini 4 (Cellular)",
			@"iPad5,3"    : @"iPad Air 2 WiFi",
			@"iPad5,4"    : @"iPad Air 2 Cellular",
			@"iPad6,3"    : @"iPad Pro 9.7-inch (WiFi)",
			@"iPad6,4"    : @"iPad Pro 9.7-inch (Cellular)",
			@"iPad6,7"    : @"iPad Pro 12.9-inch (WiFi)",
			@"iPad6,8"    : @"iPad Pro 12.9-inch (Cellular)",
			@"iPad6,11"   : @"iPad 5th Gen 2017 WiFi",
			@"iPad6,12"   : @"iPad 5th Gen 2017 LTE",
			@"iPad7,1"    : @"iPad Pro 12.9\" 2nd Gen WiFi",
			@"iPad7,2"    : @"iPad Pro 12.9\" 2nd Gen LTE",
			@"iPad7,3"    : @"iPad Pro 10.5\" WiFi",
			@"iPad7,4"    : @"iPad Pro 10.5\" LTE",
			@"i386"       : @"iPhone Simulator x86",
			@"x86_64"     : @"iPhone Simulator x64",
		};
	}
	NSString *rawStr = [self getSysInfoByName:propertyName];
	NSString *platform = [lookup objectForKey:rawStr];
	if (platform == nil) {
		platform = rawStr;
	}
	return platform;
}

- (NSString *) hwModel {
	return [self getSysInfoByName:propertyName];
}

@end
