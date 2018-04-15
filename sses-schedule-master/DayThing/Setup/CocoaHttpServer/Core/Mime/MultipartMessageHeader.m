#import "MultipartMessageHeader.h"
#import "MultipartMessageHeaderField.h"
#import "HTTPLogging.h"
#pragma mark log level
#ifdef DEBUG
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#else
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#endif
@implementation MultipartMessageHeader
@synthesize fields,encoding;
- (id) initWithData:(NSData *)data formEncoding:(NSStringEncoding) formEncoding {
	if( nil == (self = [super init]) ) {
        return self;
    }
	fields = [[NSMutableDictionary alloc] initWithCapacity:1];
	encoding = contentTransferEncoding_unknown;
	char* bytes = (char*)data.bytes;
	NSUInteger length = data.length;
	int offset = 0;
	uint16_t fields_separator = 0x0A0D; 
	while( offset < length - 2 ) {
		if( (*(uint16_t*) (bytes+offset)  == fields_separator) && ((offset == length - 2) || !(isspace(bytes[offset+2])) )) {
			NSData* fieldData = [NSData dataWithBytesNoCopy:bytes length:offset freeWhenDone:NO];
			MultipartMessageHeaderField* field = [[MultipartMessageHeaderField alloc] initWithData: fieldData  contentEncoding:formEncoding];
			if( field ) {
				[fields setObject:field forKey:field.name];
				HTTPLogVerbose(@"MultipartFormDataParser: Processed Header field '%@'",field.name);
			}
			else {
				NSString* fieldStr = [[NSString  alloc] initWithData:fieldData encoding:NSASCIIStringEncoding];
				HTTPLogWarn(@"MultipartFormDataParser: Failed to parse MIME header field. Input ASCII string:%@",fieldStr);
			}
			bytes += offset + 2;
			length -= offset + 2;
			offset = 0;
			continue;
		}
		++ offset;
	}
	if( !fields.count ) {
		[fields setObject:@"text/plain" forKey:@"Content-Type"];
	}
	return self;
}
- (NSString *)description {	
	return [NSString stringWithFormat:@"%@",fields];
}
@end
