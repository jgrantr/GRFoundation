/*
 
 File: GRReachability.h
 
 Copyright (C) 2013 Grant Robinson. All Rights Reserved.
 
*/


#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>


typedef NS_ENUM(NSInteger, GRNetworkStatus) {
	GRNotReachable = 0,
	GRReachableViaWiFi,
	GRReachableViaWWAN
};

#define kGRReachabilityChangedNotification @"kGRNetworkReachabilityChangedNotification"

@class GRObservable<ObjectType>;

@interface GRReachability: NSObject

@property (copy, nonatomic) void (^changedCallback)(GRReachability *obj);
@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (assign, nonatomic) SCNetworkReachabilityFlags flags;
@property (nonatomic, readonly) GRObservable<GRReachability *> *observable;

- (void) setChangedCallback:(void (^)(GRReachability *reach))changedCallback;

//reachabilityWithHostName- Use to check the reachability of a particular host name. 
+ (GRReachability*) reachabilityWithHostName: (NSString*) hostName;

//reachabilityWithAddress- Use to check the reachability of a particular IP address. 
+ (GRReachability*) reachabilityWithAddress: (const struct sockaddr_in*) hostAddress;

//reachabilityForInternetConnection- checks whether the default route is available.  
//  Should be used by applications that do not connect to a particular host
+ (GRReachability*) reachabilityForInternetConnection;

//reachabilityForLocalWiFi- checks whether a local wifi connection is available.
+ (GRReachability*) reachabilityForLocalWiFi;

//Start listening for reachability notifications on the current run loop
- (BOOL) startNotifier;
- (void) stopNotifier;

- (GRNetworkStatus) currentReachabilityStatus;
//WWAN may be available, but not active until a connection has been established.
//WiFi may require a connection for VPN on Demand.
- (BOOL) connectionRequired;

@end


