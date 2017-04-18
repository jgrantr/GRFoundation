//
//  GRJson.m
//  Pods
//
//  Created by Grant Robinson on 4/17/17.
//
//

#import "GRJson.h"
#import "Logging.h"

typedef void (*VoidFunction)(id ptr, SEL cmd);

static VoidFunction parseObject;

static void (*parseMembers)(id, SEL);
static void (*parsePair)(id, SEL);
static void (*parseString)(id, SEL, BOOL);
static void (*parseEscapedString)(id, SEL, NSMutableString*, BOOL);
static void (*copyStringWithStart)(id, SEL, unsigned long, unsigned long, NSMutableString *);
static void (*skipWhiteSpace)(id, SEL);
static void (*parseValue)(id, SEL);
static void (*parseNumber)(id, SEL);
static void (*parseArray)(id, SEL);
static void (*parseArrayElements)(id, SEL);
static void (*parseBool)(id, SEL);
static void (*parseNull)(id, SEL);
static void (*advance)(id, SEL);
static void (*skip)(id, SEL, int);
static BOOL (*isEof)(id, SEL);


@interface GRJson ()
{
	const char *m_buf;     ///< our buffer we are reading from
	unsigned long m_bufLen; ///< the length of the buffer in bytes
	unsigned long m_pos;    ///< currrent position
	int m_objectLevel;     ///< if non-zero, indicates the parser is in the midst of parsing a non-top level object or array
	NSMutableString *m_errMsg;   ///< error message if there is an error during parsing
	NSData *data;
	VoidFunction json_null;
	void (*json_bool)(id, SEL, BOOL);
	void (*json_number)(id, SEL, const unsigned char *, unsigned long);
	void (*json_string)(id, SEL, NSString *);
	VoidFunction json_object_begin;
	void (*json_object_key)(id, SEL, NSString *);
	VoidFunction json_object_end;
	VoidFunction json_array_begin;
	VoidFunction json_array_end;

}

- (void) parseObject;
- (void) parseMembers;
- (void) parsePair;
- (void) parseString:(BOOL)isObjectKey;
- (void) parseEscapedString:(NSMutableString *)result isObjectKey:(BOOL)isObjectKey;
- (void) copyToStringWithStart:(unsigned long)startPos end:(unsigned long)endPos str:(NSMutableString *)str;
- (void) skipWhiteSpace;
- (void) parseValue;
- (void) parseNumber;
- (void) parseArray;
- (void) parseArrayElements;
- (void) parseBool;
- (void) parseNull;
- (void) advance;
- (void) skip:(int)amount;
- (BOOL)isEof;
- (void) setError:(NSString *)fmt, ...;

@end

@implementation GRJson

@synthesize delegate, data;

+ (void) initialize {
	parseObject = (VoidFunction)[self instanceMethodForSelector:@selector(parseObject)];
	parseMembers = (VoidFunction)[self instanceMethodForSelector:@selector(parseMembers)];
	parsePair = (VoidFunction)[self instanceMethodForSelector:@selector(parsePair)];
	parseString = (void (*) (id, SEL, BOOL))[self instanceMethodForSelector:@selector(parseString:)];
	parseEscapedString = (void (*) (id, SEL, NSMutableString*, BOOL))[self instanceMethodForSelector:@selector(parseEscapedString:isObjectKey:)];
	copyStringWithStart = (void (*) (id, SEL, unsigned long, unsigned long, NSMutableString*))[self instanceMethodForSelector:@selector(copyToStringWithStart:end:str:)];
	skipWhiteSpace = (VoidFunction)[self instanceMethodForSelector:@selector(skipWhiteSpace)];
	parseValue = (VoidFunction)[self instanceMethodForSelector:@selector(parseValue)];
	parseNumber = (VoidFunction)[self instanceMethodForSelector:@selector(parseNumber)];
	parseArray = (VoidFunction)[self instanceMethodForSelector:@selector(parseArray)];
	parseArrayElements = (VoidFunction)[self instanceMethodForSelector:@selector(parseArrayElements)];
	parseBool = (VoidFunction)[self instanceMethodForSelector:@selector(parseBool)];
	parseNull = (VoidFunction)[self instanceMethodForSelector:@selector(parseNull)];
	advance = (VoidFunction)[self instanceMethodForSelector:@selector(advance)];
	skip = (void (*) (id, SEL, int))[self instanceMethodForSelector:@selector(skip:)];
	isEof = (BOOL (*) (id, SEL))[self instanceMethodForSelector:@selector(isEof)];
}

