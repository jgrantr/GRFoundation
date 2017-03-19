//
//  GRObservable.m
//  Pods
//
//  Created by Grant Robinson on 3/16/17.
//
//

#import "GRObservable.h"

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

- (void) addSubscriber:(GRSubscriber *)subscriber;
- (void) removeSubscriber:(GRSubscriber *)subscriber;

@end


@interface GRSubscriber ()

@property (nonatomic, copy) void (^nextBlock)(id value);
@property (nonatomic, copy) void (^errorBlock)(NSError *error);
@property (nonatomic, copy) void (^completeBlock)();

@end

@implementation GRSubscriber

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
	NSLog(@"dealloc of GRSubscriber<%p> called", self);
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

@implementation GRObservable

+ (void) load {
	_privateQ = dispatch_queue_create("net.mr-r.GRObservable-private", NULL);
}

+ (instancetype) withBlock:(void (^)(id<GRObserver> observer))block {
	GRObservable *observable = [[GRObservable alloc] init];
	observable.block = block;
	return observable;
}

+ (instancetype (^)(void (^)(id<GRObserver> observer)))observable {
	return ^GRObservable*(void (^observer)(id<GRObserver>)) {
		GRObservable *observable = [[GRObservable alloc] init];
		observable.block = observer;
		return observable;
	};
}

- (id) init {
	self = [super init];
	if (self) {
		subscribers = [NSMutableArray arrayWithCapacity:1];
	}
	return self;
}

- (void) dealloc {
	NSLog(@"dealloc of GRObservable<%p> called", self);
	if (self.subscriptionToOtherObservable) {
		[self.subscriptionToOtherObservable unsubscribe];
		self.subscriptionToOtherObservable = nil;
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
			[self addSubscriber:nextOrSubscriber];
		}
		else if (nextOrSubscriber) {
			GRSubscriber *sub = [[GRSubscriber alloc] init];
			sub.nextBlock = nextOrSubscriber;
			toReturn = sub;
		}
		if (shouldExecuteBlock) {
			self.block(self);
		}
		return toReturn;
	};
}

- (GRSubscriber *(^)(int, ...))subscribeWithLiterals {
	return ^GRSubscriber*(int count, ...) {
		if (count == 0) {
			@throw [NSException exceptionWithName:@"NSInternalConsistencyException" reason:@"subscribeWithLiterals needs at least 1 block of type void (^)(id value)" userInfo:nil];
		}
		if (count > 3) {
			@throw [NSException exceptionWithName:@"NSInternalConsistencyException" reason:@"subscriberWithLiterals should have no more than 3 parameters" userInfo:nil];
		}
		GRSubscriber *sub = [[GRSubscriber alloc] init];
		id eachObject = nil;
		va_list args;
		va_start(args, count);
		for (int i = 0; i < count; i++) {
			eachObject = va_arg(args, id);
			if (i == 0) {
				sub.nextBlock = eachObject;
			}
			else if (i == 1) {
				sub.errorBlock = eachObject;
			}
			else if (i == 2){
				sub.completeBlock = eachObject;
			}
		}
		va_end(args);
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
		toReturn.subscriptionToOtherObservable = GRSubscribe(self, ^(id value) {
			BOOL shouldPassAlong = NO;
			if (prevValue == nil) {
				shouldPassAlong = YES;
			}
			else if (comparisonBlock) {
				shouldPassAlong = comparisonBlock(prevValue, value);
			}
			else {
				if ([prevValue respondsToSelector:@selector(gr_isEqual:)]) {
					shouldPassAlong = [prevValue gr_isEqual:value];
				}
				else {
					shouldPassAlong = [prevValue isEqual:value];
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
