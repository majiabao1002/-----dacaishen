#import "HTTPDynamicFileResponse.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; 
#define NULL_FD  -1
@implementation HTTPDynamicFileResponse
- (id)initWithFilePath:(NSString *)fpath
         forConnection:(HTTPConnection *)parent
             separator:(NSString *)separatorStr
 replacementDictionary:(NSDictionary *)dict
{
	if ((self = [super initWithFilePath:fpath forConnection:parent]))
	{
		HTTPLogTrace();
		separator = [separatorStr dataUsingEncoding:NSUTF8StringEncoding];
		replacementDict = dict;
	}
	return self;
}
- (BOOL)isChunked
{
	HTTPLogTrace();
	return YES;
}
- (UInt64)contentLength
{
	HTTPLogTrace();
	return 0;
}
- (void)setOffset:(UInt64)offset
{
	HTTPLogTrace();
}
- (BOOL)isDone
{
	BOOL result = (readOffset == fileLength) && (readBufferOffset == 0);
	HTTPLogTrace2(@"%@[%p]: isDone - %@", THIS_FILE, self, (result ? @"YES" : @"NO"));
	return result;
}
- (void)processReadBuffer
{
	HTTPLogTrace();
	NSUInteger bufLen = readBufferOffset;
	NSUInteger sepLen = [separator length];
	NSUInteger offset = 0;
	NSUInteger stopOffset = (bufLen > sepLen) ? bufLen - sepLen + 1 : 0;
	BOOL found1 = NO;
	BOOL found2 = NO;
	NSUInteger s1 = 0;
	NSUInteger s2 = 0;
	const void *sep = [separator bytes];
	while (offset < stopOffset)
	{
		const void *subBuffer = readBuffer + offset;
		if (memcmp(subBuffer, sep, sepLen) == 0)
		{
			if (!found1)
			{
				found1 = YES;
				s1 = offset;
				offset += sepLen;
				HTTPLogVerbose(@"%@[%p]: Found s1 at %lu", THIS_FILE, self, (unsigned long)s1);
			}
			else
			{
				found2 = YES;
				s2 = offset;
				offset += sepLen;
				HTTPLogVerbose(@"%@[%p]: Found s2 at %lu", THIS_FILE, self, (unsigned long)s2);
			}
			if (found1 && found2)
			{
				NSRange fullRange = NSMakeRange(s1, (s2 - s1 + sepLen));
				NSRange strRange = NSMakeRange(s1 + sepLen, (s2 - s1 - sepLen));
				void *strBuf = readBuffer + strRange.location;
				NSUInteger strLen = strRange.length;
				NSString *key = [[NSString alloc] initWithBytes:strBuf length:strLen encoding:NSUTF8StringEncoding];
				if (key)
				{
					id value = [replacementDict objectForKey:key];
					if (value)
					{
						HTTPLogVerbose(@"%@[%p]: key(%@) -> value(%@)", THIS_FILE, self, key, value);
						NSData *v = [[value description] dataUsingEncoding:NSUTF8StringEncoding];
						NSUInteger vLength = [v length];
						if (fullRange.length == vLength)
						{
							memcpy(readBuffer + fullRange.location, [v bytes], vLength);
						}
						else 
						{
							NSInteger diff = (NSInteger)vLength - (NSInteger)fullRange.length;
							if (diff > 0)
							{
								if (diff > (readBufferSize - bufLen))
								{
									NSUInteger inc = MAX(diff, 256);
									readBufferSize += inc;
									readBuffer = reallocf(readBuffer, readBufferSize);
								}
							}
							void *src = readBuffer + fullRange.location + fullRange.length;
							void *dst = readBuffer + fullRange.location + vLength;
							NSUInteger remaining = bufLen - (fullRange.location + fullRange.length);
							memmove(dst, src, remaining);
							memcpy(readBuffer + fullRange.location, [v bytes], vLength);
							bufLen     += diff;
							offset     += diff;
							stopOffset += diff;
						}
					}
				}
				found1 = found2 = NO;
			}
		}
		else
		{
			offset++;
		}
	}
	if (readOffset == fileLength)
	{
		data = [[NSData alloc] initWithBytes:readBuffer length:bufLen];
		readBufferOffset = 0;
	}
	else
	{
		NSUInteger available;
		if (found1)
		{
			available = s1;
		}
		else
		{
			available = stopOffset;
		}
		data = [[NSData alloc] initWithBytes:readBuffer length:available];
		NSUInteger remaining = bufLen - available;
		memmove(readBuffer, readBuffer + available, remaining);
		readBufferOffset = remaining;
	}
	[connection responseHasAvailableData:self];
}
- (void)dealloc
{
	HTTPLogTrace();
}
@end
