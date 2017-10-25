//
//  GPChevronButton.m
//  GRToolkit
//
//  Created by Grant Robinson on 5/19/15.
//  Copyright (c) 2015 Grant Robinson. All rights reserved.
//

#import "GRChevronButton.h"

@implementation GRChevronButton

@synthesize size;

- (id) initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self setNeedsDisplay];
	}
	return self;
}

- (void) setLineColor:(UIColor *)lineColor {
	[self willChangeValueForKey:@"lineColor"];
	_lineColor = lineColor;
	[self didChangeValueForKey:@"lineColor"];
	[self setNeedsDisplay];
}

- (void) setLineWidth:(CGFloat)lineWidth {
	[self willChangeValueForKey:@"lineColor"];
	_lineWidth = lineWidth;
	[self didChangeValueForKey:@"lineColor"];
	[self setNeedsDisplay];
}

- (void) setSize:(CGSize)_size {
	[self willChangeValueForKey:@"size"];
	size = _size;
	[self didChangeValueForKey:@"size"];
	[self setNeedsDisplay];
}

- (void) setDirection:(NSInteger)direction {
	[self willChangeValueForKey:@"direction"];
	if (direction >= 1 && direction <= 4) {
		_direction = direction;
	}
	else {
		_direction = GRCheveronRight;
	}
	[self didChangeValueForKey:@"direction"];
	[self setNeedsDisplay];
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetStrokeColorWithColor(ctx, self.lineColor.CGColor);
	CGContextSetLineWidth(ctx, self.lineWidth);
	
	CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
	CGContextBeginPath(ctx);
	GRChevronDirection direction = self.direction;
	switch (direction) {
		case GRCheveronRight:
			CGContextMoveToPoint(ctx, center.x - (size.width / 2.0), center.y - (size.height / 2.0));
			CGContextAddLineToPoint(ctx, center.x + (size.width / 2.0), center.y);
			CGContextAddLineToPoint(ctx, center.x - (size.width / 2.0), center.y + (size.height / 2.0));
			break;
		case GRChevronLeft:
			CGContextMoveToPoint(ctx, center.x + (size.width / 2.0), center.y - (size.height / 2.0));
			CGContextAddLineToPoint(ctx, center.x - (size.width / 2.0), center.y);
			CGContextAddLineToPoint(ctx, center.x + (size.width / 2.0), center.y + (size.height / 2.0));
			break;
		case GRChevronUp:
			break;
		case GRChevronDown:
			break;
	}
	CGContextStrokePath(ctx);

}

@end
