//
//  GRViewController.m
//  GRFoundation
//
//  Created by Grant Robinson on 11/07/2016.
//  Copyright (c) 2016 Grant Robinson. All rights reserved.
//

#import "GRViewController.h"
#import <GRFoundation/GRFoundation.h>

@interface GRViewController ()
{
	GRObservable *observable;
	GRObservable *obs2;
	GRObservable *filter;
	GRObservable *destroyQuickly;
	GRObservable *kvoObservable;
}

@property (nonatomic, strong) NSString *testProperty;

@end

@implementation GRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	observable = GRObservable.observable(^(id<GRObserver> observer) {
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
	
	obs2 = GRObservable.observable(^(id<GRObserver> observer) {
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
	
	filter = GRObservable.observable(^(id<GRObserver> observer) {
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
	
	destroyQuickly = GRObservable.observable(^(id<GRObserver> observer) {
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
