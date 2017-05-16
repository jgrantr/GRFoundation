//
//  GRObservable.m
//  Pods
//
//  Created by Grant Robinson on 3/16/17.
//
//

#import "GRObservable.h"
#import "Logging.h"

#undef LOG_LEVEL_DEF
#define LOG_LEVEL_DEF GRSub_ddLogLevel

static DDLogLevel GRSub_ddLogLevel = DDLogLevelInfo;

#import <objc/runtime.h>

static char associatedObserverKey;

static dispatch_queue_t _privateQ;

@interface GRSubscriber ()

@property (nonatomic, weak) GRObserver *parent;

@end

@interface GRObserver ()
{
	NSMutableArray <GRSubscriber *> *subscribers;
	BOOL erroredOut;
	BOOL complete;
	BOOL isMainQueue;
}

@property (nonatomic) BOOL asynchronous;
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;


- (void) addSubscriber:(GRSubscriber *)subscriber;
- (void) removeSubscriber:(GRSubscriber *)subscriber;

@end

@implementation GRObserver

- (instancetype) init {
	self = [super init];
	if (self) {
		subscribers = [NSMutableArray arrayWithCapacity:1];
		isMainQueue = (self.dispatchQueue == nil || self.dispatchQueue == dispatch_get_main_queue());
	}
	return self;
}

- (void) setDispatchQueue:(dispatch_queue_t)dispatchQueue {
	[self willChangeValueForKey:@"dispatchQueue"];
	_dispatchQueue = dispatchQueue;
	[self didChangeValueForKey:@"dispatchQueue"];
	isMainQueue = (dispatchQueue == nil || dispatchQueue == dispatch_get_main_queue());
	if (!isMainQueue && dispatchQueue) {
		dispatch_queue_set_specific(dispatchQueue, (__bridge void *)self, (__bridge void *)self, nil);
	}
}

- (void) addSubscriber:(GRSubscriber *)subscriber {
	dispatch_sync(_privateQ, ^{
		subscriber.parent = self;
		[subscribers addObject:subscriber];
	});
}

- (void) removeSubscriber:(GRSubscriber *)subscriber {
	dispatch_sync(_privateQ, ^{
		subscriber.parent = nil;
		[subscribers removeObject:subscriber];
	});
}

- (void) runOnQueue:(void (^)())block {
	if (self.asynchronous) {
		dispatch_async(self.dispatchQueue?:dispatch_get_main_queue(), block);
	}
	else if (isMainQueue && [NSThread isMainThread]) {
		block();
	}
	else if (dispatch_get_specific((__bridge void *)self) == (__bridge void *)self) {
		block();
	}
	else {
		// if self.asynchronous is NO, we will still dispatch asynchronously if we aren't on the correct queue
		dispatch_async(self.dispatchQueue, block);
	}
}

- (void) next:(id)value {
	[self runOnQueue:^{
		__block NSArray *subCopy;
		dispatch_sync(_privateQ, ^{
			subCopy = [subscribers copy];
		});
		for (GRSubscriber *subscriber in subCopy) {
			[subscriber next:value];
		}
	}];
}

- (void) error:(NSError *)error {
	[self runOnQueue:^{
		__block NSArray *subCopy;
		dispatch_sync(_privateQ, ^{
			subCopy = [subscribers copy];
		});
		for (GRSubscriber *subscriber in subCopy) {
			[subscriber error:error];
		}
		erroredOut = YES;
		dispatch_sync(_privateQ, ^{
			[subscribers removeAllObjects];
		});
	}];
}

- (void) complete {
	[self runOnQueue:^{
		if (!complete) {
			__block NSArray *subCopy;
			dispatch_sync(_privateQ, ^{
				subCopy = [subscribers copy];
			});
			for (GRSubscriber *subscriber in subCopy) {
				[subscriber complete];
			}
			complete = YES;
			dispatch_sync(_privateQ, ^{
				[subscribers removeAllObjects];
			});
		}
	}];
}

@end

@interface GRObservable ()
{
	GRObserver *_observer;
}

@property (nonatomic, copy) void (^block)(GRObserver* observer);
@property (nonatomic, weak) GRSubscriber *subscriptionToOtherObservable;
@property (nonatomic, strong) id observing;
@property (nonatomic, strong) NSString *keyPath;


@end


@interface GRSubscriber ()

@property (nonatomic, copy) void (^nextBlock)(id value);
@property (nonatomic, copy) void (^errorBlock)(NSError *error);
@property (nonatomic, copy) void (^completeBlock)();

@end

@implementation GRSubscriber

