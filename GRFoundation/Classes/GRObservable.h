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
typedef void (^GRObservableCompleteBlock)(void);

@interface GRObserver<__covariant ObjectType> : NSObject

- (void) next:(ObjectType)value;
- (void) error:(NSError *)error;
- (void) complete;

@end

@interface GRSubscriber<__covariant ObjectType> : GRObserver<ObjectType>

+ (GRSubscriber *) next:(void (^)(ObjectType value))next error:(void (^)(NSError *error))error complete:(void (^)(void))complete;
+ (GRSubscriber *) next:(void (^)(ObjectType value))next error:(void (^)(NSError *error))error;
+ (GRSubscriber *) next:(void (^)(ObjectType value))next;

- (void) unsubscribe;

@end

#define GRSubscribe(observable, ...) __GRSubscribe(observable, __VA_ARGS__, nil, nil, nil)
#define __GRSubscribe(observable, _next, _error, _complete, ...) observable.subscribeWithLiterals(_next, _error, _complete)


@interface GRObservable<__covariant ObjectType> : NSObject

+ (instancetype) withBlock:(void (^)(GRObserver<ObjectType>* observer))block;
+ (GRObservable<ObjectType>* (^)(void (^)(GRObserver<ObjectType> *observer)))observable;

@property (nonatomic) BOOL asynchronous;
@property (nonatomic) BOOL deliverCurrentValueUponSubscription;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong) NSString *name;

- (GRSubscriber<ObjectType> *(^)(id nextOrObservable))subscribe;
- (GRSubscriber<ObjectType> *(^)(void (^)(ObjectType value), GRObservableErrorBlock, GRObservableCompleteBlock))subscribeWithLiterals;

/**
 * Returns a new observable that will emit values that are distinct from the previous value.  For example,
 * if the source observable emits {1, 1, 2, 2, 2, 1, 3, 4}, this observable will emit {1, 2, 1, 3, 4}.  If a comparison
 * block is passed, it will be used to determine equality.
 *
 * If no block is passed, the gr_isEqual: selector will be used.
 * If the object does not respond to the gr_isEqual: selector, the isEqual: selector will be used.
 *
 */
- (GRObservable<ObjectType> *(^)(BOOL (^)(ObjectType prev, ObjectType cur))) distinctUntilChanged;

@end

/**
 * @brief A subclass of GRObservable specifically for doing KVO observing.
 * @discussion Please note the following:
 *    1) instances of this class strongly-retain the object they are observing.  To release the retained object that is being observed,
 *      simply make sure that the instance of this class is released.
 *    2) instances of GRKVOObservable deliver the latest value when you subscribe by default.  If for some reason you don't want this behavior,
 *      set the value of <pre>deliverCurrentValueUponSubscription</pre> to <pre>NO</pre>.
 */
@interface GRKVObservable<__covariant ObjectType> : GRObservable

+ (GRKVObservable<ObjectType> *) forObject:(id<NSObject>)object keyPath:(NSString *)keypath;
+ (GRKVObservable<NSDictionary<NSKeyValueChangeKey,id> *> *) rawObservableFor:(id<NSObject>)object keyPath:(NSString *)keypath;

/**
  * An observer attached to Key-Value Observing never actually completes, so this method is provided to complete
  * the observable so cleanup can happen.
  */
- (void) complete;

@end
