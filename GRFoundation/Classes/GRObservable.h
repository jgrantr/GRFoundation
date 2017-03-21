//
//  GRObservable.h
//  Pods
//
//  Created by Grant Robinson on 3/16/17.
//
//

#import <Foundation/Foundation.h>

typedef void (^GRObservableNextBlock)(id value);
typedef void (^GRObservableErrorBlock)(NSError *error);
typedef void (^GRObservableCompleteBlock)();

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

#define GRSubscribe(observable, ...) __GRSubscribe(observable, __VA_ARGS__, nil, nil, nil)
#define __GRSubscribe(observable, _next, _error, _complete, ...) observable.subscribeWithLiterals(_next, _error, _complete)


@interface GRObservable : NSObject

+ (instancetype) withBlock:(void (^)(id<GRObserver> observer))block;
+ (GRObservable* (^)(void (^)(id<GRObserver> observer)))observable;

- (GRSubscriber *(^)(id nextOrObservable))subscribe;
- (GRSubscriber *(^)(GRObservableNextBlock, GRObservableErrorBlock, GRObservableCompleteBlock))subscribeWithLiterals;

/**
 * Returns a new observable that will emit values that are distinct from the previous value.  For example,
 * if the source observable emits {1, 1, 2, 2, 2, 1, 3, 4}, this observable will emit {1, 2, 1, 3, 4}.  If a comparison
 * block is passed, it will be used to determine equality.
 *
 * If no block is passed, the gr_isEqual: selector will be used.
 * If the object does not respond to the gr_isEqual: selector, the isEqual: selector will be used.
 *
 */
- (GRObservable *(^)(BOOL (^)(id prev, id cur))) distinctUntilChanged;

@end
