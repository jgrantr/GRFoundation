//
//  URLBuilder.m
//
//  Created by Grant Robinson on 8/23/10.
//  Copyright 2010 Grant Robinson. All rights reserved.
//

#import "GRURLBuilder.h"
#import "Logging.h"

static NSMutableDictionary * parseArgs(NSString *queryString) {
	NSArray *args = [queryString componentsSeparatedByString:@"&"];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:args.count];
	for (NSString *arg in args) {
		NSArray *pairs = [arg componentsSeparatedByString:@"="];
		if (pairs.count == 2) {
			dict[[pairs objectAtIndex:0]] = [(NSString *)[pairs objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		}
	}
	return dict;
}

@interface GRURLBuilder () {
	NSMutableDictionary *params;
}

@property (nonatomic, strong) NSMutableDictionary *params;

@end

@implementation GRURLBuilder

@synthesize params;

+ (DDLogLevel)ddLogLevel {
	return ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel {
	ddLogLevel = logLevel;
}


- (id) init {
	self = [super init];
	params = [[NSMutableDictionary alloc] init];
	return self;
}

- (void) dealloc {
	if (params) {
		params = nil;
	}
}

+ (GRURLBuilder *) builder {
	GRURLBuilder *builder = [[GRURLBuilder alloc] init];
	return builder;
}

+ (GRURLBuilder *) builderWithBuilder:(GRURLBuilder *)otherBuilder {
	GRURLBuilder *builder = [[GRURLBuilder alloc] init];
	if (otherBuilder) {
		builder.params = [otherBuilder.params mutableCopy];
	}
	return builder;
}

+ (GRURLBuilder *) builderFromQueryString:(NSString *)queryString {
	GRURLBuilder *builder = [[GRURLBuilder alloc] init];
	NSMutableDictionary *args = parseArgs(queryString);
	if (args.count > 0) {
		[builder addDictionary:args];
	}
	return builder;
}

- (NSUInteger) count {
	return [params count];
}

- (id) objectForKeyedSubscript:(id<NSCopying>)key {
	return params[key];
}

- (void) setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
	if ([obj isKindOfClass:[NSDictionary class]]) {
		[(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			[params setObject:[obj description] forKey:key];
		}];
	}
	else {
		if (key && obj) {
			id value = nil;
			if ([obj isKindOfClass:[NSArray class]]) {
				value = obj;
			}
			else {
				value = [obj description];
			}
			[params setObject:value forKey:key];
		}
		else if (key && obj == nil) {
			[params removeObjectForKey:key];
		}
		else {
			DDLogWarn(@"not setting value '%@' for key '%@'", obj, key);
		}
	}
}

- (void) addParam:(id)param forKey:(NSString *)key {
	[params setObject:param forKey:key];
}

- (void) addDictionary:(NSDictionary *)dict {
	for (NSString *key in dict) {
		[params setObject:[[dict objectForKey:key] description] forKey:key];
	}
}

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id  _Nullable __unsafe_unretained [])buffer count:(NSUInteger)len
{
	return [params countByEnumeratingWithState:state objects:buffer count:len];
}

- (void) enumerateKeysAndObjectsUsingBlock:(void (^)(NSString *, id, BOOL *))block {
	[params enumerateKeysAndObjectsUsingBlock:block];
}

- (NSString *) urlString {
	NSString *(^escapeString)(NSString*) = ^NSString*(NSString *obj) {
		NSString *value = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
			kCFAllocatorDefault,
			(__bridge CFStringRef)obj, NULL,
			CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"),
			CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
		);
		return value;
	};
	NSMutableArray *strings = [[NSMutableArray alloc] initWithCapacity:params.count];
	[params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ([obj isKindOfClass:[NSArray class]]) {
			for (id value in (NSArray *)obj) {
				[strings addObject:[NSString stringWithFormat:@"%@=%@", key, escapeString(value)]];
			}
		}
		else {
			[strings addObject:[NSString stringWithFormat:@"%@=%@", key, escapeString(obj)]];
		}
	}];
	return [strings componentsJoinedByString:@"&"];
}

- (NSString *) jsonString {
    NSError *error = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    if (error) {
        NSLog(@"could not create JSON from dict '%@': %@", params, error);
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return json;
}


@end
