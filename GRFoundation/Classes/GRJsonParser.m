//
//  GRJsonParser.m
//  Pods
//
//  Created by Grant Robinson on 4/18/17.
//
//

#import "GRJsonParser.h"
#import "GRJson.h"

@interface GRJsonParser () <GRJsonDelegate>
{
	NSMutableArray *stack;
	NSMutableArray <NSNumber*> *parserState;
	NSNumberFormatter *converter;
}


@end

@implementation GRJsonParser

@synthesize ignoreNulls;

+ (id) JSONObjectFromData:(NSData *)data error:(NSError *__autoreleasing *)errorOut {
	GRJsonParser *myself = [[GRJsonParser alloc] init];
	GRJson *parser = [[GRJson alloc] initWithData:data delegate:myself];
	NSError *error = nil;
	BOOL success = [parser parse:&error];
	if (!success || error) {
		NSLog(@"error parsing JSON: %@", error);
		if (errorOut) {
			*errorOut = error;
		}
	}
	return myself->stack.lastObject;
}

- (id) init {
	self = [super init];
	if (self) {
		stack = [NSMutableArray arrayWithCapacity:3];
		parserState = [@[] mutableCopy];
		converter = [[NSNumberFormatter alloc] init];
	}
	return self;
}

- (GRJsonParserState) parserState {
	return parserState.lastObject.integerValue;
}

- (void) storeValue:(id)value {
	switch ([self parserState]) {
		case GRJPSRoot:
		{
			[stack addObject:value];
			break;
		}
		case GRJPSInObject:
		{
			NSString *key = stack.lastObject;
			[stack removeLastObject];
			NSMutableDictionary *dict = stack.lastObject;
			if (value == nil && !ignoreNulls) {
				value = [NSNull null];
			}
			if (value) {
				dict[key] = value;
			}
			break;
		}
		case GRJPSInArray:
		{
			NSMutableArray *array = stack.lastObject;
			[array addObject:value];
			break;
		}
	}
}

- (void) json_null {
	[self storeValue:nil];
}

- (void) json_bool:(BOOL)boolVal {
	[self storeValue:@(boolVal)];
}

- (void) json_string:(NSString *)strVal {
	[self storeValue:strVal];
}

- (void) json_array_begin {
	NSMutableArray *array = [NSMutableArray array];
	[stack addObject:array];
	[parserState addObject:@(GRJPSInArray)];
}

- (void) json_array_end {
	[parserState removeLastObject];
	if ([self parserState] != GRJPSRoot) {
		NSArray *finished = stack.lastObject;
		[stack removeLastObject];
		[self storeValue:finished];
	}
}

- (void) json_object_begin {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	[stack addObject:dict];
	[parserState addObject:@(GRJPSInObject)];
}

- (void) json_object_end {
	[parserState removeLastObject];
	if ([self parserState] != GRJPSRoot) {
		NSDictionary *finished = stack.lastObject;
		[stack removeLastObject];
		[self storeValue:finished];
	}
}

- (void) json_object_key:(NSString *)key {
	[stack addObject:key];
}


- (void) json_number:(const unsigned char *)numberVal length:(unsigned long)len {
	NSString *str = [[NSString alloc] initWithBytes:numberVal length:len encoding:NSUTF8StringEncoding];
	[self storeValue:[converter numberFromString:str]];
}

@end
