//
//  GRViewController.m
//  GRFoundation
//
//  Created by Grant Robinson on 11/07/2016.
//  Copyright (c) 2016 Grant Robinson. All rights reserved.
//

#import "GRViewController.h"
#import <GRFoundation/GRFoundation.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>

static struct mach_timebase_info info;

__attribute__((constructor)) static void initializeTimeBase() {
	kern_return_t ret = mach_timebase_info(&info);
	if (ret != KERN_SUCCESS) {
		NSLog(@"+++++++++++ Could not get mach timebase info");
	}
	else {
		NSLog(@"timebase initialized");
	}
}

static uint64_t li_currentTime() {
	return mach_absolute_time();
}

static uint64_t li_timeDiffInMicroseconds(uint64_t time1, uint64_t time2) {
	return ((time2 - time1) * info.numer / info.denom) / 1000;
}


struct MyStruct {
	int pot; int lady;
};

typedef struct MyStruct MyStruct;


@interface CustomClass : NSObject

+ (instancetype) fromDict:(NSDictionary *)dict;
+ (instancetype) fromDictSetValue:(NSDictionary *)dict;

@property (nonatomic, strong) NSString *stringVar;
@property (nonatomic, strong) NSDictionary<NSString*,NSNumber*> *peopleILike;
@property (nonatomic, strong) NSSet<NSString*> *favoriteColors;

@end

@interface TestClass : NSObject
+ (instancetype) fromDict:(NSDictionary *)dict;
+ (instancetype) fromDictSetValue:(NSDictionary *)dict;

- (NSString *) instanceMethod1;
- (NSString *) instanceMethod2;
- (NSString *) instanceMethod3;

@property (nonatomic) BOOL boolVar;
@property (nonatomic) int intVar;
@property (nonatomic) NSInteger integerVar;
@property (nonatomic, strong) NSNumber *numberVar;
@property (nonatomic, strong) NSString *stringVar;
@property (nonatomic) struct MyStruct structVar;
@property (nonatomic) MyStruct structTypeVar;
@property (nonatomic, strong) CustomClass *customClassVar;
@property (nonatomic, copy) void (^blockTakesInt)(int myvar);

@end

@implementation CustomClass

GROMap(favoritePeople, peopleILike)

GROConvertValue(favoriteValues, ^id(NSArray *colors){
	return [NSSet setWithArray:colors];
})

+ (instancetype) fromDict:(NSDictionary *)dict {
	CustomClass *custom = [[CustomClass alloc] init];
	custom.stringVar = dict[@"stringVar"];
	custom.peopleILike = dict[@"favoritePeople"];
	custom.favoriteColors = [NSSet setWithArray:dict[@"favoriteColors"]];
	return custom;
}

+ (instancetype) fromDictSetValue:(NSDictionary *)dict {
	CustomClass *custom = [[CustomClass alloc] init];
	[custom setValue:dict[@"stringVar"] forKey:@"stringVar"];
	[custom setValue:dict[@"favoritePeople"] forKey:@"peopleILike"];
	[custom setValue:[NSSet setWithArray:dict[@"favoriteColors"]] forKey:@"favoriteColors"];
	return custom;
}


@end

@implementation TestClass

- (id) convertMyStruct:(NSDictionary *)dict {
	MyStruct my;
	my.pot = [dict[@"pot"] intValue];
	my.lady = [dict[@"lady"] intValue];
	return [NSValue valueWithBytes:&my objCType:@encode(MyStruct)];
}

GROConvertValue(structVar, ^id(NSDictionary *dict){
	return [self convertMyStruct:dict];
});

GROConvertValue(structTypeVar, ^id(NSDictionary *dict){
	MyStruct my;
	my.pot = [dict[@"pot"] intValue];
	my.lady = [dict[@"lady"] intValue];
	return [NSValue valueWithBytes:&my objCType:@encode(MyStruct)];
});


+ (instancetype) fromDict:(NSDictionary *)dict {
	TestClass *test = [[TestClass alloc] init];
	test.boolVar = [dict[@"boolVar"] boolValue];
	test.intVar = [dict[@"intVar"] intValue];
	test.integerVar = [dict[@"integerVar"] integerValue];
	test.numberVar = dict[@"numberVar"];
	test.stringVar = dict[@"stringVar"];
	MyStruct structVar;
	structVar.pot = [dict[@"structVar"][@"pot"] intValue];
	structVar.lady = [dict[@"structVar"][@"lady"] intValue];
	test.structVar = structVar;
	MyStruct structTypeVar;
	structTypeVar.pot = [dict[@"structTypeVar"][@"pot"] intValue];
	structTypeVar.lady = [dict[@"structTypeVar"][@"lady"] intValue];
	test.structTypeVar = structTypeVar;
	test.customClassVar = [CustomClass fromDict:dict[@"customClassVar"]];
	return test;
}