- (instancetype) initWithData:(NSData *)dataIn delegate:(id<GRJsonDelegate>)delegateIn {
	self = [super init];
	if (self) {
		data = dataIn;
		m_buf = (const char *)[data bytes];
		m_bufLen = [data length];
		m_pos = 0;
		m_objectLevel = 0;
		delegate = delegateIn;
		
		NSObject *object = (NSObject *)delegateIn;
		
		json_null = (VoidFunction)[object methodForSelector:@selector(json_null)];
		json_bool = (void (*)(id, SEL, BOOL))[object methodForSelector:@selector(json_bool:)];
		json_number = (void (*)(id, SEL, const unsigned char *, unsigned long))[object methodForSelector:@selector(json_number:length:)];
		json_string = (void (*)(id, SEL, NSString *))[object methodForSelector:@selector(json_string:)];
		json_object_begin = (VoidFunction)[object methodForSelector:@selector(json_object_begin)];
		json_object_key = (void (*)(id, SEL, NSString *))[object methodForSelector:@selector(json_object_key:)];
		json_object_end = (VoidFunction)[object methodForSelector:@selector(json_object_end)];
		json_array_begin = (VoidFunction)[object methodForSelector:@selector(json_array_begin)];
		json_array_end = (VoidFunction)[object methodForSelector:@selector(json_array_end)];

	}
	return self;
}

- (void) setError:(NSString *)fmt, ... {
	va_list argList;
	va_start(argList, fmt);
	m_errMsg = [[NSMutableString alloc] initWithFormat:fmt arguments:argList];
	va_end(argList);
	@throw [NSError errorWithDomain:@"GRJsonParser" code:-1 userInfo:@{NSLocalizedDescriptionKey: m_errMsg}];
}

- (BOOL) isEof {
	return m_pos >= m_bufLen;
}

- (void) advance {
	m_pos++;
	if (isEof(self, @selector(isEof)) && m_objectLevel > 0) {
		[self setError:@"unexpected EOF"];
		@throw [NSException exceptionWithName:@"GRJsonParserException" reason:@"unexpected EOF" userInfo:@{}];
	}
}

- (void) skip:(int)amount {
	m_pos += amount;
	if (isEof(self, @selector(isEof))) {
		[self setError:@"unexpected EOF while skipping"];
		@throw [NSException exceptionWithName:@"GRJsonParserException" reason:@"unexpected EOF while skipping" userInfo:@{}];
	}
}

/* a lookup table which lets us quickly determine five things:
 * VEC - valid escaped conrol char
 * IJC - invalid json char
 * VHC - valid hex char
 * VWC - valid whitesapce char
 * VNC - valid number character
 * note.  the solidus '/' may be escaped or not.
 * note.  the
 */
#define VEC 1
#define VALID_ESC_CHAR 1
#define IJC 2
#define INVALID_JSON_CHAR 2
#define VHC 4
#define VALID_HEX_CHAR 4
#define VWC 8
#define VALID_WHITESPACE_CHAR 8
#define VNC 16
#define VALID_NUMERIC_CHAR 16
static const char charLookupTable[256] =
{
	/*00*/ IJC    , IJC    , IJC    , IJC    , IJC    , IJC    , IJC    , IJC    ,
	/*08*/ IJC    , IJC|VWC, IJC|VWC, IJC    , IJC    , IJC|VWC, IJC    , IJC    ,
	/*16*/ IJC    , IJC    , IJC    , IJC    , IJC|VWC, IJC    , IJC    , IJC    ,
	/*24*/ IJC    , IJC    , IJC    , IJC    , IJC    , IJC    , IJC    , IJC    ,
	
	/*32*/ VWC    , 0      , VEC|IJC, 0      , 0      , 0      , 0      , 0      ,
	/*40*/ 0      , 0      , 0      , 0      , 0      , 0      , 0      , VEC    ,
	/*48*/ VHC|VNC, VHC|VNC, VHC|VNC, VHC|VNC, VHC|VNC, VHC|VNC, VHC|VNC, VHC|VNC,
	/*56*/ VHC|VNC, VHC|VNC, 0      , 0      , 0      , 0      , 0      , 0      ,
	
	/*64*/ 0      , VHC    , VHC    , VHC    , VHC    , VHC    , VHC    , 0      ,
	/*72*/ 0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	/*80*/ 0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	/*88*/ 0      , 0      , 0      , 0      , VEC|IJC, 0      , 0      , 0      ,
	
	/*96*/ 0      , VHC    , VEC|VHC, VHC    , VHC    , VHC    , VEC|VHC, 0      ,
	/*104*/ 0      , 0      , 0      , 0      , 0      , 0      , VEC    , 0      ,
	/*112*/ 0      , 0      , VEC    , 0      , VEC    , 0      , 0      , 0      ,
	/*120*/ 0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	
	/* include these so we don't have to always check the range of the char */
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0      ,
	0      , 0      , 0      , 0      , 0      , 0      , 0      , 0
};


