//
//  GRObservable.h
//  Pods
//
//  Created by Grant Robinson on 3/16/17.
//
//

#import <Foundation/Foundation.h>

@protocol GRObserver <NSObject>

@required
- (void) next:(id)value;
- (void) error:(NSError *)error;
- (void) complete;

@end

@interface GRSubscriber : NSObject <GRObserver>

+ (GRSubscriber *) next:(void (^)(id value))next error:(void (^)(NSError *error))error complete:(void (^)())complete;
+ (GRSubscriber *) next:(void (^)(id value))next error:(void (^)(NSError *error))error;
+ (GRSubscriber *) next:(void (^)(id value))next;

- (void) unsubscribe;

@end

#define GRSubscribe(observable, ...) __GRSubscribe(observable, __VA_ARGS__, 3, 2, 1, 0)
#define __GRSubscribe(observable, _next, _error, _complete, N, ...) observable.subscribeWithLiterals(N, _next, _error, _complete)


@interface GRObservable : NSObject

+ (instancetype) withBlock:(void (^)(id<GRObserver> observer))block;
+ (instancetype (^)(void (^)(id<GRObserver> observer)))observable;

- (GRSubscriber *(^)(id nextOrObservable))subscribe;
- (GRSubscriber *(^)(int, ...))subscribeWithLiterals;

@end
