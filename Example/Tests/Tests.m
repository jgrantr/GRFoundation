//
//  GRFoundationTests.m
//  GRFoundationTests
//
//  Created by Grant Robinson on 11/07/2016.
//  Copyright (c) 2016 Grant Robinson. All rights reserved.
//

// https://github.com/Specta/Specta

#import <GRFoundation/GRFoundation.h>

struct TestSerializeStruct {
	double value1;
	double value2;
};

typedef struct TestSerializeStruct TestSerializeStruct;

@interface TestSerializeClass : NSObject

@property (nonatomic, strong) NSString *stringValue;
@property (nonatomic, strong) NSNumber *numberValue;
@property (nonatomic) double doubleValue;
@property (nonatomic) int intValue;
@property (nonatomic) TestSerializeStruct structValue;

@end

@implementation TestSerializeClass

- (instancetype) init {
	self = [super init];
	if (self) {
		_stringValue = @"Hello World";
		_numberValue = @(2);
		_doubleValue = 2.0;
		_intValue = 3;
		_structValue = (struct TestSerializeStruct){1, 2};
	}
	return self;
}

@end

@interface TestSerializeClassWithConversion : NSObject

@property (nonatomic, strong) NSString *stringValue;
@property (nonatomic, strong) NSNumber *numberValue;
@property (nonatomic) double doubleValue;
@property (nonatomic) int intValue;
@property (nonatomic) TestSerializeStruct structValue;

@end

@implementation TestSerializeClassWithConversion

GROConvertToJSON(structValue, ^id(void) {
	return (@{@"value1" : @(self.structValue.value1), @"value2" : @(self.structValue.value2)});
})

- (instancetype) init {
	self = [super init];
	if (self) {
		_stringValue = @"Hello World";
		_numberValue = @(2);
		_doubleValue = 2.0;
		_intValue = 3;
		_structValue = (struct TestSerializeStruct){1, 2};
	}
	return self;
}

@end

@interface TestSerializeClassPreferConvert : NSObject

@property (nonatomic, strong) NSString *stringValue;
@property (nonatomic, strong) NSNumber *numberValue;
@property (nonatomic) double doubleValue;
@property (nonatomic) int intValue;
@property (nonatomic) int overrideValue;

@end

@implementation TestSerializeClassPreferConvert

GROConvertToJSON(overrideValue, ^id(void) {
	return @(10);
})

- (instancetype) init {
	self = [super init];
	if (self) {
		_stringValue = @"Hello World";
		_numberValue = @(2);
		_doubleValue = 2.0;
		_intValue = 3;
		_overrideValue = 5;
	}
	return self;
}

@end

@interface CustomClassWithExclusions : NSObject

@property (nonatomic, strong) NSString *prop1;
@property (nonatomic, strong) NSString *excluded;

@end

@implementation CustomClassWithExclusions

+ (NSSet<NSString*> *) excludePropertiesFromJSON {
	return [NSSet setWithArray:@[NSStringFromSelector(@selector(excluded))]];
}

@end

@interface CustomClassWithInclusions : NSObject

@property (nonatomic, strong) NSString *prop1;
@property (nonatomic, strong) NSString *included;

@end

@implementation CustomClassWithInclusions

+ (NSSet<NSString*> *) includePropertiesInJSON {
	return [NSSet setWithArray:@[NSStringFromSelector(@selector(included))]];
}

@end

@interface CustomParentClass : NSObject

@property (nonatomic, strong) NSString *type;

@end

@implementation CustomParentClass

@end

@interface CustomChildClass : CustomParentClass

@property (nonatomic, strong) NSString *type;

@end

@implementation CustomChildClass

@dynamic type;

@end

SpecBegin(InitialSpecs)

describe(@"ConvertToJSON", ^{

	it(@"can serialize", ^{
		TestSerializeClass *toSerialize = [[TestSerializeClass alloc] init];
		NSError *error = nil;
		NSDictionary *json = [GROMapper jsonObjectFrom:toSerialize error:&error];
		expect(json[@"stringValue"]).to.equal(@"Hello World");
		expect(json[@"structValue"]).to.equal(nil);
		expect(json[@"numberValue"]).to.equal(@(2));
		expect(json[@"doubleValue"]).to.equal(@(2.0));
		expect(json[@"intValue"]).to.equal(@(3));
	});
	
	it(@"can custom map", ^{
		TestSerializeClassWithConversion *toSerialize = [[TestSerializeClassWithConversion alloc] init];
		NSError *error = nil;
		NSDictionary *json = [GROMapper jsonObjectFrom:toSerialize error:&error];
		expect(json[@"stringValue"]).to.equal(@"Hello World");
		expect(json[@"numberValue"]).to.equal(@(2));
		expect(json[@"doubleValue"]).to.equal(@(2.0));
		expect(json[@"intValue"]).to.equal(@(3));
		NSDictionary<NSString*,NSNumber*> *structDict = json[@"structValue"];
		expect(structDict[@"value1"]).to.equal(@(1));
		expect(structDict[@"value2"]).to.equal(@(2));
	});
	
	it(@"can prefer convert blocks over property", ^{
		TestSerializeClassPreferConvert *toSerialize = [[TestSerializeClassPreferConvert alloc] init];
		NSError *error = nil;
		NSDictionary *json = [GROMapper jsonObjectFrom:toSerialize error:&error];
		expect(json[@"stringValue"]).to.equal(@"Hello World");
		expect(json[@"numberValue"]).to.equal(@(2));
		expect(json[@"doubleValue"]).to.equal(@(2.0));
		expect(json[@"intValue"]).to.equal(@(3));
		expect(json[@"overrideValue"]).to.equal(@(10));
	});
	
	it(@"can convert nil values", ^{
		TestSerializeClass *toSerialize = [[TestSerializeClass alloc] init];
		toSerialize.stringValue = nil;
		NSError *error = nil;
		NSDictionary *json = [GROMapper jsonObjectFrom:toSerialize error:&error];
		expect(json[@"stringValue"]).to.equal([NSNull null]);
		expect(json[@"structValue"]).to.equal(nil);
		expect(json[@"numberValue"]).to.equal(@(2));
		expect(json[@"doubleValue"]).to.equal(@(2.0));
		expect(json[@"intValue"]).to.equal(@(3));

	});
	
	it(@"can exclude properties", ^{
		CustomClassWithExclusions *toSerialize = [[CustomClassWithExclusions alloc] init];
		toSerialize.prop1 = @"Hello";
		toSerialize.excluded = @"World";
		NSError *error = nil;
		NSDictionary *json = [GROMapper jsonObjectFrom:toSerialize error:&error];
		expect(json[@"excluded"]).to.equal(nil);
		expect(json[@"prop1"]).to.equal(@"Hello");
	});
	
	it(@"can only include certain properties", ^{
		CustomClassWithInclusions *toSerialize = [[CustomClassWithInclusions alloc] init];
		toSerialize.prop1 = @"Hello";
		toSerialize.included = @"World";
		NSError *error = nil;
		NSDictionary *json = [GROMapper jsonObjectFrom:toSerialize error:&error];
		expect(json[@"prop1"]).to.equal(nil);
		expect(json[@"included"]).to.equal(@"World");
	});
	
	it(@"can map re-declared properties of a child class", ^{
		CustomChildClass *toSerialize = [[CustomChildClass alloc] init];
		toSerialize.type = @"Tall";
		NSError *error = nil;
		NSDictionary *json = [GROMapper jsonObjectFrom:toSerialize error:&error];
		expect(json[@"type"]).to.equal(@"Tall");
	});
});

