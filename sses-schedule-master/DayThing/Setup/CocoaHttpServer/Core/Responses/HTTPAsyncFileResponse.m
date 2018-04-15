#import "HTTPAsyncFileResponse.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"
#import <unistd.h>
#import <fcntl.h>
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; 
#define NULL_FD  -1
@implementation HTTPAsyncFileResponse
- (id)initWithFilePath:(NSString *)fpath forConnection:(HTTPConnection *)parent
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		connection = parent; 
		fileFD = NULL_FD;
		filePath = [fpath copy];
		if (filePath == nil)
		{
			HTTPLogWarn(@"%@: Init failed - Nil filePath", THIS_FILE);
			return nil;
		}
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL];
		if (fileAttributes == nil)
		{
			HTTPLogWarn(@"%@: Init failed - Unable to get file attributes. filePath: %@", THIS_FILE, filePath);
			return nil;
		}
		fileLength = (UInt64)[[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
		fileOffset = 0;
		aborted = NO;
	}
	return self;
}
- (void)abort
{
	HTTPLogTrace();
	[connection responseDidAbort:self];
	aborted = YES;
}
- (void)processReadBuffer
{
	data = [[NSData alloc] initWithBytes:readBuffer length:readBufferOffset];
	readBufferOffset = 0;
	[connection responseHasAvailableData:self];
}
- (void)pauseReadSource
{
	if (!readSourceSuspended)
	{
		HTTPLogVerbose(@"%@[%p]: Suspending readSource", THIS_FILE, self);
		readSourceSuspended = YES;
		dispatch_suspend(readSource);
	}
}
- (void)resumeReadSource
{
	if (readSourceSuspended)
	{
		HTTPLogVerbose(@"%@[%p]: Resuming readSource", THIS_FILE, self);
		readSourceSuspended = NO;
		dispatch_resume(readSource);
	}
}
- (void)cancelReadSource
{
	HTTPLogVerbose(@"%@[%p]: Canceling readSource", THIS_FILE, self);
	dispatch_source_cancel(readSource);
	if (readSourceSuspended)
	{
		readSourceSuspended = NO;
		dispatch_resume(readSource);
	}
}
- (BOOL)openFileAndSetupReadSource
{
	HTTPLogTrace();
	fileFD = open([filePath UTF8String], (O_RDONLY | O_NONBLOCK));
	if (fileFD == NULL_FD)
	{
		HTTPLogError(@"%@: Unable to open file. filePath: %@", THIS_FILE, filePath);
		return NO;
	}
	HTTPLogVerbose(@"%@[%p]: Open fd[%i] -> %@", THIS_FILE, self, fileFD, filePath);
	readQueue = dispatch_queue_create("HTTPAsyncFileResponse", NULL);
	readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fileFD, 0, readQueue);
	dispatch_source_set_event_handler(readSource, ^{
		HTTPLogTrace2(@"%@: eventBlock - fd[%i]", THIS_FILE, fileFD);
		unsigned long long _bytesAvailableOnFD = dispatch_source_get_data(readSource);
		UInt64 _bytesLeftInFile = fileLength - readOffset;
		NSUInteger bytesAvailableOnFD;
		NSUInteger bytesLeftInFile;
		bytesAvailableOnFD = (_bytesAvailableOnFD > NSUIntegerMax) ? NSUIntegerMax : (NSUInteger)_bytesAvailableOnFD;
		bytesLeftInFile    = (_bytesLeftInFile    > NSUIntegerMax) ? NSUIntegerMax : (NSUInteger)_bytesLeftInFile;
		NSUInteger bytesLeftInRequest = readRequestLength - readBufferOffset;
		NSUInteger bytesLeft = MIN(bytesLeftInRequest, bytesLeftInFile);
		NSUInteger bytesToRead = MIN(bytesAvailableOnFD, bytesLeft);
		if (readBuffer == NULL || bytesToRead > (readBufferSize - readBufferOffset))
		{
			readBufferSize = bytesToRead;
			readBuffer = reallocf(readBuffer, (size_t)bytesToRead);
			if (readBuffer == NULL)
			{
				HTTPLogError(@"%@[%p]: Unable to allocate buffer", THIS_FILE, self);
				[self pauseReadSource];
				[self abort];
				return;
			}
		}
		HTTPLogVerbose(@"%@[%p]: Attempting to read %lu bytes from file", THIS_FILE, self, (unsigned long)bytesToRead);
		ssize_t result = read(fileFD, readBuffer + readBufferOffset, (size_t)bytesToRead);
		if (result < 0)
		{
			HTTPLogError(@"%@: Error(%i) reading file(%@)", THIS_FILE, errno, filePath);
			[self pauseReadSource];
			[self abort];
		}
		else if (result == 0)
		{
			HTTPLogError(@"%@: Read EOF on file(%@)", THIS_FILE, filePath);
			[self pauseReadSource];
			[self abort];
		}
		else 
		{
			HTTPLogVerbose(@"%@[%p]: Read %lu bytes from file", THIS_FILE, self, (unsigned long)result);
			readOffset += result;
			readBufferOffset += result;
			[self pauseReadSource];
			[self processReadBuffer];
		}
	});
	int theFileFD = fileFD;
	#if !OS_OBJECT_USE_OBJC
	dispatch_source_t theReadSource = readSource;
	#endif
	dispatch_source_set_cancel_handler(readSource, ^{
		HTTPLogTrace2(@"%@: cancelBlock - Close fd[%i]", THIS_FILE, theFileFD);
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(theReadSource);
		#endif
		close(theFileFD);
	});
	readSourceSuspended = YES;
	return YES;
}
- (BOOL)openFileIfNeeded
{
	if (aborted)
	{
		return NO;
	}
	if (fileFD != NULL_FD)
	{
		return YES;
	}
	return [self openFileAndSetupReadSource];
}	
- (UInt64)contentLength
{
	HTTPLogTrace2(@"%@[%p]: contentLength - %llu", THIS_FILE, self, fileLength);
	return fileLength;
}
- (UInt64)offset
{
	HTTPLogTrace();
	return fileOffset;
}
- (void)setOffset:(UInt64)offset
{
	HTTPLogTrace2(@"%@[%p]: setOffset:%llu", THIS_FILE, self, offset);
	if (![self openFileIfNeeded])
	{
		return;
	}
	fileOffset = offset;
	readOffset = offset;
	off_t result = lseek(fileFD, (off_t)offset, SEEK_SET);
	if (result == -1)
	{
		HTTPLogError(@"%@[%p]: lseek failed - errno(%i) filePath(%@)", THIS_FILE, self, errno, filePath);
		[self abort];
	}
}
- (NSData *)readDataOfLength:(NSUInteger)length
{
	HTTPLogTrace2(@"%@[%p]: readDataOfLength:%lu", THIS_FILE, self, (unsigned long)length);
	if (data)
	{
		NSUInteger dataLength = [data length];
		HTTPLogVerbose(@"%@[%p]: Returning data of length %lu", THIS_FILE, self, (unsigned long)dataLength);
		fileOffset += dataLength;
		NSData *result = data;
		data = nil;
		return result;
	}
	else
	{
		if (![self openFileIfNeeded])
		{
			return nil;
		}
		dispatch_sync(readQueue, ^{
			NSAssert(readSourceSuspended, @"Invalid logic - perhaps HTTPConnection has changed.");
			readRequestLength = length;
			[self resumeReadSource];
		});
		return nil;
	}
}
- (BOOL)isDone
{
	BOOL result = (fileOffset == fileLength);
	HTTPLogTrace2(@"%@[%p]: isDone - %@", THIS_FILE, self, (result ? @"YES" : @"NO"));
	return result;
}
- (NSString *)filePath
{
	return filePath;
}
- (BOOL)isAsynchronous
{
	HTTPLogTrace();
	return YES;
}
- (void)connectionDidClose
{
	HTTPLogTrace();
	if (fileFD != NULL_FD)
	{
		dispatch_sync(readQueue, ^{
			connection = nil;
			[self cancelReadSource];
		});
	}
}
- (void)dealloc
{
	HTTPLogTrace();
	#if !OS_OBJECT_USE_OBJC
	if (readQueue) dispatch_release(readQueue);
	#endif
	if (readBuffer)
		free(readBuffer);
}
@end