+ (instancetype) fromDictSetValue:(NSDictionary *)dict {
	TestClass *test = [[TestClass alloc] init];
	[test setValue:dict[@"boolVar"] forKey:@"boolVar"];
	[test setValue:dict[@"intVar"] forKey:@"intVar"];
	[test setValue:dict[@"integerVar"] forKey:@"integerVar"];
	[test setValue:dict[@"numberVar"] forKey:@"numberVar"];
	[test setValue:dict[@"stringVar"] forKey:@"stringVar"];
	MyStruct structVar;
	structVar.pot = [dict[@"structVar"][@"pot"] intValue];
	structVar.lady = [dict[@"structVar"][@"lady"] intValue];
	[test setValue:[NSValue valueWithBytes:&structVar objCType:@encode(MyStruct)] forKey:@"structVar"];
	MyStruct structTypeVar;
	structTypeVar.pot = [dict[@"structTypeVar"][@"pot"] intValue];
	structTypeVar.lady = [dict[@"structTypeVar"][@"lady"] intValue];
	[test setValue:[NSValue valueWithBytes:&structTypeVar objCType:@encode(MyStruct)] forKey:@"structTypeVar"];
	[test setValue:[CustomClass fromDictSetValue:dict[@"customClassVar"]] forKey:@"customClassVar"];
	return test;
}


- (NSString *) instanceMethod1 {
	return @"instanceMethod1";
}
- (NSString *) instanceMethod2 {
	return @"instanceMethod2";
}
- (NSString *) instanceMethod3 {
	return @"instanceMethod3";
}

@end

@interface GRViewController ()
{
	GRObservable<NSNumber*> *observable;
	GRObservable<NSNumber*> *obs2;
	GRObservable *filter;
	GRObservable *destroyQuickly;
	GRObservable<NSDictionary<NSKeyValueChangeKey,id> *> *kvoObservable;
}

@property (nonatomic, strong) NSString *testProperty;

@end