describe(@"GRKVOObservable", ^{
	
	it(@"can deliver initial values upon subscription", ^{
		TestSerializeClass *toObserve = [[TestSerializeClass alloc] init];
		__block GRKVObservable<NSString*> *observable = [GRKVObservable forObject:toObserve keyPath:@"stringValue"];
		__block NSString *initialValue = nil;
		observable.subscribeWithLiterals(^(NSString *value) {
			initialValue = value;
		}, nil, nil);
		waitUntil(^(DoneCallback done) {
			dispatch_async(dispatch_get_main_queue(), ^{
				expect(initialValue).to.equal(@"Hello World");
			});
			observable = nil;
			done();
		});
	});
	
	it(@"can deliver latest values upon subscription", ^{
		TestSerializeClass *toObserve = [[TestSerializeClass alloc] init];
		GRKVObservable<NSString*> *observable = [GRKVObservable forObject:toObserve keyPath:@"stringValue"];
		GRSubscriber<NSString *> *sub1 = observable.subscribeWithLiterals(^(NSString *value) {
			
		}, nil, nil);
		[sub1 unsubscribe];
		toObserve.stringValue = @"2nd Value";
		__block NSString *currentValue = nil;
		observable.subscribeWithLiterals(^(NSString *value) {
			currentValue = value;
		}, nil, nil);
		expect(currentValue).to.equal(@"2nd Value");
	});
});

describe(@"GRObservable", ^{
	
	it(@"can deliver latest values upon subscription", ^{
		__block GRObserver<NSString*> *myObserver = nil;
		GRObservable<NSString*> *observable = [GRObservable withBlock:^(GRObserver *observer) {
			myObserver = observer;
		}];
		observable.deliverCurrentValueUponSubscription = YES;
		GRSubscriber<NSString*> *sub1 = observable.subscribeWithLiterals(^(NSString *value) {
			
		}, nil, nil);
		[sub1 unsubscribe];
		[myObserver next:@"Value 1"];
		__block NSString *value1 = nil;
		GRSubscriber<NSString*> *sub2 = observable.subscribeWithLiterals(^(NSString *value) {
			value1 = value;
		}, nil, nil);
		expect(value1).to.equal(@"Value 1");
		[sub2 unsubscribe];
		[myObserver next:@"Value 2"];
		__block NSString *value2 = nil;
		GRSubscriber<NSString *> *sub3 = observable.subscribeWithLiterals(^(NSString *value) {
			value2 = value;
		}, nil, nil);
		expect(value2).to.equal(@"Value 2");
		[sub3 unsubscribe];
		observable = nil;
		myObserver = nil;
	});
	
});

describe(@"HMAC-SHA1", ^{
	it(@"can create HMAC-SHA1 signatures", ^{
		NSString *base64Secret = [[@"***REMOVED***" stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
		NSData *secret = [[NSData alloc] initWithBase64EncodedString:base64Secret options:0];
		NSString *urlPortion = @"/maps/api/staticmap?size=96x96&zoom=18&center=40.382%2C-111.732&maptype=satellite&key=***REMOVED***&scale=2";
		NSString *base64NonSafe = [urlPortion hmacSHA1UsingSecret:secret];
		NSString *base64WebSafe = [[base64NonSafe stringByReplacingOccurrencesOfString:@"+" withString:@"-"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
		expect(base64WebSafe).to.equal(@"zAMUC8cOGbDJXUi6678709jxeaU=");
	});
});

describe(@"these will pass", ^{
    
    it(@"can do maths", ^{
        expect(1).beLessThan(23);
    });
    
    it(@"can read", ^{
        expect(@"team").toNot.contain(@"I");
    });
    
    it(@"will wait and succeed", ^{
        waitUntil(^(DoneCallback done) {
            done();
        });
    });
});

SpecEnd

