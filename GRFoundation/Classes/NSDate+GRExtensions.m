//
//  NSDate+GRExtensions.m
//  Pods
//
//  Created by Grant Robinson on 3/3/18.
//
//

#import "NSDate+GRExtensions.h"

@implementation NSDate (GRExtensions)

- (BOOL) isEarlierThan:(NSDate *)anotherDate {
	return ([self compare:anotherDate] == NSOrderedAscending);
}

- (BOOL) isLaterThan:(NSDate *)anotherDate {
	return ([self compare:anotherDate] == NSOrderedDescending);
}

@end
