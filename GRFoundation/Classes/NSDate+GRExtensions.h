//
//  NSDate+GRExtensions.h
//  Pods
//
//  Created by Grant Robinson on 3/3/18.
//
//

#import <Foundation/Foundation.h>

@interface NSDate (GRExtensions)

- (BOOL) isEarlierThan:(NSDate *)anotherDate;
- (BOOL) isLaterThan:(NSDate *)anotherDate;

@end
