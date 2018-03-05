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

