/*
 
 File: GRReachability.m
 
 Copyright (C) 2013 Grant Robinson. All Rights Reserved.
 
*/

#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

#import <CoreFoundation/CoreFoundation.h>
#import "GRObservable.h"

#import "GRReachability.h"

#import "Logging.h"

NSString * NSStringFromReachabilityFlags(SCNetworkReachabilityFlags flags) {
	NSString *str = [NSString stringWithFormat:@"Reachability Flag Status: %c%c %c%c%c%c%c%c%c",
					 (flags & kSCNetworkReachabilityFlagsIsWWAN)				  ? 'W' : '-',
					 (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
					 
					 (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
					 (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
					 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
					 (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
					 (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
					 (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
					 (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'
					 ];
	return str;
}

@interface GRReachability ()
{
	BOOL flagsHaveBeenSet;
	BOOL localWiFiRef;
	SCNetworkReachabilityRef reachabilityRef;
}

@property (nonatomic, strong) GRObservable<GRReachability *> *observable;
@property (nonatomic, strong) GRObserver<GRReachability *> *observer;

@end


@implementation GRReachability

@synthesize changedCallback, dispatchQueue, observable, observer;

- (void) setFlags:(SCNetworkReachabilityFlags)flags {
	[self willChangeValueForKey:@"flags"];
	_flags = flags;
	flagsHaveBeenSet = YES;
	[self didChangeValueForKey:@"flags"];
}

- (GRObservable<GRReachability *> *) observable {
	if (!observable) {
		observable = [GRObservable withBlock:^(GRObserver<GRReachability*> *_observer) {
			self.observer = _observer;
		}];
	}
	return observable;
}

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
	NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
	NSCAssert([(__bridge NSObject *)info isKindOfClass: [GRReachability class]], @"info was wrong class in ReachabilityCallback");

	// We're (probably) on the main RunLoop, so an NSAutoreleasePool is not necessary, but is added defensively
	// in case someone uses the GRReachablity object in a different thread.
	@autoreleasepool {
		GRReachability* noteObject = (__bridge GRReachability*) info;
		DDLogInfo(@"++++++++++-************* reachability flags set to %@", NSStringFromReachabilityFlags(flags));
		noteObject.flags = flags;
		// Post a notification to notify the client that the network reachability changed.
		[[NSNotificationCenter defaultCenter] postNotificationName:kGRReachabilityChangedNotification object:noteObject];
		dispatch_queue_t queue = dispatch_get_main_queue();
		if (noteObject.dispatchQueue) {
			queue = noteObject.dispatchQueue;
		}
		dispatch_async(queue, ^{
			if (noteObject.changedCallback) {
				noteObject.changedCallback(noteObject);
			}
			[noteObject.observer next:noteObject];
		});
	}
}

- (BOOL) startNotifier
{
	BOOL retVal = NO;
	SCNetworkReachabilityContext	context = {0, (__bridge void *)(self), NULL, NULL, NULL};
	if(SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context))
	{
		if(SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
		{
			retVal = YES;
		}
	}
	return retVal;
}

- (void) stopNotifier
{
	if(reachabilityRef!= NULL)
	{
		SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
}

- (void) dealloc
{
	[self stopNotifier];
	if(reachabilityRef!= NULL)
	{
		CFRelease(reachabilityRef);
		reachabilityRef = NULL;
	}
}

+ (GRReachability*) reachabilityWithHostName: (NSString*) hostName;
{
	GRReachability* retVal = NULL;
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
	if(reachability!= NULL)
	{
		retVal= [[self alloc] init];
		if(retVal!= NULL)
		{
			retVal->reachabilityRef = reachability;
			retVal->localWiFiRef = NO;
		}
	}
	return retVal;
}

+ (GRReachability*) reachabilityWithAddress: (const struct sockaddr_in*) hostAddress;
{
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)hostAddress);
	GRReachability* retVal = NULL;
	if(reachability!= NULL)
	{
		retVal= [[self alloc] init];
		if(retVal!= NULL)
		{
			retVal->reachabilityRef = reachability;
			retVal->localWiFiRef = NO;
		}
	}
	return retVal;
}

+ (GRReachability*) reachabilityForInternetConnection;
{
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
	return [self reachabilityWithAddress: &zeroAddress];
}

+ (GRReachability*) reachabilityForLocalWiFi;
{
	struct sockaddr_in localWifiAddress;
	bzero(&localWifiAddress, sizeof(localWifiAddress));
	localWifiAddress.sin_len = sizeof(localWifiAddress);
	localWifiAddress.sin_family = AF_INET;
	// IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
	localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
	GRReachability* retVal = [self reachabilityWithAddress: &localWifiAddress];
	if(retVal!= NULL)
	{
		retVal->localWiFiRef = YES;
	}
	return retVal;
}

#pragma mark Network Flag Handling

- (GRNetworkStatus) localWiFiStatusForFlags: (SCNetworkReachabilityFlags) flags
{
	GRNetworkStatus retVal = GRNotReachable;
	if((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
	{
		retVal = GRReachableViaWiFi;	
	}
	return retVal;
}

- (GRNetworkStatus) networkStatusForFlags: (SCNetworkReachabilityFlags) flags
{
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
	{
		// if target host is not reachable
		return GRNotReachable;
	}

	GRNetworkStatus retVal = GRNotReachable;
	
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
	{
		// if target host is reachable and no connection is required
		//  then we'll assume (for now) that your on Wi-Fi
		retVal = GRReachableViaWiFi;
	}
	
	
	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
		(flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
	{
			// ... and the connection is on-demand (or on-traffic) if the
			//     calling application is using the CFSocketStream or higher APIs

			if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
			{
				// ... and no [user] intervention is needed
				retVal = GRReachableViaWiFi;
			}
		}
	
	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
	{
		// ... but WWAN connections are OK if the calling application
		//     is using the CFNetwork (CFSocketStream?) APIs.
		retVal = GRReachableViaWWAN;
	}
	return retVal;
}

- (BOOL) connectionRequired;
{
	NSAssert(reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
	if (flagsHaveBeenSet) {
		return (_flags & kSCNetworkReachabilityFlagsConnectionRequired);
	}
	return NO;
}

- (GRNetworkStatus) currentReachabilityStatus
{
	NSAssert(reachabilityRef != NULL, @"currentNetworkStatus called with NULL reachabilityRef");
	GRNetworkStatus retVal = GRNotReachable;
	if (flagsHaveBeenSet) {
		if(localWiFiRef)
		{
			retVal = [self localWiFiStatusForFlags:_flags];
		}
		else
		{
			retVal = [self networkStatusForFlags:_flags];
		}
	}
	else {
		retVal = GRReachableViaWiFi;
	}
	return retVal;
}
@end
