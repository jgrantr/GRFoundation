//
//  NSDate+GRExtensions.m
//  Pods
//
//  Created by Grant Robinson on 3/3/18.
//
//

#import "NSDate+GRExtensions.h"
#import <objc/runtime.h>

static dispatch_queue_t dispatchQueue() {
	static dispatch_queue_t queue;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		queue = dispatch_queue_create("net.mr-r.NSDateGRExtensions.queue", NULL);
	});
	return queue;
}

@implementation NSDate (GRExtensions)

- (BOOL) isEarlierThan:(NSDate *)anotherDate {
	return ([self compare:anotherDate] == NSOrderedAscending);
}

- (BOOL) isLaterThan:(NSDate *)anotherDate {
	return ([self compare:anotherDate] == NSOrderedDescending);
}

- (NSCalendarUnit) allComponents {
	return NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekOfMonth|NSCalendarUnitWeekOfYear|NSCalendarUnitWeekday|NSCalendarUnitWeekdayOrdinal|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond;
}

- (NSString *) longAgoDateStringWithCalendar:(NSCalendar *)cal {
	static NSDateFormatter *longAgo;
	static NSArray *suffixes;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		longAgo = [[NSDateFormatter alloc] init];
		longAgo.dateFormat = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"longAgo", nil, [NSBundle mainBundle], @"MMM d'${suffix} at' %@", @"Should read something like 'July 3rd at 3:45 PM"), [NSDateFormatter dateFormatFromTemplate:@"jj:mm" options:0 locale:[NSLocale autoupdatingCurrentLocale]]];
		NSString *suffix_string = @"|st|nd|rd|th|th|th|th|th|th|th|th|th|th|th|th|th|th|th|th|th|st|nd|rd|th|th|th|th|th|th|th|st";
		suffixes = [suffix_string componentsSeparatedByString: @"|"];
	});
	__block NSString *value = nil;
	dispatch_sync(dispatchQueue(), ^{
		value = [longAgo stringFromDate:self];
	});
	NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
	NSString *languageCode = [locale objectForKey:NSLocaleLanguageCode];
	NSString *dateString = nil;
	if ([languageCode caseInsensitiveCompare:@"en"] == NSOrderedSame) {
		NSInteger day = [cal component:NSCalendarUnitDay fromDate:self];
		NSString *suffix = suffixes[day];
		dateString = [value stringByReplacingOccurrencesOfString:@"${suffix}" withString:suffix];
	}
	else {
		dateString = [value stringByReplacingOccurrencesOfString:@"${suffix}" withString:@""];
	}
	return dateString;
}

- (NSString *) toRelativeDateTime {
	NSDate *now = [NSDate date];
	NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	cal.timeZone = [NSTimeZone localTimeZone];
	NSDate *startOfDay = [cal startOfDayForDate:self];
	NSUInteger units = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
	NSDateComponents *startOfDayComponents = [cal components:units fromDate:startOfDay toDate:now options:0];
	NSDateComponents *components = [cal components:units fromDate:self toDate:now options:0];
	if (components.day == 0 && components.hour == 0) {
		if (components.minute >= 1) {
			return [NSString stringWithFormat:components.minute == 1 ? NSLocalizedStringWithDefaultValue(@"minuteAgo", nil, [NSBundle mainBundle], @"%ld minute ago", nil) : NSLocalizedStringWithDefaultValue(@"minutesAgo", nil, [NSBundle mainBundle], @"%ld minutes ago", nil), components.minute];
		}
		else {
			return NSLocalizedStringWithDefaultValue(@"justNow", nil, [NSBundle mainBundle], @"Just now", nil);
		}
	}
	if (startOfDayComponents.day >= 2) {
		return [self longAgoDateStringWithCalendar:cal];
	}
	else if (startOfDayComponents.day == 1) {
		static NSDateFormatter *yesterdayRelative;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			yesterdayRelative = [[NSDateFormatter alloc] init];
			yesterdayRelative.dateFormat = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"yesterdayRelative", nil, [NSBundle mainBundle], @"'Yesterday at' %@", @"Should read something like 'Yesterday at 12:31 PM'"), [NSDateFormatter dateFormatFromTemplate:@"jj:mm" options:0 locale:[NSLocale autoupdatingCurrentLocale]]];
		});
		__block NSString *value = nil;
		dispatch_sync(dispatchQueue(), ^{
			value = [yesterdayRelative stringFromDate:self];
		});
		return value;
	}
	else if (startOfDayComponents.hour >= 1) {
		static NSDateFormatter *todayRelative;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			todayRelative = [[NSDateFormatter alloc] init];
			todayRelative.dateFormat = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"todayRelative", nil, [NSBundle mainBundle], @"'Today at' %@", @"Should read something like 'Today at 12:31 PM'"), [NSDateFormatter dateFormatFromTemplate:@"jj:mm" options:0 locale:[NSLocale autoupdatingCurrentLocale]]];
		});
		__block NSString *value = nil;
		dispatch_sync(dispatchQueue(), ^{
			value = [todayRelative stringFromDate:self];
		});
		return value;
	}
	else {
		return [self longAgoDateStringWithCalendar:cal];
	}
}

@end