@implementation GRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	observable = GRObservable.observable(^(GRObserver<NSNumber*> *observer) {
		[observer next:@(1)];
		[observer next:@(2)];
		[observer next:@(3)];
		[observer error:[NSError errorWithDomain:@"MyErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"my error"}]];
		[observer complete];
	});
	GRSubscribe(observable, ^(id value) {
		NSLog(@"%@", value);
	}, ^(NSError *error) {
		NSLog(@"error: %@", error);
		observable = nil;
	}, ^() {
		NSLog(@"complete");
		observable = nil;
	});
	
	obs2 = GRObservable.observable(^(GRObserver<NSNumber*> * observer) {
		[observer next:@(1)];
		[observer next:@(5)];
		[observer next:@(10)];
		[observer complete];
	});
	
	GRSubscribe(obs2, ^(id value) {
		NSLog(@"%@", value);
	}, ^(NSError *error) {
		NSLog(@"error in obs2, %@", error);
	}, ^{
		obs2 = nil;
	});
	
	filter = GRObservable.observable(^(GRObserver<NSNumber*>* observer) {
		[observer next:@(1)];
		[observer next:@(1)];
		[observer next:@(1)];
		[observer next:@(2)];
		[observer next:@(2)];
		[observer next:@(2)];
		[observer next:@(1)];
		[observer next:@(3)];
		[observer complete];
	}).distinctUntilChanged(nil);
	
	GRSubscribe(filter,
		^(id value) {
			NSLog(@"filtered: %@", value);
		},
		^(NSError *error) {
			NSLog(@"error, : %@", error);
		},
		^{
			filter = nil;
		}
	);
	
	destroyQuickly = GRObservable.observable(^(GRObserver<NSNumber*>* observer) {
		[observer next:@(1)];
		[observer next:@(1)];
		[observer next:@(1)];
		[observer next:@(2)];
		[observer next:@(2)];
		[observer next:@(2)];
		[observer next:@(1)];
		[observer next:@(3)];
		[observer complete];
	}).distinctUntilChanged(nil);
	
	GRSubscribe(destroyQuickly, ^(id value) {
		NSLog(@"destroyQuickly: %@", value);
	}, ^(NSError *error) {
		NSLog(@"error: %@", error);
	}, ^{
		NSLog(@"complete");
	});
	
	destroyQuickly = nil;
	
	kvoObservable = [GRObservable observableFor:self keyPath:@"testProperty"];
		
	kvoObservable.subscribe(^(NSDictionary<NSKeyValueChangeKey,id> *change) {
		id newValue = change[NSKeyValueChangeNewKey];
		NSLog(@"new value of 'testProperty' is '%@'", newValue);
	});
	
	self.testProperty = @"Hello World!";
	self.testProperty = @"KVO Observing is cool!";
	kvoObservable = nil;
		
	NSData *mapperData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"mapping" withExtension:@"json"]];
	NSError *error = nil;
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:mapperData options:NSJSONReadingMutableContainers error:&error];
	if (!json || error) {
		NSLog(@"error parsing JSON: %@", error);
	}
	else {
		dispatch_async(dispatch_get_main_queue(), ^{
			uint64_t autoMapStart = li_currentTime();
			NSError *error = nil;
			for (int i = 0; i < 1000; i++) {
				TestClass *class = [GROMapper map:json to:[TestClass class] error:&error];
				if (!class || error) {
					NSLog(@"could not map JSON to 'TestClass': %@", error);
				}
			}
			uint64_t autoMapEnd = li_currentTime();
			uint64_t manualMapStart = li_currentTime();
			error = nil;
			for (int i = 0; i < 1000; i++) {
				TestClass *class = [TestClass fromDict:json];
				if (!class || error) {
					NSLog(@"could not map JSON to 'TestClass': %@", error);
				}
			}
			uint64_t manualMapEnd = li_currentTime();
			uint64_t manualWithKVCStart = li_currentTime();
			error = nil;
			for (int i = 0; i < 1000; i++) {
				TestClass *class = [TestClass fromDict:json];
				if (!class || error) {
					NSLog(@"could not map JSON to 'TestClass': %@", error);
				}
			}
			uint64_t manualWithKVCEnd = li_currentTime();
			uint64_t autoTotal = li_timeDiffInMicroseconds(autoMapStart, autoMapEnd);
			uint64_t manualTotal = li_timeDiffInMicroseconds(manualMapStart, manualMapEnd);
			uint64_t kvcTotal = li_timeDiffInMicroseconds(manualWithKVCStart, manualWithKVCEnd);
			NSLog(@"Benchmark Report\n\tauto mapping\t%llu micros (%.14g micros per)\n\tmanual mapping\t%llu micros (%.14g micros per)\n\tmanual (KVC)\t%llu micros (%.14g micros per)\n", autoTotal, (autoTotal / 1000.0), manualTotal, (manualTotal/1000.0), kvcTotal, (kvcTotal/1000.0));
		});
	}
	
	objc_property_t *props;
	unsigned int propsCount;
	if ((props = class_copyPropertyList([TestClass class], &propsCount))) {
		while (propsCount--) {
			const char *propName = property_getName(props[propsCount]);
			const char *attributes = property_getAttributes(props[propsCount]);
			NSLog(@"propName = '%s', attributes = '%s'", propName, attributes);
		}
		free(props);
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		TestClass *testClass = [[TestClass alloc] init];
		Class clazz = [testClass class];
		SEL selector1 = @selector(instanceMethod1);
		SEL selector2 = @selector(instanceMethod2);
		SEL selector3 = @selector(instanceMethod3);
		int numYes = 0;
		int numNo = 0;
		uint64_t selectorStart = li_currentTime();
		for (int i = 0; i < 100000; i++) {
			if ([testClass respondsToSelector:selector1]) {
				numYes++;
			}
			else {
				numNo++;
			}
		}
		uint64_t selectorEnd = li_currentTime();
		NSLog(@"respondsToInstanceMethod1: numYes %d, numNo %d", numYes, numNo);
		numYes = 0;
		numNo = 0;
		uint64_t classRespondsStart = li_currentTime();
		for (int i = 0; i < 100000; i++) {
			if (class_respondsToSelector(clazz, selector2)) {
				numYes++;
			}
			else {
				numNo++;
			}
		}
		uint64_t classRespondsEnd = li_currentTime();
		NSLog(@"respondsToInstanceMethod2: numYes %d, numNo %d", numYes, numNo);
		numYes = 0;
		numNo = 0;
		uint64_t methodStart = li_currentTime();
		for (int i = 0; i < 100000; i++) {
			if (class_getInstanceMethod(clazz, selector3) != NULL) {
				numYes++;
			}
			else {
				numNo++;
			}
		}
		uint64_t methodEnd = li_currentTime();
		NSLog(@"respondsToInstanceMethod3: numYes %d, numNo %d", numYes, numNo);
		uint64_t selectorTotal = li_timeDiffInMicroseconds(selectorStart, selectorEnd);
		uint64_t classTotal = li_timeDiffInMicroseconds(classRespondsStart, classRespondsEnd);
		uint64_t methodTotal = li_timeDiffInMicroseconds(methodStart, methodEnd);
		NSLog(@"Benchmark Report:\n\trespondsToSelector\t%llu micros\n\tclass_respondsToSelector\t%llu micros\n\tclass_getInstanceMethod\t%llu micros\n", selectorTotal, classTotal, methodTotal);
	});

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
