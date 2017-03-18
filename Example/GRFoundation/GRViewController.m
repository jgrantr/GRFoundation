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
}

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
	});
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
