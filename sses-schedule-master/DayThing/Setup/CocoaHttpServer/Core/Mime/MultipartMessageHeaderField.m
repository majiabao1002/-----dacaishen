#import "MultipartMessageHeaderField.h"
#import "HTTPLogging.h"
#pragma mark log level
#ifdef DEBUG
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#else
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#endif
int findChar(const char* str,NSUInteger length, char c);
NSString* extractParamValue(const char* bytes, NSUInteger length, NSStringEncoding encoding);
@interface MultipartMessageHeaderField (private)
-(BOOL) parseHeaderValueBytes:(char*) bytes length:(NSUInteger) length encoding:(NSStringEncoding) encoding;
@end
@implementation MultipartMessageHeaderField
@synthesize name,value,params;
- (id) initWithData:(NSData *)data contentEncoding:(NSStringEncoding)encoding {
	params = [[NSMutableDictionary alloc] initWithCapacity:1];
	char* bytes = (char*)data.bytes;
	NSUInteger length = data.length;
	int separatorOffset = findChar(bytes, length, ':');
	if( (-1 == separatorOffset) || (separatorOffset >= length-2) ) {
		HTTPLogError(@"MultipartFormDataParser: Bad format.No colon in field header.");
		return nil;
	}
	name = [[NSString alloc] initWithBytes: bytes length: separatorOffset encoding: NSASCIIStringEncoding];
	if( nil == name ) {
		HTTPLogError(@"MultipartFormDataParser: Bad MIME header name.");
		return nil;		
	}
	bytes += separatorOffset + 2;
	length -= separatorOffset + 2;
	separatorOffset = findChar(bytes, length, ';');
	if( separatorOffset == -1 ) {
		value = [[NSString alloc] initWithBytes:bytes length: length encoding:encoding];
		if( nil == value ) {
			HTTPLogError(@"MultipartFormDataParser: Bad MIME header value for header name: '%@'",name);
			return nil;		
		}
		return self;
	}
	value = [[NSString alloc] initWithBytes:bytes length: separatorOffset encoding:encoding];
	HTTPLogVerbose(@"MultipartFormDataParser: Processing  header field '%@' : '%@'",name,value);
	bytes += separatorOffset + 2;
	length -= separatorOffset + 2;
	if( ![self parseHeaderValueBytes:bytes length:length encoding:encoding] ) {
		NSString* paramsStr = [[NSString alloc] initWithBytes:bytes length:length encoding:NSASCIIStringEncoding];
		HTTPLogError(@"MultipartFormDataParser: Bad params for header with name '%@' and value '%@'",name,value);
		HTTPLogError(@"MultipartFormDataParser: Params str: %@",paramsStr);
		return nil;		
	}
	return self;
}
-(BOOL) parseHeaderValueBytes:(char*) bytes length:(NSUInteger) length encoding:(NSStringEncoding) encoding {
	int offset = 0;
	NSString* currentParam = nil;
	BOOL insideQuote = NO;
	while( offset < length ) {
		if( bytes[offset] == '\"' ) {
			if( !offset || bytes[offset-1] != '\\' ) {
			   insideQuote = !insideQuote;
			}
		}
		if( insideQuote ) {
			++ offset;
			continue; 
		}
		if( bytes[offset] == '=' ) {
			if( currentParam ) {
				return NO;
			}
			currentParam = [[NSString alloc] initWithBytes:bytes length:offset encoding:NSASCIIStringEncoding];
			bytes+=offset + 1;
			length -= offset + 1;
			offset = 0;
			continue;
		}
		if( bytes[offset] == ';' ) {
			if( !currentParam ) {
				HTTPLogError(@"MultipartFormDataParser: Unexpected ';' when parsing header");
				return NO;
			}
			NSString* paramValue = extractParamValue(bytes, offset,encoding);
			 if( nil == paramValue ) {
				HTTPLogWarn(@"MultipartFormDataParser: Failed to exctract paramValue for key %@ in header %@",currentParam,name);
			}
			else {
#ifdef DEBUG
				if( [params objectForKey:currentParam] ) {
					HTTPLogWarn(@"MultipartFormDataParser: param %@ mentioned more then once in header %@",currentParam,name);
				}
#endif
				[params setObject:paramValue forKey:currentParam];
				HTTPLogVerbose(@"MultipartFormDataParser: header param: %@ = %@",currentParam,paramValue);
			}
			currentParam = nil;
			bytes+=offset + 2;
			length -= offset + 2;
			offset = 0;
		}
		++ offset;
	}
	if( insideQuote ) {
		HTTPLogWarn(@"MultipartFormDataParser: unterminated quote in header %@",name);
	}
	if( currentParam ) {
		NSString* paramValue = extractParamValue(bytes, length, encoding);
		if( nil == paramValue ) {
			HTTPLogError(@"MultipartFormDataParser: Failed to exctract paramValue for key %@ in header %@",currentParam,name);
		}
#ifdef DEBUG
		if( [params objectForKey:currentParam] ) {
			HTTPLogWarn(@"MultipartFormDataParser: param %@ mentioned more then once in one header",currentParam);
		}
#endif
		[params setObject:paramValue forKey:currentParam];
		HTTPLogVerbose(@"MultipartFormDataParser: header param: %@ = %@",currentParam,paramValue);
		currentParam = nil;
	}
	return YES;
}
- (NSString *)description {
	return [NSString stringWithFormat:@"%@:%@\n params: %@",name,value,params];
}
@end
int findChar(const char* str, NSUInteger length, char c) {
	int offset = 0;
	while( offset < length ) {
		if( str[offset] == c )
			return offset;
		++ offset;
	}
	return -1;
}
NSString* extractParamValue(const char* bytes, NSUInteger length, NSStringEncoding encoding) {
	if( !length ) 
		return nil;
	NSMutableString* value = nil;
	if( bytes[0] == '"' ) {
		value = [[NSMutableString alloc] initWithBytes:bytes + 1 length: length - 2 encoding:encoding]; 
	}
	else {
		value = [[NSMutableString alloc] initWithBytes:bytes length: length encoding:encoding];
	}
	NSRange range= [value rangeOfString:@"\\"];
	while ( range.length ) {
		[value deleteCharactersInRange:range];
		range.location ++;
		range = [value rangeOfString:@"\\" options:NSLiteralSearch range: range];
	}
	return value;
}
