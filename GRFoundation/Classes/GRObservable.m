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

@property (nonatomic, weak) GRObservable *parent;

@end

@interface GRObservable () <GRObserver>
{
	NSMutableArray <GRSubscriber *> *subscribers;
	BOOL erroredOut;
	BOOL complete;
}

@property (nonatomic, copy) void (^block)(id<GRObserver> observer);
@property (nonatomic, weak) GRSubscriber *subscriptionToOtherObservable;
@property (nonatomic, strong) id observing;
@property (nonatomic, strong) NSString *keyPath;

- (void) addSubscriber:(GRSubscriber *)subscriber;
- (void) removeSubscriber:(GRSubscriber *)subscriber;

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

+ (instancetype) withBlock:(void (^)(id<GRObserver> observer))block {
	GRObservable *observable = [[GRObservable alloc] init];
	observable.block = block;
	return observable;
}

+ (GRObservable *(^)(void (^)(id<GRObserver> observer)))observable {
	return ^GRObservable*(void (^observer)(id<GRObserver>)) {
		GRObservable *observable = [[GRObservable alloc] init];
		observable.block = observer;
		return observable;
	};
}
+ (GRObservable* )observableFor:(id<NSObject>)object keyPath:(NSString *)keypath {
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
		[self next:change];
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (id) init {
	self = [super init];
	if (self) {
		subscribers = [NSMutableArray arrayWithCapacity:1];
	}
	return self;
}

- (void) dealloc {
	DDLogDebug(@"dealloc of GRObservable<%p> called", self);
	if (self.subscriptionToOtherObservable) {
		[self.subscriptionToOtherObservable unsubscribe];
		self.subscriptionToOtherObservable = nil;
	}
	self.observing = nil;
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

- (void) next:(id)value {
	dispatch_async(dispatch_get_main_queue(), ^{
		__block NSArray *subCopy;
		dispatch_sync(_privateQ, ^{
			subCopy = [subscribers copy];
		});
		for (GRSubscriber *subscriber in subCopy) {
			[subscriber next:value];
		}
	});
}

- (void) error:(NSError *)error {
	dispatch_async(dispatch_get_main_queue(), ^{
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
	});
}

- (void) complete {
	dispatch_async(dispatch_get_main_queue(), ^{
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
	});
}

- (GRSubscriber *(^)(id nextOrSubscriber))subscribe {
	return ^GRSubscriber*(id nextOrSubscriber) {
		BOOL shouldExecuteBlock = NO;
		if (subscribers.count == 0) {
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
		if (toReturn) [self addSubscriber:toReturn];
		if (shouldExecuteBlock && self.block) {
			self.block(self);
		}
		return toReturn;
	};
}

- (GRSubscriber *(^)(GRObservableNextBlock, GRObservableErrorBlock, GRObservableCompleteBlock))subscribeWithLiterals
{
	
	return ^GRSubscriber*(GRObservableNextBlock next, GRObservableErrorBlock error, GRObservableCompleteBlock completeBlock) {
		if (!next && !error && !complete) {
			@throw [NSException exceptionWithName:@"NSInternalConsistencyException" reason:[NSString stringWithFormat:@"subscribeWithLiterals requires at least 1 block (given next: %@, error: %@, complete %@)", next, error, completeBlock] userInfo:nil];
		}
		GRSubscriber *sub = [[GRSubscriber alloc] init];
		sub.nextBlock = next;
		sub.errorBlock = error;
		sub.completeBlock = completeBlock;
		return self.subscribe(sub);
	};
}

- (GRObservable *(^)(BOOL (^)(id prev, id cur))) distinctUntilChanged {
	return ^GRObservable*(BOOL (^comparisonBlock)(id prev, id current)) {
		__block __weak id<GRObserver> observer = nil;
		__block id prevValue = nil;
		GRObservable *toReturn = GRObservable.observable(^(id<GRObserver> _observer) {
			observer = _observer;
		});
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
		return toReturn;
	};
}


@end