- (BOOL) parse:(NSError *__autoreleasing *)error {
	BOOL success = YES;
	@try {
		bool moreElements = true;
		while (isEof(self, @selector(isEof)) == false && moreElements == true) {
			switch (m_buf[m_pos]) {
				case '{':
					parseObject(self, @selector(parseObject));
					moreElements = false;
					break;
				case '[':
					parseArray(self, @selector(parseArray));
					moreElements = false;
					break;
				default:
					if (charLookupTable[(int)m_buf[m_pos]] & VALID_WHITESPACE_CHAR) {
						advance(self, @selector(advance));
						break;
					}
					else {
						@throw [NSError errorWithDomain:@"GRJsonParser" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"invalid char '%c' at pos %lu", m_buf[m_pos], m_pos]}];
					}
			}
		}
	} @catch (NSException *exception) {
		DDLogError(@"exception while parsing JSON: %@", exception.reason);
		if (error) {
			*error = [NSError errorWithDomain:@"GRJsonParser" code:-1 userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
		}
		success = NO;
	} @catch(NSError *thrown) {
		DDLogError(@"error while parsing JSON: %@", thrown);
		if (error) {
			*error = thrown;
		}
		success = NO;
	} @finally {
		
	}
	return success;
}

- (void) parseObject {
	json_object_begin(delegate, @selector(json_object_begin));
	m_objectLevel++;
	advance(self, @selector(advance));
	parseMembers(self, @selector(parseMembers));
	if (m_buf[m_pos] == '}') {
		m_objectLevel--;
		advance(self, @selector(advance));
		json_object_end(delegate, @selector(json_object_end));
	}
	else {
		[self setError:@"expected '}' to close object, got '%c' at pos %lu", m_buf[m_pos], m_pos];
	}
}

- (void) parseMembers {
	char nextSym = '"';
	bool hasMoreMembers = true;
	while (hasMoreMembers) {
		skipWhiteSpace(self, @selector(skipWhiteSpace));
		if (m_buf[m_pos] != nextSym) {
			return;
		}
		switch (m_buf[m_pos]) {
			case '"':
				parsePair(self, @selector(parsePair));
				nextSym = ',';
				break;
			case ',':
				advance(self, @selector(advance));
				nextSym = '"';
				break;
			default:
				[self setError:@"expected ',' or '\"', got '%c' at pos %lu", m_buf[m_pos], m_pos];
		}
	}
}

- (void) parsePair {
	parseString(self, @selector(parseString:), YES);
	skipWhiteSpace(self, @selector(skipWhiteSpace));
	if (m_buf[m_pos] != ':') {
		[self setError:@"expected pair-separator ':', got '%c' at pos %lu", m_buf[m_pos], m_pos];
	}
	advance(self, @selector(advance));
	skipWhiteSpace(self, @selector(skipWhiteSpace));
	parseValue(self, @selector(parseValue));
	skipWhiteSpace(self, @selector(skipWhiteSpace));
}

- (void) skipWhiteSpace {
	while (charLookupTable[(int)m_buf[m_pos]] & VALID_WHITESPACE_CHAR) {
		advance(self, @selector(advance));
		if (m_pos >= m_bufLen) {
			[self setError:@"hit EOF while skipping whitespace"];
		}
	}
}

- (void) copyToStringWithStart:(unsigned long)startPos end:(unsigned long)endPos str:(NSMutableString *)str {
	if (endPos - startPos > 0) {
		[str appendString:[[NSString alloc] initWithBytes:m_buf+startPos length:endPos-startPos encoding:NSUTF8StringEncoding]];
	}
}

