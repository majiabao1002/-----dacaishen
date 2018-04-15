#import "HTTPFileResponse.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"
#import <unistd.h>
#import <fcntl.h>
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; 
#define NULL_FD  -1
@implementation HTTPFileResponse
- (id)initWithFilePath:(NSString *)fpath forConnection:(HTTPConnection *)parent
{
	if((self = [super init]))
	{
		HTTPLogTrace();
		connection = parent; 
		fileFD = NULL_FD;
		filePath = [[fpath copy] stringByResolvingSymlinksInPath];
		if (filePath == nil)
		{
			HTTPLogWarn(@"%@: Init failed - Nil filePath", THIS_FILE);
			return nil;
		}
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
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
- (BOOL)openFile
{
	HTTPLogTrace();
	fileFD = open([filePath UTF8String], O_RDONLY);
	if (fileFD == NULL_FD)
	{
		HTTPLogError(@"%@[%p]: Unable to open file. filePath: %@", THIS_FILE, self, filePath);
		[self abort];
		return NO;
	}
	HTTPLogVerbose(@"%@[%p]: Open fd[%i] -> %@", THIS_FILE, self, fileFD, filePath);
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
	return [self openFile];
}
- (UInt64)contentLength
{
	HTTPLogTrace();
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
	if (![self openFileIfNeeded])
	{
		return nil;
	}
	UInt64 bytesLeftInFile = fileLength - fileOffset;
	NSUInteger bytesToRead = (NSUInteger)MIN(length, bytesLeftInFile);
	if (buffer == NULL || bufferSize < bytesToRead)
	{
		bufferSize = bytesToRead;
		buffer = reallocf(buffer, (size_t)bufferSize);
		if (buffer == NULL)
		{
			HTTPLogError(@"%@[%p]: Unable to allocate buffer", THIS_FILE, self);
			[self abort];
			return nil;
		}
	}
	HTTPLogVerbose(@"%@[%p]: Attempting to read %lu bytes from file", THIS_FILE, self, (unsigned long)bytesToRead);
	ssize_t result = read(fileFD, buffer, bytesToRead);
	if (result < 0)
	{
		HTTPLogError(@"%@: Error(%i) reading file(%@)", THIS_FILE, errno, filePath);
		[self abort];
		return nil;
	}
	else if (result == 0)
	{
		HTTPLogError(@"%@: Read EOF on file(%@)", THIS_FILE, filePath);
		[self abort];
		return nil;
	}
	else 
	{
		HTTPLogVerbose(@"%@[%p]: Read %ld bytes from file", THIS_FILE, self, (long)result);
		fileOffset += result;
		return [NSData dataWithBytes:buffer length:result];
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
- (void)dealloc
{
	HTTPLogTrace();
	if (fileFD != NULL_FD)
	{
		HTTPLogVerbose(@"%@[%p]: Close fd[%i]", THIS_FILE, self, fileFD);
		close(fileFD);
	}
	if (buffer)
		free(buffer);
}
@end
