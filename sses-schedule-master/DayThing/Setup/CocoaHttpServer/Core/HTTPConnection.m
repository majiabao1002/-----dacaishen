#import "GCDAsyncSocket.h"
#import "HTTPServer.h"
#import "HTTPConnection.h"
#import "HTTPMessage.h"
#import "HTTPResponse.h"
#import "HTTPAuthenticationRequest.h"
#import "DDNumber.h"
#import "DDRange.h"
#import "DDData.h"
#import "HTTPFileResponse.h"
#import "HTTPAsyncFileResponse.h"
#import "WebSocket.h"
#import "HTTPLogging.h"
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; 
#if TARGET_OS_IPHONE
  #define READ_CHUNKSIZE  (1024 * 256)
#else
  #define READ_CHUNKSIZE  (1024 * 512)
#endif
#if TARGET_OS_IPHONE
  #define POST_CHUNKSIZE  (1024 * 256)
#else
  #define POST_CHUNKSIZE  (1024 * 512)
#endif
#define TIMEOUT_READ_FIRST_HEADER_LINE       30
#define TIMEOUT_READ_SUBSEQUENT_HEADER_LINE  30
#define TIMEOUT_READ_BODY                    -1
#define TIMEOUT_WRITE_HEAD                   30
#define TIMEOUT_WRITE_BODY                   -1
#define TIMEOUT_WRITE_ERROR                  30
#define TIMEOUT_NONCE                       300
#define MAX_HEADER_LINE_LENGTH  8190
#define MAX_HEADER_LINES         100
#define MAX_CHUNK_LINE_LENGTH    200
#define HTTP_REQUEST_HEADER                10
#define HTTP_REQUEST_BODY                  11
#define HTTP_REQUEST_CHUNK_SIZE            12
#define HTTP_REQUEST_CHUNK_DATA            13
#define HTTP_REQUEST_CHUNK_TRAILER         14
#define HTTP_REQUEST_CHUNK_FOOTER          15
#define HTTP_PARTIAL_RESPONSE              20
#define HTTP_PARTIAL_RESPONSE_HEADER       21
#define HTTP_PARTIAL_RESPONSE_BODY         22
#define HTTP_CHUNKED_RESPONSE_HEADER       30
#define HTTP_CHUNKED_RESPONSE_BODY         31
#define HTTP_CHUNKED_RESPONSE_FOOTER       32
#define HTTP_PARTIAL_RANGE_RESPONSE_BODY   40
#define HTTP_PARTIAL_RANGES_RESPONSE_BODY  50
#define HTTP_RESPONSE                      90
#define HTTP_FINAL_RESPONSE                91
@interface HTTPConnection (PrivateAPI)
- (void)startReadingRequest;
- (void)sendResponseHeadersAndBody;
@end
#pragma mark -
@implementation HTTPConnection
static dispatch_queue_t recentNonceQueue;
static NSMutableArray *recentNonces;
+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		recentNonceQueue = dispatch_queue_create("HTTPConnection-Nonce", NULL);
		recentNonces = [[NSMutableArray alloc] initWithCapacity:5];
	});
}
+ (NSString *)generateNonce
{
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	NSString *newNonce = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	dispatch_async(recentNonceQueue, ^{ @autoreleasepool {
		[recentNonces addObject:newNonce];
	}});
	double delayInSeconds = TIMEOUT_NONCE;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, recentNonceQueue, ^{ @autoreleasepool {
		[recentNonces removeObject:newNonce];
	}});
	return newNonce;
}
+ (BOOL)hasRecentNonce:(NSString *)recentNonce
{
	__block BOOL result = NO;
	dispatch_sync(recentNonceQueue, ^{ @autoreleasepool {
		result = [recentNonces containsObject:recentNonce];
	}});
	return result;
}
#pragma mark Init, Dealloc:
- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		if (aConfig.queue)
		{
			connectionQueue = aConfig.queue;
			#if !OS_OBJECT_USE_OBJC
			dispatch_retain(connectionQueue);
			#endif
		}
		else
		{
			connectionQueue = dispatch_queue_create("HTTPConnection", NULL);
		}
		asyncSocket = newSocket;
		[asyncSocket setDelegate:self delegateQueue:connectionQueue];
		config = aConfig;
		lastNC = 0;
		request = [[HTTPMessage alloc] initEmptyRequest];
		numHeaderLines = 0;
		responseDataSizes = [[NSMutableArray alloc] initWithCapacity:5];
	}
	return self;
}
- (void)dealloc
{
	HTTPLogTrace();
	#if !OS_OBJECT_USE_OBJC
	dispatch_release(connectionQueue);
	#endif
	[asyncSocket setDelegate:nil delegateQueue:NULL];
	[asyncSocket disconnect];
	if ([httpResponse respondsToSelector:@selector(connectionDidClose)])
	{
		[httpResponse connectionDidClose];
	}
}
#pragma mark Method Support
- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	if ([method isEqualToString:@"GET"])
		return YES;
	if ([method isEqualToString:@"HEAD"])
		return YES;
	return NO;
}
- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	if ([method isEqualToString:@"POST"])
		return YES;
	if ([method isEqualToString:@"PUT"])
		return YES;
	return NO;
}
#pragma mark HTTPS
- (BOOL)isSecureServer
{
	HTTPLogTrace();
	return NO;
}
- (NSArray *)sslIdentityAndCertificates
{
	HTTPLogTrace();
	return nil;
}
#pragma mark Password Protection
- (BOOL)isPasswordProtected:(NSString *)path
{
	HTTPLogTrace();
	return NO;
}
- (BOOL)useDigestAccessAuthentication
{
	HTTPLogTrace();
	return YES;
}
- (NSString *)realm
{
	HTTPLogTrace();
	return @"defaultRealm@host.com";
}
- (NSString *)passwordForUser:(NSString *)username
{
	HTTPLogTrace();
	return nil;
}
- (BOOL)isAuthenticated
{
	HTTPLogTrace();
	HTTPAuthenticationRequest *auth = [[HTTPAuthenticationRequest alloc] initWithRequest:request];
	if ([self useDigestAccessAuthentication])
	{
		if(![auth isDigest])
		{
			return NO;
		}
		if ([auth username] == nil)
		{
			return NO;
		}
		NSString *password = [self passwordForUser:[auth username]];
		if (password == nil)
		{
			return NO;
		}
		NSString *url = [[request url] relativeString];
		if (![url isEqualToString:[auth uri]])
		{
			return NO;
		}
		if (![nonce isEqualToString:[auth nonce]])
		{
			if ([[self class] hasRecentNonce:[auth nonce]])
			{
				nonce = [[auth nonce] copy];
				lastNC = 0;
			}
			else
			{
				return NO;
			}
		}
		long authNC = strtol([[auth nc] UTF8String], NULL, 16);
		if (authNC <= lastNC)
		{
			return NO;
		}
		lastNC = authNC;
		NSString *HA1str = [NSString stringWithFormat:@"%@:%@:%@", [auth username], [auth realm], password];
		NSString *HA2str = [NSString stringWithFormat:@"%@:%@", [request method], [auth uri]];
		NSString *HA1 = [[[HA1str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
		NSString *HA2 = [[[HA2str dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
		NSString *responseStr = [NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@",
								 HA1, [auth nonce], [auth nc], [auth cnonce], [auth qop], HA2];
		NSString *response = [[[responseStr dataUsingEncoding:NSUTF8StringEncoding] md5Digest] hexStringValue];
		return [response isEqualToString:[auth response]];
	}
	else
	{
		if (![auth isBasic])
		{
			return NO;
		}
		NSString *base64Credentials = [auth base64Credentials];
		NSData *temp = [[base64Credentials dataUsingEncoding:NSUTF8StringEncoding] base64Decoded];
		NSString *credentials = [[NSString alloc] initWithData:temp encoding:NSUTF8StringEncoding];
		NSRange colonRange = [credentials rangeOfString:@":"];
		if (colonRange.length == 0)
		{
			return NO;
		}
		NSString *credUsername = [credentials substringToIndex:colonRange.location];
		NSString *credPassword = [credentials substringFromIndex:(colonRange.location + colonRange.length)];
		NSString *password = [self passwordForUser:credUsername];
		if (password == nil)
		{
			return NO;
		}
		return [password isEqualToString:credPassword];
	}
}
- (void)addDigestAuthChallenge:(HTTPMessage *)response
{
	HTTPLogTrace();
	NSString *authFormat = @"Digest realm=\"%@\", qop=\"auth\", nonce=\"%@\"";
	NSString *authInfo = [NSString stringWithFormat:authFormat, [self realm], [[self class] generateNonce]];
	[response setHeaderField:@"WWW-Authenticate" value:authInfo];
}
- (void)addBasicAuthChallenge:(HTTPMessage *)response
{
	HTTPLogTrace();
	NSString *authFormat = @"Basic realm=\"%@\"";
	NSString *authInfo = [NSString stringWithFormat:authFormat, [self realm]];
	[response setHeaderField:@"WWW-Authenticate" value:authInfo];
}
#pragma mark Core
- (void)start
{
	dispatch_async(connectionQueue, ^{ @autoreleasepool {
		if (!started)
		{
			started = YES;
			[self startConnection];
		}
	}});
}
- (void)stop
{
	dispatch_async(connectionQueue, ^{ @autoreleasepool {
		[asyncSocket disconnect];
	}});
}
- (void)startConnection
{
	HTTPLogTrace();
	if ([self isSecureServer])
	{
		NSArray *certificates = [self sslIdentityAndCertificates];
		if ([certificates count] > 0)
		{
			NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
			[settings setObject:[NSNumber numberWithBool:YES]
						 forKey:(NSString *)kCFStreamSSLIsServer];
			[settings setObject:certificates
						 forKey:(NSString *)kCFStreamSSLCertificates];
			[settings setObject:(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL
						 forKey:(NSString *)kCFStreamSSLLevel];
			[asyncSocket startTLS:settings];
		}
	}
	[self startReadingRequest];
}
- (void)startReadingRequest
{
	HTTPLogTrace();
	[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
	                withTimeout:TIMEOUT_READ_FIRST_HEADER_LINE
	                  maxLength:MAX_HEADER_LINE_LENGTH
	                        tag:HTTP_REQUEST_HEADER];
}
- (NSDictionary *)parseParams:(NSString *)query
{
	NSArray *components = [query componentsSeparatedByString:@"&"];
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[components count]];
	NSUInteger i;
	for (i = 0; i < [components count]; i++)
	{ 
		NSString *component = [components objectAtIndex:i];
		if ([component length] > 0)
		{
			NSRange range = [component rangeOfString:@"="];
			if (range.location != NSNotFound)
			{ 
				NSString *escapedKey = [component substringToIndex:(range.location + 0)]; 
				NSString *escapedValue = [component substringFromIndex:(range.location + 1)];
				if ([escapedKey length] > 0)
				{
					CFStringRef k, v;
					k = CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)escapedKey, CFSTR(""));
					v = CFURLCreateStringByReplacingPercentEscapes(NULL, (__bridge CFStringRef)escapedValue, CFSTR(""));
					NSString *key, *value;
					key   = (__bridge_transfer NSString *)k;
					value = (__bridge_transfer NSString *)v;
					if (key)
					{
						if (value)
							[result setObject:value forKey:key]; 
						else 
							[result setObject:[NSNull null] forKey:key]; 
					}
				}
			}
		}
	}
	return result;
}
- (NSDictionary *)parseGetParams 
{
	if(![request isHeaderComplete]) return nil;
	NSDictionary *result = nil;
	NSURL *url = [request url];
	if(url)
	{
		NSString *query = [url query];
		if (query)
		{
			result = [self parseParams:query];
		}
	}
	return result; 
}
- (BOOL)parseRangeRequest:(NSString *)rangeHeader withContentLength:(UInt64)contentLength
{
	HTTPLogTrace();
	NSRange eqsignRange = [rangeHeader rangeOfString:@"="];
	if(eqsignRange.location == NSNotFound) return NO;
	NSUInteger tIndex = eqsignRange.location;
	NSUInteger fIndex = eqsignRange.location + eqsignRange.length;
	NSMutableString *rangeType  = [[rangeHeader substringToIndex:tIndex] mutableCopy];
	NSMutableString *rangeValue = [[rangeHeader substringFromIndex:fIndex] mutableCopy];
	CFStringTrimWhitespace((__bridge CFMutableStringRef)rangeType);
	CFStringTrimWhitespace((__bridge CFMutableStringRef)rangeValue);
	if([rangeType caseInsensitiveCompare:@"bytes"] != NSOrderedSame) return NO;
	NSArray *rangeComponents = [rangeValue componentsSeparatedByString:@","];
	if([rangeComponents count] == 0) return NO;
	ranges = [[NSMutableArray alloc] initWithCapacity:[rangeComponents count]];
	rangeIndex = 0;
	NSUInteger i;
	for (i = 0; i < [rangeComponents count]; i++)
	{
		NSString *rangeComponent = [rangeComponents objectAtIndex:i];
		NSRange dashRange = [rangeComponent rangeOfString:@"-"];
		if (dashRange.location == NSNotFound)
		{
			UInt64 byteIndex;
			if(![NSNumber parseString:rangeComponent intoUInt64:&byteIndex]) return NO;
			if(byteIndex >= contentLength) return NO;
			[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(byteIndex, 1)]];
		}
		else
		{
			tIndex = dashRange.location;
			fIndex = dashRange.location + dashRange.length;
			NSString *r1str = [rangeComponent substringToIndex:tIndex];
			NSString *r2str = [rangeComponent substringFromIndex:fIndex];
			UInt64 r1, r2;
			BOOL hasR1 = [NSNumber parseString:r1str intoUInt64:&r1];
			BOOL hasR2 = [NSNumber parseString:r2str intoUInt64:&r2];
			if (!hasR1)
			{
				if(!hasR2) return NO;
				if(r2 > contentLength) return NO;
				UInt64 startIndex = contentLength - r2;
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(startIndex, r2)]];
			}
			else if (!hasR2)
			{
				if(r1 >= contentLength) return NO;
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(r1, contentLength - r1)]];
			}
			else
			{
				if(r1 > r2) return NO;
				if(r2 >= contentLength) return NO;
				[ranges addObject:[NSValue valueWithDDRange:DDMakeRange(r1, r2 - r1 + 1)]];
			}
		}
	}
	if([ranges count] == 0) return NO;
	for (i = 0; i < [ranges count] - 1; i++)
	{
		DDRange range1 = [[ranges objectAtIndex:i] ddrangeValue];
		NSUInteger j;
		for (j = i+1; j < [ranges count]; j++)
		{
			DDRange range2 = [[ranges objectAtIndex:j] ddrangeValue];
			DDRange iRange = DDIntersectionRange(range1, range2);
			if(iRange.length != 0)
			{
				return NO;
			}
		}
	}
	[ranges sortUsingSelector:@selector(ddrangeCompare:)];
	return YES;
}
- (NSString *)requestURI
{
	if(request == nil) return nil;
	return [[request url] relativeString];
}
- (void)replyToHTTPRequest
{
	HTTPLogTrace();
	if (HTTP_LOG_VERBOSE)
	{
		NSData *tempData = [request messageData];
		NSString *tempStr = [[NSString alloc] initWithData:tempData encoding:NSUTF8StringEncoding];
		HTTPLogVerbose(@"%@[%p]: Received HTTP request:\n%@", THIS_FILE, self, tempStr);
	}
	NSString *version = [request version];
	if (![version isEqualToString:HTTPVersion1_1] && ![version isEqualToString:HTTPVersion1_0])
	{
		[self handleVersionNotSupported:version];
		return;
	}
	NSString *uri = [self requestURI];
	if ([WebSocket isWebSocketRequest:request])
	{
		HTTPLogVerbose(@"isWebSocket");
		WebSocket *ws = [self webSocketForURI:uri];
		if (ws == nil)
		{
			[self handleResourceNotFound];
		}
		else
		{
			[ws start];
			[[config server] addWebSocket:ws];
			if ([asyncSocket delegate] == self)
			{
				HTTPLogWarn(@"%@[%p]: WebSocket forgot to set itself as socket delegate", THIS_FILE, self);
				[asyncSocket disconnect];
			}
			else
			{
				asyncSocket = nil;
				[self die];
			}
		}
		return;
	}
	if ([self isPasswordProtected:uri] && ![self isAuthenticated])
	{
		[self handleAuthenticationFailed];
		return;
	}
	NSString *method = [request method];
	httpResponse = [self httpResponseForMethod:method URI:uri];
	if (httpResponse == nil)
	{
		[self handleResourceNotFound];
		return;
	}
	[self sendResponseHeadersAndBody];
}
- (HTTPMessage *)newUniRangeResponse:(UInt64)contentLength
{
	HTTPLogTrace();
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:206 description:nil version:HTTPVersion1_1];
	DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
	NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", range.length];
	[response setHeaderField:@"Content-Length" value:contentLengthStr];
	NSString *rangeStr = [NSString stringWithFormat:@"%qu-%qu", range.location, DDMaxRange(range) - 1];
	NSString *contentRangeStr = [NSString stringWithFormat:@"bytes %@/%qu", rangeStr, contentLength];
	[response setHeaderField:@"Content-Range" value:contentRangeStr];
	return response;
}
- (HTTPMessage *)newMultiRangeResponse:(UInt64)contentLength
{
	HTTPLogTrace();
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:206 description:nil version:HTTPVersion1_1];
	ranges_headers = [[NSMutableArray alloc] initWithCapacity:[ranges count]];
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	ranges_boundry = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	NSString *startingBoundryStr = [NSString stringWithFormat:@"\r\n--%@\r\n", ranges_boundry];
	NSString *endingBoundryStr = [NSString stringWithFormat:@"\r\n--%@--\r\n", ranges_boundry];
	UInt64 actualContentLength = 0;
	NSUInteger i;
	for (i = 0; i < [ranges count]; i++)
	{
		DDRange range = [[ranges objectAtIndex:i] ddrangeValue];
		NSString *rangeStr = [NSString stringWithFormat:@"%qu-%qu", range.location, DDMaxRange(range) - 1];
		NSString *contentRangeVal = [NSString stringWithFormat:@"bytes %@/%qu", rangeStr, contentLength];
		NSString *contentRangeStr = [NSString stringWithFormat:@"Content-Range: %@\r\n\r\n", contentRangeVal];
		NSString *fullHeader = [startingBoundryStr stringByAppendingString:contentRangeStr];
		NSData *fullHeaderData = [fullHeader dataUsingEncoding:NSUTF8StringEncoding];
		[ranges_headers addObject:fullHeaderData];
		actualContentLength += [fullHeaderData length];
		actualContentLength += range.length;
	}
	NSData *endingBoundryData = [endingBoundryStr dataUsingEncoding:NSUTF8StringEncoding];
	actualContentLength += [endingBoundryData length];
	NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", actualContentLength];
	[response setHeaderField:@"Content-Length" value:contentLengthStr];
	NSString *contentTypeStr = [NSString stringWithFormat:@"multipart/byteranges; boundary=%@", ranges_boundry];
	[response setHeaderField:@"Content-Type" value:contentTypeStr];
	return response;
}
- (NSData *)chunkedTransferSizeLineForLength:(NSUInteger)length
{
	return [[NSString stringWithFormat:@"%lx\r\n", (unsigned long)length] dataUsingEncoding:NSUTF8StringEncoding];
}
- (NSData *)chunkedTransferFooter
{
	return [@"\r\n0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
}
- (void)sendResponseHeadersAndBody
{
	if ([httpResponse respondsToSelector:@selector(delayResponseHeaders)])
	{
		if ([httpResponse delayResponseHeaders])
		{
			return;
		}
	}
	BOOL isChunked = NO;
	if ([httpResponse respondsToSelector:@selector(isChunked)])
	{
		isChunked = [httpResponse isChunked];
	}
	UInt64 contentLength = 0;
	if (!isChunked)
	{
		contentLength = [httpResponse contentLength];
	}
	NSString *rangeHeader = [request headerField:@"Range"];
	BOOL isRangeRequest = NO;
	if (!isChunked && rangeHeader)
	{
		if ([self parseRangeRequest:rangeHeader withContentLength:contentLength])
		{
			isRangeRequest = YES;
		}
	}
	HTTPMessage *response;
	if (!isRangeRequest)
	{
		NSInteger status = 200;
		if ([httpResponse respondsToSelector:@selector(status)])
		{
			status = [httpResponse status];
		}
		response = [[HTTPMessage alloc] initResponseWithStatusCode:status description:nil version:HTTPVersion1_1];
		if (isChunked)
		{
			[response setHeaderField:@"Transfer-Encoding" value:@"chunked"];
		}
		else
		{
			NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", contentLength];
			[response setHeaderField:@"Content-Length" value:contentLengthStr];
		}
	}
	else
	{
		if ([ranges count] == 1)
		{
			response = [self newUniRangeResponse:contentLength];
		}
		else
		{
			response = [self newMultiRangeResponse:contentLength];
		}
	}
	BOOL isZeroLengthResponse = !isChunked && (contentLength == 0);
	if ([[request method] isEqualToString:@"HEAD"] || isZeroLengthResponse)
	{
		NSData *responseData = [self preprocessResponse:response];
		[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
		sentResponseHeaders = YES;
	}
	else
	{
		NSData *responseData = [self preprocessResponse:response];
		[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_PARTIAL_RESPONSE_HEADER];
		sentResponseHeaders = YES;
		if (!isRangeRequest)
		{
			NSData *data = [httpResponse readDataOfLength:READ_CHUNKSIZE];
			if ([data length] > 0)
			{
				[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
				if (isChunked)
				{
					NSData *chunkSize = [self chunkedTransferSizeLineForLength:[data length]];
					[asyncSocket writeData:chunkSize withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_HEADER];
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_CHUNKED_RESPONSE_BODY];
					if ([httpResponse isDone])
					{
						NSData *footer = [self chunkedTransferFooter];
						[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
					}
					else
					{
						NSData *footer = [GCDAsyncSocket CRLFData];
						[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_FOOTER];
					}
				}
				else
				{
					long tag = [httpResponse isDone] ? HTTP_RESPONSE : HTTP_PARTIAL_RESPONSE_BODY;
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
				}
			}
		}
		else
		{
			if ([ranges count] == 1)
			{
				DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
				[httpResponse setOffset:range.location];
				NSUInteger bytesToRead = range.length < READ_CHUNKSIZE ? (NSUInteger)range.length : READ_CHUNKSIZE;
				NSData *data = [httpResponse readDataOfLength:bytesToRead];
				if ([data length] > 0)
				{
					[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
					long tag = [data length] == range.length ? HTTP_RESPONSE : HTTP_PARTIAL_RANGE_RESPONSE_BODY;
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
				}
			}
			else
			{
				NSData *rangeHeaderData = [ranges_headers objectAtIndex:0];
				[asyncSocket writeData:rangeHeaderData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_PARTIAL_RESPONSE_HEADER];
				DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
				[httpResponse setOffset:range.location];
				NSUInteger bytesToRead = range.length < READ_CHUNKSIZE ? (NSUInteger)range.length : READ_CHUNKSIZE;
				NSData *data = [httpResponse readDataOfLength:bytesToRead];
				if ([data length] > 0)
				{
					[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
					[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_PARTIAL_RANGES_RESPONSE_BODY];
				}
			}
		}
	}
}
- (NSUInteger)writeQueueSize
{
	NSUInteger result = 0;
	NSUInteger i;
	for(i = 0; i < [responseDataSizes count]; i++)
	{
		result += [[responseDataSizes objectAtIndex:i] unsignedIntegerValue];
	}
	return result;
}
- (void)continueSendingStandardResponseBody
{
	HTTPLogTrace();
	NSUInteger writeQueueSize = [self writeQueueSize];
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
	NSData *data = [httpResponse readDataOfLength:available];
	if ([data length] > 0)
	{
		[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
		BOOL isChunked = NO;
		if ([httpResponse respondsToSelector:@selector(isChunked)])
		{
			isChunked = [httpResponse isChunked];
		}
		if (isChunked)
		{
			NSData *chunkSize = [self chunkedTransferSizeLineForLength:[data length]];
			[asyncSocket writeData:chunkSize withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_HEADER];
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_CHUNKED_RESPONSE_BODY];
			if([httpResponse isDone])
			{
				NSData *footer = [self chunkedTransferFooter];
				[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
			}
			else
			{
				NSData *footer = [GCDAsyncSocket CRLFData];
				[asyncSocket writeData:footer withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_CHUNKED_RESPONSE_FOOTER];
			}
		}
		else
		{
			long tag = [httpResponse isDone] ? HTTP_RESPONSE : HTTP_PARTIAL_RESPONSE_BODY;
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
		}
	}
}
- (void)continueSendingSingleRangeResponseBody
{
	HTTPLogTrace();
	NSUInteger writeQueueSize = [self writeQueueSize];
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	DDRange range = [[ranges objectAtIndex:0] ddrangeValue];
	UInt64 offset = [httpResponse offset];
	UInt64 bytesRead = offset - range.location;
	UInt64 bytesLeft = range.length - bytesRead;
	if (bytesLeft > 0)
	{
		NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
		NSUInteger bytesToRead = bytesLeft < available ? (NSUInteger)bytesLeft : available;
		NSData *data = [httpResponse readDataOfLength:bytesToRead];
		if ([data length] > 0)
		{
			[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
			long tag = [data length] == bytesLeft ? HTTP_RESPONSE : HTTP_PARTIAL_RANGE_RESPONSE_BODY;
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:tag];
		}
	}
}
- (void)continueSendingMultiRangeResponseBody
{
	HTTPLogTrace();
	NSUInteger writeQueueSize = [self writeQueueSize];
	if(writeQueueSize >= READ_CHUNKSIZE) return;
	DDRange range = [[ranges objectAtIndex:rangeIndex] ddrangeValue];
	UInt64 offset = [httpResponse offset];
	UInt64 bytesRead = offset - range.location;
	UInt64 bytesLeft = range.length - bytesRead;
	if (bytesLeft > 0)
	{
		NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
		NSUInteger bytesToRead = bytesLeft < available ? (NSUInteger)bytesLeft : available;
		NSData *data = [httpResponse readDataOfLength:bytesToRead];
		if ([data length] > 0)
		{
			[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
			[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_PARTIAL_RANGES_RESPONSE_BODY];
		}
	}
	else
	{
		if (++rangeIndex < [ranges count])
		{
			NSData *rangeHeader = [ranges_headers objectAtIndex:rangeIndex];
			[asyncSocket writeData:rangeHeader withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_PARTIAL_RESPONSE_HEADER];
			range = [[ranges objectAtIndex:rangeIndex] ddrangeValue];
			[httpResponse setOffset:range.location];
			NSUInteger available = READ_CHUNKSIZE - writeQueueSize;
			NSUInteger bytesToRead = range.length < available ? (NSUInteger)range.length : available;
			NSData *data = [httpResponse readDataOfLength:bytesToRead];
			if ([data length] > 0)
			{
				[responseDataSizes addObject:[NSNumber numberWithUnsignedInteger:[data length]]];
				[asyncSocket writeData:data withTimeout:TIMEOUT_WRITE_BODY tag:HTTP_PARTIAL_RANGES_RESPONSE_BODY];
			}
		}
		else
		{
			NSString *endingBoundryStr = [NSString stringWithFormat:@"\r\n--%@--\r\n", ranges_boundry];
			NSData *endingBoundryData = [endingBoundryStr dataUsingEncoding:NSUTF8StringEncoding];
			[asyncSocket writeData:endingBoundryData withTimeout:TIMEOUT_WRITE_HEAD tag:HTTP_RESPONSE];
		}
	}
}
#pragma mark Responses
- (NSArray *)directoryIndexFileNames
{
	HTTPLogTrace();
	return [NSArray arrayWithObjects:@"index.html", @"index.htm", nil];
}
- (NSString *)filePathForURI:(NSString *)path
{
	return [self filePathForURI:path allowDirectory:NO];
}
- (NSString *)filePathForURI:(NSString *)path allowDirectory:(BOOL)allowDirectory
{
	HTTPLogTrace();
	NSString *documentRoot = [config documentRoot];
	if (documentRoot == nil)
	{
		HTTPLogWarn(@"%@[%p]: No configured document root", THIS_FILE, self);
		return nil;
	}
	NSURL *docRoot = [NSURL fileURLWithPath:documentRoot isDirectory:YES];
	if (docRoot == nil)
	{
		HTTPLogWarn(@"%@[%p]: Document root is invalid file path", THIS_FILE, self);
		return nil;
	}
	NSString *relativePath = [[NSURL URLWithString:path relativeToURL:docRoot] relativePath];
	NSString *fullPath = [[documentRoot stringByAppendingPathComponent:relativePath] stringByStandardizingPath];
	if ([relativePath isEqualToString:@"/"])
	{
		fullPath = [fullPath stringByAppendingString:@"/"];
	}
	if (![documentRoot hasSuffix:@"/"])
	{
		documentRoot = [documentRoot stringByAppendingString:@"/"];
	}
	if (![fullPath hasPrefix:documentRoot])
	{
		HTTPLogWarn(@"%@[%p]: Request for file outside document root", THIS_FILE, self);
		return nil;
	}
	if (!allowDirectory)
	{
		BOOL isDir = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir)
		{
			NSArray *indexFileNames = [self directoryIndexFileNames];
			for (NSString *indexFileName in indexFileNames)
			{
				NSString *indexFilePath = [fullPath stringByAppendingPathComponent:indexFileName];
				if ([[NSFileManager defaultManager] fileExistsAtPath:indexFilePath isDirectory:&isDir] && !isDir)
				{
					return indexFilePath;
				}
			}
			return nil;
		}
	}
	return fullPath;
}
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	HTTPLogTrace();
	NSString *filePath = [self filePathForURI:path allowDirectory:NO];
	BOOL isDir = NO;
	if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
	{
		return [[HTTPFileResponse alloc] initWithFilePath:filePath forConnection:self];
	}
	return nil;
}
- (WebSocket *)webSocketForURI:(NSString *)path
{
	HTTPLogTrace();
	return nil;
}
#pragma mark Uploads
- (void)prepareForBodyWithSize:(UInt64)contentLength
{
}
- (void)processBodyData:(NSData *)postDataChunk
{
}
- (void)finishBody
{
}
#pragma mark Errors
- (void)handleVersionNotSupported:(NSString *)version
{
	HTTPLogWarn(@"HTTP Server: Error 505 - Version Not Supported: %@ (%@)", version, [self requestURI]);
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:505 description:nil version:HTTPVersion1_1];
	[response setHeaderField:@"Content-Length" value:@"0"];
	NSData *responseData = [self preprocessErrorResponse:response];
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_RESPONSE];
}
- (void)handleAuthenticationFailed
{
	HTTPLogInfo(@"HTTP Server: Error 401 - Unauthorized (%@)", [self requestURI]);
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:401 description:nil version:HTTPVersion1_1];
	[response setHeaderField:@"Content-Length" value:@"0"];
	if ([self useDigestAccessAuthentication])
	{
		[self addDigestAuthChallenge:response];
	}
	else
	{
		[self addBasicAuthChallenge:response];
	}
	NSData *responseData = [self preprocessErrorResponse:response];
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_RESPONSE];
}
- (void)handleInvalidRequest:(NSData *)data
{
	HTTPLogWarn(@"HTTP Server: Error 400 - Bad Request (%@)", [self requestURI]);
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:400 description:nil version:HTTPVersion1_1];
	[response setHeaderField:@"Content-Length" value:@"0"];
	[response setHeaderField:@"Connection" value:@"close"];
	NSData *responseData = [self preprocessErrorResponse:response];
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_FINAL_RESPONSE];
}
- (void)handleUnknownMethod:(NSString *)method
{
	HTTPLogWarn(@"HTTP Server: Error 405 - Method Not Allowed: %@ (%@)", method, [self requestURI]);
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:405 description:nil version:HTTPVersion1_1];
	[response setHeaderField:@"Content-Length" value:@"0"];
	[response setHeaderField:@"Connection" value:@"close"];
	NSData *responseData = [self preprocessErrorResponse:response];
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_FINAL_RESPONSE];
}
- (void)handleResourceNotFound
{
	HTTPLogInfo(@"HTTP Server: Error 404 - Not Found (%@)", [self requestURI]);
	HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:404 description:nil version:HTTPVersion1_1];
	[response setHeaderField:@"Content-Length" value:@"0"];
	NSData *responseData = [self preprocessErrorResponse:response];
	[asyncSocket writeData:responseData withTimeout:TIMEOUT_WRITE_ERROR tag:HTTP_RESPONSE];
}
#pragma mark Headers
- (NSString *)dateAsString:(NSDate *)date
{
	static NSDateFormatter *df;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		df = [[NSDateFormatter alloc] init];
		[df setFormatterBehavior:NSDateFormatterBehavior10_4];
		[df setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
		[df setDateFormat:@"EEE, dd MMM y HH:mm:ss 'GMT'"];
		[df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
	});
	return [df stringFromDate:date];
}
- (NSData *)preprocessResponse:(HTTPMessage *)response
{
	HTTPLogTrace();
	NSString *now = [self dateAsString:[NSDate date]];
	[response setHeaderField:@"Date" value:now];
	[response setHeaderField:@"Accept-Ranges" value:@"bytes"];
	if ([httpResponse respondsToSelector:@selector(httpHeaders)])
	{
		NSDictionary *responseHeaders = [httpResponse httpHeaders];
		NSEnumerator *keyEnumerator = [responseHeaders keyEnumerator];
		NSString *key;
		while ((key = [keyEnumerator nextObject]))
		{
			NSString *value = [responseHeaders objectForKey:key];
			[response setHeaderField:key value:value];
		}
	}
	return [response messageData];
}
- (NSData *)preprocessErrorResponse:(HTTPMessage *)response
{
	HTTPLogTrace();
	NSString *now = [self dateAsString:[NSDate date]];
	[response setHeaderField:@"Date" value:now];
	[response setHeaderField:@"Accept-Ranges" value:@"bytes"];
	if ([httpResponse respondsToSelector:@selector(httpHeaders)])
	{
		NSDictionary *responseHeaders = [httpResponse httpHeaders];
		NSEnumerator *keyEnumerator = [responseHeaders keyEnumerator];
		NSString *key;
		while((key = [keyEnumerator nextObject]))
		{
			NSString *value = [responseHeaders objectForKey:key];
			[response setHeaderField:key value:value];
		}
	}
	return [response messageData];
}
#pragma mark GCDAsyncSocket Delegate
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
	if (tag == HTTP_REQUEST_HEADER)
	{
		BOOL result = [request appendData:data];
		if (!result)
		{
			HTTPLogWarn(@"%@[%p]: Malformed request", THIS_FILE, self);
			[self handleInvalidRequest:data];
		}
		else if (![request isHeaderComplete])
		{
			if (++numHeaderLines > MAX_HEADER_LINES)
			{
				[asyncSocket disconnect];
				return;
			}
			else
			{
				[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
				                withTimeout:TIMEOUT_READ_SUBSEQUENT_HEADER_LINE
				                  maxLength:MAX_HEADER_LINE_LENGTH
				                        tag:HTTP_REQUEST_HEADER];
			}
		}
		else
		{
			NSString *method = [request method];
			NSString *uri = [self requestURI];
			NSString *transferEncoding = [request headerField:@"Transfer-Encoding"];
			NSString *contentLength = [request headerField:@"Content-Length"];
			BOOL expectsUpload = [self expectsRequestBodyFromMethod:method atPath:uri];
			if (expectsUpload)
			{
				if (transferEncoding && ![transferEncoding caseInsensitiveCompare:@"Chunked"])
				{
					requestContentLength = -1;
				}
				else
				{
					if (contentLength == nil)
					{
						HTTPLogWarn(@"%@[%p]: Method expects request body, but had no specified Content-Length",
									THIS_FILE, self);
						[self handleInvalidRequest:nil];
						return;
					}
					if (![NSNumber parseString:(NSString *)contentLength intoUInt64:&requestContentLength])
					{
						HTTPLogWarn(@"%@[%p]: Unable to parse Content-Length header into a valid number",
									THIS_FILE, self);
						[self handleInvalidRequest:nil];
						return;
					}
				}
			}
			else
			{
				if (contentLength != nil)
				{
					if (![NSNumber parseString:(NSString *)contentLength intoUInt64:&requestContentLength])
					{
						HTTPLogWarn(@"%@[%p]: Unable to parse Content-Length header into a valid number",
									THIS_FILE, self);
						[self handleInvalidRequest:nil];
						return;
					}
					if (requestContentLength > 0)
					{
						HTTPLogWarn(@"%@[%p]: Method not expecting request body had non-zero Content-Length",
									THIS_FILE, self);
						[self handleInvalidRequest:nil];
						return;
					}
				}
				requestContentLength = 0;
				requestContentLengthReceived = 0;
			}
			if (![self supportsMethod:method atPath:uri])
			{
				[self handleUnknownMethod:method];
				return;
			}
			if (expectsUpload)
			{
				requestContentLengthReceived = 0;
				[self prepareForBodyWithSize:requestContentLength];
				if (requestContentLength > 0)
				{
					if (requestContentLength == -1)
					{
						[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
						                withTimeout:TIMEOUT_READ_BODY
						                  maxLength:MAX_CHUNK_LINE_LENGTH
						                        tag:HTTP_REQUEST_CHUNK_SIZE];
					}
					else
					{
						NSUInteger bytesToRead;
						if (requestContentLength < POST_CHUNKSIZE)
							bytesToRead = (NSUInteger)requestContentLength;
						else
							bytesToRead = POST_CHUNKSIZE;
						[asyncSocket readDataToLength:bytesToRead
						                  withTimeout:TIMEOUT_READ_BODY
						                          tag:HTTP_REQUEST_BODY];
					}
				}
				else
				{
					[self finishBody];
					[self replyToHTTPRequest];
				}
			}
			else
			{
				[self replyToHTTPRequest];
			}
		}
	}
	else
	{
		BOOL doneReadingRequest = NO;
		if (tag == HTTP_REQUEST_CHUNK_SIZE)
		{
			NSString *sizeLine = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			errno = 0;  
			requestChunkSize = (UInt64)strtoull([sizeLine UTF8String], NULL, 16);
			requestChunkSizeReceived = 0;
			if (errno != 0)
			{
				HTTPLogWarn(@"%@[%p]: Method expects chunk size, but received something else", THIS_FILE, self);
				[self handleInvalidRequest:nil];
				return;
			}
			if (requestChunkSize > 0)
			{
				NSUInteger bytesToRead;
				bytesToRead = (requestChunkSize < POST_CHUNKSIZE) ? (NSUInteger)requestChunkSize : POST_CHUNKSIZE;
				[asyncSocket readDataToLength:bytesToRead
				                  withTimeout:TIMEOUT_READ_BODY
				                          tag:HTTP_REQUEST_CHUNK_DATA];
			}
			else
			{
				[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
				                withTimeout:TIMEOUT_READ_BODY
				                  maxLength:MAX_HEADER_LINE_LENGTH
				                        tag:HTTP_REQUEST_CHUNK_FOOTER];
			}
			return;
		}
		else if (tag == HTTP_REQUEST_CHUNK_DATA)
		{
			requestContentLengthReceived += [data length];
			requestChunkSizeReceived += [data length];
			[self processBodyData:data];
			UInt64 bytesLeft = requestChunkSize - requestChunkSizeReceived;
			if (bytesLeft > 0)
			{
				NSUInteger bytesToRead = (bytesLeft < POST_CHUNKSIZE) ? (NSUInteger)bytesLeft : POST_CHUNKSIZE;
				[asyncSocket readDataToLength:bytesToRead
				                  withTimeout:TIMEOUT_READ_BODY
				                          tag:HTTP_REQUEST_CHUNK_DATA];
			}
			else
			{
				[asyncSocket readDataToLength:2
				                  withTimeout:TIMEOUT_READ_BODY
				                          tag:HTTP_REQUEST_CHUNK_TRAILER];
			}
			return;
		}
		else if (tag == HTTP_REQUEST_CHUNK_TRAILER)
		{
			if (![data isEqualToData:[GCDAsyncSocket CRLFData]])
			{
				HTTPLogWarn(@"%@[%p]: Method expects chunk trailer, but is missing", THIS_FILE, self);
				[self handleInvalidRequest:nil];
				return;
			}
			[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
			                withTimeout:TIMEOUT_READ_BODY
			                  maxLength:MAX_CHUNK_LINE_LENGTH
			                        tag:HTTP_REQUEST_CHUNK_SIZE];
		}
		else if (tag == HTTP_REQUEST_CHUNK_FOOTER)
		{
			if (++numHeaderLines > MAX_HEADER_LINES)
			{
				[asyncSocket disconnect];
				return;
			}
			if ([data length] > 2)
			{
				[asyncSocket readDataToData:[GCDAsyncSocket CRLFData]
				                withTimeout:TIMEOUT_READ_BODY
				                  maxLength:MAX_HEADER_LINE_LENGTH
				                        tag:HTTP_REQUEST_CHUNK_FOOTER];
			}
			else
			{
				doneReadingRequest = YES;
			}
		}
		else  
		{
			requestContentLengthReceived += [data length];
			[self processBodyData:data];
			if (requestContentLengthReceived < requestContentLength)
			{
				UInt64 bytesLeft = requestContentLength - requestContentLengthReceived;
				NSUInteger bytesToRead = bytesLeft < POST_CHUNKSIZE ? (NSUInteger)bytesLeft : POST_CHUNKSIZE;
				[asyncSocket readDataToLength:bytesToRead
				                  withTimeout:TIMEOUT_READ_BODY
				                          tag:HTTP_REQUEST_BODY];
			}
			else
			{
				doneReadingRequest = YES;
			}
		}
		if (doneReadingRequest)
		{
			[self finishBody];
			[self replyToHTTPRequest];
		}
	}
}
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	BOOL doneSendingResponse = NO;
	if (tag == HTTP_PARTIAL_RESPONSE_BODY)
	{
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
		[self continueSendingStandardResponseBody];
	}
	else if (tag == HTTP_CHUNKED_RESPONSE_BODY)
	{
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
	}
	else if (tag == HTTP_CHUNKED_RESPONSE_FOOTER)
	{
		[self continueSendingStandardResponseBody];
	}
	else if (tag == HTTP_PARTIAL_RANGE_RESPONSE_BODY)
	{
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
		[self continueSendingSingleRangeResponseBody];
	}
	else if (tag == HTTP_PARTIAL_RANGES_RESPONSE_BODY)
	{
        if ([responseDataSizes count] > 0) {
            [responseDataSizes removeObjectAtIndex:0];
        }
		[self continueSendingMultiRangeResponseBody];
	}
	else if (tag == HTTP_RESPONSE || tag == HTTP_FINAL_RESPONSE)
	{
		if ([responseDataSizes count] > 0)
		{
			[responseDataSizes removeObjectAtIndex:0];
		}
		doneSendingResponse = YES;
	}
	if (doneSendingResponse)
	{
		if ([httpResponse respondsToSelector:@selector(connectionDidClose)])
		{
			[httpResponse connectionDidClose];
		}
		if (tag == HTTP_FINAL_RESPONSE)
		{
			[self finishResponse];
			[asyncSocket disconnect];
			return;
		}
		else
		{
			if ([self shouldDie])
			{
				[self finishResponse];
				[asyncSocket disconnect];
			}
			else
			{
				[self finishResponse];
				NSAssert(request == nil, @"Request not properly released in finishBody");
				request = [[HTTPMessage alloc] initEmptyRequest];
				numHeaderLines = 0;
				sentResponseHeaders = NO;
				[self startReadingRequest];
			}
		}
	}
}
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	HTTPLogTrace();
	asyncSocket = nil;
	[self die];
}
#pragma mark HTTPResponse Notifications
- (void)responseHasAvailableData:(NSObject<HTTPResponse> *)sender
{
	HTTPLogTrace();
	dispatch_async(connectionQueue, ^{ @autoreleasepool {
		if (sender != httpResponse)
		{
			HTTPLogWarn(@"%@[%p]: %@ - Sender is not current httpResponse", THIS_FILE, self, THIS_METHOD);
			return;
		}
		if (!sentResponseHeaders)
		{
			[self sendResponseHeadersAndBody];
		}
		else
		{
			if (ranges == nil)
			{
				[self continueSendingStandardResponseBody];
			}
			else
			{
				if ([ranges count] == 1)
					[self continueSendingSingleRangeResponseBody];
				else
					[self continueSendingMultiRangeResponseBody];
			}
		}
	}});
}
- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender
{
	HTTPLogTrace();
	dispatch_async(connectionQueue, ^{ @autoreleasepool {
		if (sender != httpResponse)
		{
			HTTPLogWarn(@"%@[%p]: %@ - Sender is not current httpResponse", THIS_FILE, self, THIS_METHOD);
			return;
		}
		[asyncSocket disconnectAfterWriting];
	}});
}
#pragma mark Post Request
- (void)finishResponse
{
	HTTPLogTrace();
	request = nil;
	httpResponse = nil;
	ranges = nil;
	ranges_headers = nil;
	ranges_boundry = nil;
}
- (BOOL)shouldDie
{
	HTTPLogTrace();
	BOOL shouldDie = NO;
	NSString *version = [request version];
	if ([version isEqualToString:HTTPVersion1_1])
	{
		NSString *connection = [request headerField:@"Connection"];
		shouldDie = (connection && ([connection caseInsensitiveCompare:@"close"] == NSOrderedSame));
	}
	else if ([version isEqualToString:HTTPVersion1_0])
	{
		NSString *connection = [request headerField:@"Connection"];
		if (connection == nil)
			shouldDie = YES;
		else
			shouldDie = [connection caseInsensitiveCompare:@"Keep-Alive"] != NSOrderedSame;
	}
	return shouldDie;
}
- (void)die
{
	HTTPLogTrace();
	if ([httpResponse respondsToSelector:@selector(connectionDidClose)])
	{
		[httpResponse connectionDidClose];
	}
	httpResponse = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:HTTPConnectionDidDieNotification object:self];
}
@end
#pragma mark -
@implementation HTTPConfig
@synthesize server;
@synthesize documentRoot;
@synthesize queue;
- (id)initWithServer:(HTTPServer *)aServer documentRoot:(NSString *)aDocumentRoot
{
	if ((self = [super init]))
	{
		server = aServer;
		documentRoot = aDocumentRoot;
	}
	return self;
}
- (id)initWithServer:(HTTPServer *)aServer documentRoot:(NSString *)aDocumentRoot queue:(dispatch_queue_t)q
{
	if ((self = [super init]))
	{
		server = aServer;
		documentRoot = [aDocumentRoot stringByStandardizingPath];
		if ([documentRoot hasSuffix:@"/"])
		{
			documentRoot = [documentRoot stringByAppendingString:@"/"];
		}
		if (q)
		{
			queue = q;
			#if !OS_OBJECT_USE_OBJC
			dispatch_retain(queue);
			#endif
		}
	}
	return self;
}
- (void)dealloc
{
	#if !OS_OBJECT_USE_OBJC
	if (queue) dispatch_release(queue);
	#endif
}
@end