- (void) parseEscapedString:(NSMutableString *)result isObjectKey:(BOOL)isObjectKey {
	unsigned long startPos = m_pos;
	unsigned long endPos = 0;
	bool isEos = false;
	while (isEos == false) {
		switch (m_buf[m_pos]) {
			case '\\':
				// it is an escape char
				if (charLookupTable[(int)m_buf[m_pos+1]] & VALID_ESC_CHAR) {
					// valid escape char
					copyStringWithStart(self, @selector(copyToStringWithStart:end:str:), startPos, m_pos, result);
					const char *unescaped = "?";
					switch (m_buf[m_pos+1]) {
						case 'r': unescaped = "\r"; break;
						case 'n': unescaped = "\n"; break;
						case '\\': unescaped = "\\"; break;
						case '/': unescaped = "/"; break;
						case '"': unescaped = "\""; break;
						case 'f': unescaped = "\f"; break;
						case 'b': unescaped = "\b"; break;
						case 't': unescaped = "\t"; break;
						default:
							DDLogError(@"mismatch between lookup table and escapes");
							unescaped = "";
							break;
					}
					[result appendFormat:@"%s", unescaped];
					skip(self, @selector(skip:), 2);
					startPos = m_pos;
				}
				else if (m_buf[m_pos+1] == 'u') {
					if (m_pos+6 >= m_bufLen) {
						[self setError:@"un-expected EOF while parsing unicode escape"];
					}
					if ((charLookupTable[(int)m_buf[m_pos+2]] & VALID_ESC_CHAR) &&
						(charLookupTable[(int)m_buf[m_pos+3]] & VALID_ESC_CHAR) &&
						(charLookupTable[(int)m_buf[m_pos+4]] & VALID_ESC_CHAR) &&
						(charLookupTable[(int)m_buf[m_pos+5]] & VALID_ESC_CHAR))
					{
						char temp[5];
						memcpy(temp, m_buf+2, 4);
						temp[4] = '\0';
						[result appendFormat:@"%C", (unsigned short)strtoul(temp, NULL, 16)];
						skip(self, @selector(skip:), 6);
					}
					else {
						[self setError:@"invalid HEX character in unicode escape"];
					}
				}
				else {
					[self setError:@"invalid escape char '%c' at pos %lu", m_buf[m_pos+1], m_pos+1];
				}
				break;
			case '"':
				endPos = m_pos;
				isEos = true;
				advance(self, @selector(advance));
				break;
			default:
				advance(self, @selector(advance));
				break;
		}
	}
	[self copyToStringWithStart:startPos end:endPos str:result];
	if (isObjectKey) {
		json_object_key(delegate, @selector(json_object_key:), result);
	}
	else {
		json_string(delegate, @selector(json_string:), result);
	}
}

- (void) parseString:(BOOL)isObjectKey {
	if (m_buf[m_pos] != '"') {
		[self setError:@"expected '\"', got '%c' at pos %lu", m_buf[m_pos], m_pos];
	}
	advance(self, @selector(advance));
	unsigned long startPos = m_pos;
	unsigned long endPos = 0;
	bool isEos = false;
	while (isEos == false) {
		switch (m_buf[m_pos]) {
			case '\\':
			{
				NSMutableString *strResult = nil;
				if ((m_pos - startPos) > 0) {
					strResult = [NSMutableString stringWithCapacity:m_pos - startPos];
					[strResult appendString:[[NSString alloc] initWithBytes:m_buf+startPos length:m_pos - startPos encoding:NSUTF8StringEncoding]];
				}
				parseEscapedString(self, @selector(parseEscapedString:isObjectKey:), strResult, isObjectKey);
				return;
				break;
			}
			case '"':
				endPos = m_pos;
				isEos = true;
				advance(self, @selector(advance));
				break;
			default:
				advance(self, @selector(advance));
				break;
		}
	}
	unsigned long len = endPos - startPos;
	NSString *value = [[NSString alloc] initWithBytes:m_buf+startPos length:len encoding:NSUTF8StringEncoding];
	if (isObjectKey) {
		json_object_key(delegate, @selector(json_object_key:), value);
	}
	else {
		json_string(delegate, @selector(json_string:), value);
	}
}

