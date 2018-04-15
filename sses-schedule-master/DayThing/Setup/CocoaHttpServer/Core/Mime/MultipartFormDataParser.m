#import "MultipartFormDataParser.h"
#import "DDData.h"
#import "HTTPLogging.h"
#pragma mark log level
#ifdef DEBUG
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#else
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#endif
#ifdef __x86_64__
#define FMTNSINT "li"
#else
#define FMTNSINT "i"
#endif
@interface MultipartFormDataParser (private)
+ (NSData*) decodedDataFromData:(NSData*) data encoding:(int) encoding;
- (int) findHeaderEnd:(NSData*) workingData fromOffset:(int) offset;
- (int) findContentEnd:(NSData*) data fromOffset:(int) offset;
- (int) numberOfBytesToLeavePendingWithData:(NSData*) data length:(NSUInteger) length encoding:(int) encoding;
- (int) offsetTillNewlineSinceOffset:(int) offset inData:(NSData*) data;
- (int) processPreamble:(NSData*) workingData;
@end
@implementation MultipartFormDataParser 
@synthesize delegate,formEncoding;
- (id) initWithBoundary:(NSString*) boundary formEncoding:(NSStringEncoding) _formEncoding {
    if( nil == (self = [super init]) ){
        return self;
    }
	if( nil == boundary ) {
		HTTPLogWarn(@"MultipartFormDataParser: init with zero boundary");
		return nil;
	}
    boundaryData = [[@"\r\n--" stringByAppendingString:boundary] dataUsingEncoding:NSASCIIStringEncoding];
    pendingData = [[NSMutableData alloc] init];
    currentEncoding = contentTransferEncoding_binary;
	currentHeader = nil;
	formEncoding = _formEncoding;
	reachedEpilogue = NO;
	processedPreamble = NO;
    return self;
}
- (BOOL) appendData:(NSData *)data { 
    if( nil == boundaryData ) {
		HTTPLogError(@"MultipartFormDataParser: Trying to parse multipart without specifying a valid boundary");
		assert(false);
        return NO;
    }
    NSData* workingData = data;
    if( pendingData.length ) {
        [pendingData appendData:data];
        workingData = pendingData;
    }
    int offset = 0;
	NSUInteger sizeToLeavePending = boundaryData.length;
	if( !reachedEpilogue && workingData.length <= sizeToLeavePending )  {
		if( !pendingData.length ) {
			[pendingData appendData:data];
		}
		if( checkForContentEnd ) {
			if(	pendingData.length >= 2 ) {
				if( *(uint16_t*)(pendingData.bytes + offset) == 0x2D2D ) {
					HTTPLogVerbose(@"MultipartFormDataParser: End of multipart message");
					waitingForCRLF = YES;
					reachedEpilogue = YES;
					offset+= 2;
				}
				else {
					checkForContentEnd = NO;
					waitingForCRLF = YES;
					return YES;
				}
			} else {
				return YES;
			}
		}
		else {
			return YES;
		}
	}
	while( true ) {
		if( checkForContentEnd ) {
			if( offset < workingData.length -1 ) {
				char* bytes = (char*) workingData.bytes;
				if( *(uint16_t*)(bytes + offset) == 0x2D2D ) {
					HTTPLogVerbose(@"MultipartFormDataParser: End of multipart message");
					checkForContentEnd = NO;
					reachedEpilogue = YES;
					waitingForCRLF = YES;
					offset += 2;
				}
				else {
					waitingForCRLF = YES;
					checkForContentEnd = NO;
				}
			}
			else {
				if( offset < workingData.length ) {
					[pendingData setData:[NSData dataWithBytes:workingData.bytes + workingData.length-1 length:1]];
				}
				else {
					[pendingData setData:[NSData data]];
				}
				return YES;
			}
		}
		if( waitingForCRLF ) {
			offset = [self offsetTillNewlineSinceOffset:offset inData:workingData];
			if( -1 == offset ) {
				if( offset ) {
					if( *((char*)workingData.bytes + workingData.length -1) == '\r' ) {
						[pendingData setData:[NSData dataWithBytes:workingData.bytes + workingData.length-1 length:1]];
					}
					else {
						[pendingData setData:[NSData data]];
					}
				}
				return YES;
			}
			waitingForCRLF = NO;
		}
		if( !processedPreamble ) {
			offset = [self processPreamble:workingData];
			if( -1 == offset ) 
				return YES;
			continue;
		}
		if( reachedEpilogue ) {
			if( [delegate respondsToSelector:@selector(processEpilogueData:)] ) {
				NSData* epilogueData = [NSData dataWithBytesNoCopy: (char*) workingData.bytes + offset length: workingData.length - offset freeWhenDone:NO];
				[delegate processEpilogueData: epilogueData];
			}
			return YES;
		}
		if( nil == currentHeader ) {
			int headerEnd = [self findHeaderEnd:workingData fromOffset:offset];
			if( -1 == headerEnd ) {
				if( !pendingData.length) {
					[pendingData appendBytes:data.bytes + offset length:data.length - offset];
				}
				else {
					if( offset ) {
						pendingData = [[NSMutableData alloc] initWithBytes: (char*) workingData.bytes + offset length:workingData.length - offset];
					}
				}
				return  YES;
			}
			else {
				NSData * headerData = [NSData dataWithBytesNoCopy: (char*) workingData.bytes + offset length:headerEnd + 2 - offset freeWhenDone:NO];
				currentHeader = [[MultipartMessageHeader alloc] initWithData:headerData formEncoding:formEncoding];
				if( nil == currentHeader ) {
					HTTPLogError(@"MultipartFormDataParser: MultipartFormDataParser: wrong input format, coulnd't get a valid header");
					return NO;
				}
                if( [delegate respondsToSelector:@selector(processStartOfPartWithHeader:)] ) {
                    [delegate processStartOfPartWithHeader:currentHeader];
                }
				HTTPLogVerbose(@"MultipartFormDataParser: MultipartFormDataParser: Retrieved part header.");
			}
			offset = headerEnd + 4;	
		}
		int contentEnd = [self findContentEnd:workingData fromOffset:offset];
		if( contentEnd == -1 ) {
			NSUInteger sizeToPass = workingData.length - offset - sizeToLeavePending;
			int leaveTrailing = [self numberOfBytesToLeavePendingWithData:data length:sizeToPass encoding:currentEncoding];
			sizeToPass -= leaveTrailing;
			if( sizeToPass <= 0 ) {
				if( offset ) {
					[pendingData setData:[NSData dataWithBytes:(char*) workingData.bytes + offset length:workingData.length - offset]];
				}
				return YES;
			}
			NSData* decodedData = [MultipartFormDataParser decodedDataFromData:[NSData dataWithBytesNoCopy:(char*)workingData.bytes + offset length:workingData.length - offset - sizeToLeavePending freeWhenDone:NO] encoding:currentEncoding];
			if( [delegate respondsToSelector:@selector(processContent:WithHeader:)] ) {
				HTTPLogVerbose(@"MultipartFormDataParser: Processed %"FMTNSINT" bytes of body",sizeToPass);
				[delegate processContent: decodedData WithHeader:currentHeader];
			}
			[pendingData setData:[NSData dataWithBytes:(char*)workingData.bytes + workingData.length - sizeToLeavePending length:sizeToLeavePending]];
			return YES;
		}
		else {
			if( [delegate respondsToSelector:@selector(processContent:WithHeader:)] ) {
				[delegate processContent:[NSData dataWithBytesNoCopy:(char*) workingData.bytes + offset length:contentEnd - offset freeWhenDone:NO] WithHeader:currentHeader];
			}
			if( [delegate respondsToSelector:@selector(processEndOfPartWithHeader:)] ){
				[delegate processEndOfPartWithHeader:currentHeader];
				HTTPLogVerbose(@"MultipartFormDataParser: End of body part");
			}
			currentHeader = nil;
			offset = contentEnd + (int)boundaryData.length;
			checkForContentEnd = YES;
		}
	}
    return YES;
}
#pragma mark private methods
- (int) offsetTillNewlineSinceOffset:(int) offset inData:(NSData*) data {
	char* bytes = (char*) data.bytes;
	NSUInteger length = data.length;
	if( offset >= length - 1 ) 
		return -1;
	while ( *(uint16_t*)(bytes + offset) != 0x0A0D ) {
#ifdef DEBUG
		if( !isspace(*(bytes+offset)) ) {
			HTTPLogWarn(@"MultipartFormDataParser: Warning, non-whitespace character '%c' between boundary bytes and CRLF in boundary line",*(bytes+offset) );
		}
		if( !isspace(*(bytes+offset+1)) ) {
			HTTPLogWarn(@"MultipartFormDataParser: Warning, non-whitespace character '%c' between boundary bytes and CRLF in boundary line",*(bytes+offset+1) );
		}
#endif
		offset++;
		if( offset >= length ) {
			return -1;
		}
	}
	offset += 2;
	return offset;
}
- (int) processPreamble:(NSData*) data {
	int offset = 0;
	char* boundaryBytes = (char*) boundaryData.bytes + 2; 
    char* dataBytes = (char*) data.bytes;
    NSUInteger boundaryLength = boundaryData.length - 2;
    NSUInteger dataLength = data.length;
    while( offset < dataLength - boundaryLength +1 ) {
        int i;
        for( i = 0;i < boundaryLength; i++ ) {
            if( boundaryBytes[i] != dataBytes[offset + i] )
                break;
        }
        if( i == boundaryLength ) {
            break;
        }
		offset++;
    }
	if( offset == dataLength ) {
		NSUInteger sizeToProcess = dataLength - boundaryLength;
		if( sizeToProcess > 0) {
			if( [delegate respondsToSelector:@selector(processPreambleData:)] ) {
				NSData* preambleData = [NSData dataWithBytesNoCopy: (char*) data.bytes length: data.length - offset - boundaryLength freeWhenDone:NO];
				[delegate processPreambleData:preambleData];
				HTTPLogVerbose(@"MultipartFormDataParser: processed preamble");
			}
			pendingData = [NSMutableData dataWithBytes: data.bytes + data.length - boundaryLength length:boundaryLength];
		}
		return -1;
	}
	else {
		if ( offset && [delegate respondsToSelector:@selector(processPreambleData:)] ) {
			NSData* preambleData = [NSData dataWithBytesNoCopy: (char*) data.bytes length: offset freeWhenDone:NO];
			[delegate processPreambleData:preambleData];
		}
		offset +=boundaryLength;
		processedPreamble = YES;
		waitingForCRLF = YES;
	}
	return offset;
}
- (int) findHeaderEnd:(NSData*) workingData fromOffset:(int)offset {
    char* bytes = (char*) workingData.bytes; 
    NSUInteger inputLength = workingData.length;
    uint16_t separatorBytes = 0x0A0D;
	while( true ) {
		if(inputLength < offset + 3 ) {
			return -1;
		}
        if( (*((uint16_t*) (bytes+offset)) == separatorBytes) && (*((uint16_t*) (bytes+offset)+1) == separatorBytes) ) {
			return offset;
        }
        offset++;
    }
    return -1;
}
- (int) findContentEnd:(NSData*) data fromOffset:(int) offset {
    char* boundaryBytes = (char*) boundaryData.bytes;
    char* dataBytes = (char*) data.bytes;
    NSUInteger boundaryLength = boundaryData.length;
    NSUInteger dataLength = data.length;
    while( offset < dataLength - boundaryLength +1 ) {
        int i;
        for( i = 0;i < boundaryLength; i++ ) {
            if( boundaryBytes[i] != dataBytes[offset + i] )
                break;
        }
        if( i == boundaryLength ) {
            return offset;
        }
		offset++;
    }
    return -1;
}
- (int) numberOfBytesToLeavePendingWithData:(NSData*) data length:(int) length encoding:(int) encoding {
	int sizeToLeavePending = 0;
	if( encoding == contentTransferEncoding_base64 ) {	
		char* bytes = (char*) data.bytes;
		int i;
		for( i = length - 1; i > 0; i++ ) {
			if( * (uint16_t*) (bytes + i) == 0x0A0D ) {
				break;
			}
		}
		sizeToLeavePending = (length - i) & ~0x11; 
		return sizeToLeavePending;
	}
	if( encoding == contentTransferEncoding_quotedPrintable ) {
		if( length <= 2 ) 
			return length;
		const char* bytes = data.bytes + length - 2;
		if( bytes[0] == '=' )
			return 2;
		if( bytes[1] == '=' )
			return 1;
		return 0;
	}
	return 0;
}
#pragma mark decoding
+ (NSData*) decodedDataFromData:(NSData*) data encoding:(int) encoding {
	switch (encoding) {
		case contentTransferEncoding_base64: {
			return [data base64Decoded]; 
		} break;
		case contentTransferEncoding_quotedPrintable: {
			return [self decodedDataFromQuotedPrintableData:data];
		} break;
		default: {
			return data;
		} break;
	}
}
+ (NSData*) decodedDataFromQuotedPrintableData:(NSData *)data {
	const char hex []  = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', };
	NSMutableData* result = [[NSMutableData alloc] initWithLength:data.length];
	const char* bytes = (const char*) data.bytes;
	int count = 0;
	NSUInteger length = data.length;
	while( count < length ) {
		if( bytes[count] == '=' ) {
			[result appendBytes:bytes length:count];
			bytes = bytes + count + 1;
			length -= count + 1;
			count = 0;
			if( length < 3 ) {
				HTTPLogWarn(@"MultipartFormDataParser: warning, trailing '=' in quoted printable data");
			}
			if( bytes[0] == '\r' ) {
				bytes += 1;
				if(bytes[1] == '\n' ) {
					bytes += 2;
				}
				continue;
			}
			char encodedByte = 0;
			for( int i = 0; i < sizeof(hex); i++ ) {
				if( hex[i] == bytes[0] ) {
					encodedByte += i << 4;
				}
				if( hex[i] == bytes[1] ) {
					encodedByte += i;
				}
			}
			[result appendBytes:&encodedByte length:1];
			bytes += 2;
		}
#ifdef DEBUG
		if( (unsigned char) bytes[count] > 126 ) {
			HTTPLogWarn(@"MultipartFormDataParser: Warning, character with code above 126 appears in quoted printable encoded data");
		}
#endif
		count++;
	}
	return result;
}
@end
