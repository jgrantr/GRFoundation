//
//  GPChevronButton.h
//  GRToolkit
//
//  Created by Grant Robinson on 5/19/15.
//  Copyright (c) 2015 Grant Robinson. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GRChevronDirection) {
	GRCheveronRight=1,
	GRChevronLeft=2,
	GRChevronUp=3,
	GRChevronDown=4,
};

IB_DESIGNABLE
@interface GRChevronButton : UIButton

@property (nonatomic, strong) IBInspectable UIColor *lineColor;
@property (nonatomic, assign) IBInspectable CGFloat lineWidth;
@property (nonatomic, assign) IBInspectable CGSize size;
@property (nonatomic, assign) IBInspectable NSInteger direction;

@end