- (void) parseValue {
	switch (m_buf[m_pos]) {
		case '"':
			return parseString(self, @selector(parseString:), NO);
			break;
		case '-':
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			return parseNumber(self, @selector(parseNumber));
			break;
		case '[':
			return parseArray(self, @selector(parseArray));
			break;
		case 'f':
			return parseBool(self, @selector(parseBool));
			break;
		case 'n':
			return parseNull(self, @selector(parseNull));
			break;
		case 't':
			return parseBool(self, @selector(parseBool));
			break;
		case '{':
			return parseObject(self, @selector(parseObject));
			break;
		default:
			[self setError:@"unexpected char '%c' at pos %lu", m_buf[m_pos], m_pos];
	}
}

- (void) parseBool {
	if ((m_pos+5) >= m_bufLen) {
		[self setError:@"unexpected EOF while parsing boolean value"];
	}
	bool isValid = false;
	bool val = false;
	if (strncmp(m_buf+m_pos,"true", 4) == 0) {
		isValid = true;
		val = true;
		skip(self, @selector(skip:), 4);
	}
	else if (strncmp(m_buf+m_pos, "false", 5) == 0)
	{
		isValid = true;
		skip(self, @selector(skip:), 5);
	}
	else {
		[self setError:@"invalid boolean value"];
	}
	json_bool(delegate, @selector(json_bool:), val == true);
}

- (void) parseNull {
	if (m_pos+4 >= m_bufLen) {
		[self setError:@"unexpected EOF while parsing null value"];
	}
	if (strncmp(m_buf+m_pos,"null",4) == 0) {
		[delegate json_null];
		skip(self, @selector(skip:), 4);
	}
	[self setError:@"bad literal value (null expected)"];
}

- (void) parseNumber {
	if (m_buf[m_pos] == '-' && !(m_buf[m_pos+1] & VALID_NUMERIC_CHAR)) {
		[self setError:@"missing integer after '-', got '%c' at pos %lu", m_buf[m_pos+1], m_pos+1];
	}
	unsigned long startPos = m_pos;
	advance(self, @selector(advance));
	while (charLookupTable[(int)m_buf[m_pos]] & VALID_NUMERIC_CHAR) {
		advance(self, @selector(advance));
	}
	if (m_buf[m_pos] == '.') {
		advance(self, @selector(advance));
		unsigned long fracPos = m_pos;
		while (charLookupTable[(int)m_buf[m_pos]] & VALID_NUMERIC_CHAR) {
			advance(self, @selector(advance));
		}
		if (fracPos == m_pos) {
			[self setError:@"missing integer after '.', got '%c' at pos %lu", m_buf[m_pos], m_pos];
		}
	}
	if (m_buf[m_pos] == 'e' || m_buf[m_pos] == 'E') {
		advance(self, @selector(advance));
		if (m_buf[m_pos] == '+' || m_buf[m_pos] == '-') {
			advance(self, @selector(advance));
		}
		unsigned long expPos = m_pos;
		while (charLookupTable[(int)m_buf[m_pos]] & VALID_NUMERIC_CHAR) {
			advance(self, @selector(advance));
		}
		if (expPos == m_pos) {
			[self setError:@"missing integer after exponent, got '%c' at pos %lu", m_buf[m_pos], m_pos];
		}
	}
	unsigned long stopPos = m_pos;
	json_number(delegate, @selector(json_number:length:), (const unsigned char *)m_buf+startPos, stopPos-startPos);
}

- (void) parseArray {
	json_array_begin(delegate, @selector(json_array_begin));
	m_objectLevel++;
	advance(self, @selector(advance));
	skipWhiteSpace(self, @selector(skipWhiteSpace));
	if (m_buf[m_pos] != ']') {
		[self parseArrayElements];
	}
	if (m_buf[m_pos] == ']') {
		m_objectLevel--;
		advance(self, @selector(advance));
		json_array_end(delegate, @selector(json_array_end));
	}
	else {
		[self setError:@"expected ']' to close array, got '%c' at pos %lu", m_buf[m_pos], m_pos];
	}
}

- (void) parseArrayElements {
	bool hasMoreMembers = true;
	char nextSym = '\0';
	while (hasMoreMembers) {
		skipWhiteSpace(self, @selector(skipWhiteSpace));
		if (nextSym != '\0' && m_buf[m_pos] != nextSym) {
			return;
		}
		switch (m_buf[m_pos]) {
			case ',':
				advance(self, @selector(advance));
				nextSym = '\0';
				break;
			default:
				[self parseValue];
				nextSym = ',';
				break;
		}
	}
}


@end