+ (DDLogLevel)ddLogLevel {
	return GRSub_ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel {
	GRSub_ddLogLevel = logLevel;
}


+ (GRSubscriber *) next:(void (^)(id value))next error:(void (^)(NSError *error))error complete:(void (^)())complete {
	GRSubscriber *sub = [[GRSubscriber alloc] init];
	sub.nextBlock = next;
	sub.errorBlock = error;
	sub.completeBlock = complete;
	return sub;
}

+ (GRSubscriber *) next:(void (^)(id value))next error:(void (^)(NSError *error))error {
	return [self next:next error:error complete:nil];
	
}
+ (GRSubscriber *) next:(void (^)(id value))next {
	return [self next:next error:nil complete:nil];
}

- (BOOL) gr_isEqual:(id)otherObject {
	return [self isEqual:otherObject];
}

- (void) dealloc {
	DDLogDebug(@"dealloc of GRSubscriber<%p> called", self);
}

- (void) next:(id)value {
	if (self.nextBlock) {
		self.nextBlock(value);
	}
}

- (void) error:(NSError *)error {
	if (self.errorBlock) {
		self.errorBlock(error);
	}
	[self unsubscribe];
}

- (void) complete {
	if (self.completeBlock) {
		self.completeBlock();
	}
	[self unsubscribe];
}

- (void) unsubscribe {
	[self.parent removeSubscriber:self];
}

@end

#undef LOG_LEVEL_DEF
#define LOG_LEVEL_DEF GRObs_ddLogLevel

static DDLogLevel GRObs_ddLogLevel = DDLogLevelInfo;

@implementation GRObservable

+ (DDLogLevel)ddLogLevel {
	return GRObs_ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel {
	GRObs_ddLogLevel = logLevel;
}

+ (void) load {
	_privateQ = dispatch_queue_create("net.mr-r.GRObservable-private", NULL);
}

+ (GRObservable<id>*) withBlock:(void (^)(GRObserver<id>* observer))block {
	GRObservable *observable = [[GRObservable alloc] init];
	observable.block = block;
	return observable;
}

+ (GRObservable<id> *(^)(void (^)(GRObserver<id>* observer)))observable {
	return ^GRObservable*(void (^observer)(GRObserver *)) {
		GRObservable *observable = [[GRObservable alloc] init];
		observable.block = observer;
		return observable;
	};
}
+ (GRObservable<NSDictionary<NSKeyValueChangeKey,id>*> *)observableFor:(id<NSObject>)object keyPath:(NSString *)keypath {
	GRObservable *observable = [[GRObservable alloc] init];
	observable.keyPath = keypath;
	observable.observing = object;
	return observable;
}

- (void) setObserving:(id)observing {
	[_observing removeObserver:self forKeyPath:self.keyPath];
	[self willChangeValueForKey:@"observing"];
	_observing = observing;
	[self didChangeValueForKey:@"observing"];
	[observing addObserver:self forKeyPath:self.keyPath options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)(self.keyPath)];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	if (context == (__bridge void * _Nullable)(self.keyPath)) {
		[_observer next:change];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (id) init {
	self = [super init];
	if (self) {
		self.asynchronous = NO;
		self.dispatchQueue = dispatch_get_main_queue();
	}
	return self;
}

- (void) dealloc {
	DDLogDebug(@"dealloc of GRObservable<%p> (%@) called", self, self.name);
	if (self.subscriptionToOtherObservable) {
		[self.subscriptionToOtherObservable unsubscribe];
		self.subscriptionToOtherObservable = nil;
	}
	self.observing = nil;
	_observer = nil;
}

- (GRSubscriber<id> *(^)(id nextOrSubscriber))subscribe {
	return ^GRSubscriber*(id nextOrSubscriber) {
		BOOL shouldExecuteBlock = NO;
		if (!_observer) {
			_observer = [[GRObserver alloc] init];
			_observer.asynchronous = self.asynchronous;
			_observer.dispatchQueue = self.dispatchQueue;
			shouldExecuteBlock = YES;
		}
		GRSubscriber *toReturn = nil;
		if ([nextOrSubscriber isKindOfClass:[GRSubscriber class]]) {
			toReturn = nextOrSubscriber;
		}
		else if (nextOrSubscriber) {
			GRSubscriber *sub = [[GRSubscriber alloc] init];
			sub.nextBlock = nextOrSubscriber;
			toReturn = sub;
		}
		if (toReturn) [_observer addSubscriber:toReturn];
		if (shouldExecuteBlock && self.block) {
			self.block(_observer);
			self.block = nil;
		}
		return toReturn;
	};
}

- (GRSubscriber<id> *(^)(GRObservableNextBlock, GRObservableErrorBlock, GRObservableCompleteBlock))subscribeWithLiterals
{
	
	return ^GRSubscriber*(GRObservableNextBlock next, GRObservableErrorBlock error, GRObservableCompleteBlock completeBlock) {
		if (!next && !error && !completeBlock) {
			@throw [NSException exceptionWithName:@"NSInternalConsistencyException" reason:[NSString stringWithFormat:@"subscribeWithLiterals requires at least 1 block (given next: %@, error: %@, complete %@)", next, error, completeBlock] userInfo:nil];
		}
		GRSubscriber *sub = [[GRSubscriber alloc] init];
		sub.nextBlock = next;
		sub.errorBlock = error;
		sub.completeBlock = completeBlock;
		return self.subscribe(sub);
	};
}

- (GRObservable<id> *(^)(BOOL (^)(id prev, id cur))) distinctUntilChanged {
	return ^GRObservable*(BOOL (^comparisonBlock)(id prev, id current)) {
		__block __weak GRObserver* observer = nil;
		__block id prevValue = nil;
		__block GRObservable *toReturn = nil;
		toReturn = GRObservable.observable(^(GRObserver* passedIn) {
			observer = passedIn;
			toReturn.subscriptionToOtherObservable = self.subscribeWithLiterals(^(id value) {
				BOOL shouldPassAlong = NO;
				if (prevValue == nil) {
					shouldPassAlong = YES;
				}
				else if (comparisonBlock) {
					shouldPassAlong = (comparisonBlock(prevValue, value) == NO);
				}
				else {
					if ([prevValue respondsToSelector:@selector(gr_isEqual:)]) {
						shouldPassAlong = ([prevValue gr_isEqual:value] == NO);
					}
					else {
						shouldPassAlong = ([prevValue isEqual:value] == NO);
					}
				}
				
				if (shouldPassAlong) {
					[observer next:value];
					prevValue = value;
				}
				
			}, ^(NSError *error) {
				[observer error:error];
				observer = nil;
				prevValue = nil;
			}, ^{
				[observer complete];
				observer = nil;
				prevValue = nil;
			});
			if (observer) {
				objc_setAssociatedObject(toReturn, &associatedObserverKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}
		});
		return toReturn;
	};
}


@end
