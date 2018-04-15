#import "DDFileLogger.h"
#import <unistd.h>
#import <sys/attr.h>
#import <sys/xattr.h>
#import <libkern/OSAtomic.h>
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
#define LOG_LEVEL 2
#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog((frmt), ##__VA_ARGS__); } while(0)
@interface DDLogFileManagerDefault (PrivateAPI)
- (void)deleteOldLogFiles;
- (NSString *)defaultLogsDirectory;
@end
@interface DDFileLogger (PrivateAPI)
- (void)rollLogFileNow;
- (void)maybeRollLogFileDueToAge;
- (void)maybeRollLogFileDueToSize;
@end
#pragma mark -
@implementation DDLogFileManagerDefault
@synthesize maximumNumberOfLogFiles;
- (id)init
{
	return [self initWithLogsDirectory:nil];
}
- (id)initWithLogsDirectory:(NSString *)aLogsDirectory
{
	if ((self = [super init]))
	{
		maximumNumberOfLogFiles = DEFAULT_LOG_MAX_NUM_LOG_FILES;
		if (aLogsDirectory)
			_logsDirectory = [aLogsDirectory copy];
		else
			_logsDirectory = [[self defaultLogsDirectory] copy];
		NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
		[self addObserver:self forKeyPath:@"maximumNumberOfLogFiles" options:kvoOptions context:nil];
		NSLogVerbose(@"DDFileLogManagerDefault: logsDirectory:\n%@", [self logsDirectory]);
		NSLogVerbose(@"DDFileLogManagerDefault: sortedLogFileNames:\n%@", [self sortedLogFileNames]);
	}
	return self;
}
- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"maximumNumberOfLogFiles"];
}
#pragma mark Configuration
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSNumber *old = [change objectForKey:NSKeyValueChangeOldKey];
	NSNumber *new = [change objectForKey:NSKeyValueChangeNewKey];
	if ([old isEqual:new])
	{
		return;
	}
	if ([keyPath isEqualToString:@"maximumNumberOfLogFiles"])
	{
		NSLogInfo(@"DDFileLogManagerDefault: Responding to configuration change: maximumNumberOfLogFiles");
		dispatch_async([DDLog loggingQueue], ^{ @autoreleasepool {
			[self deleteOldLogFiles];
		}});
	}
}
#pragma mark File Deleting
- (void)deleteOldLogFiles
{
	NSLogVerbose(@"DDLogFileManagerDefault: deleteOldLogFiles");
	NSUInteger maxNumLogFiles = self.maximumNumberOfLogFiles;
	if (maxNumLogFiles == 0)
	{
		return;
	}
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	NSUInteger count = [sortedLogFileInfos count];
	BOOL excludeFirstFile = NO;
	if (count > 0)
	{
		DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:0];
		if (!logFileInfo.isArchived)
		{
			excludeFirstFile = YES;
		}
	}
	NSArray *sortedArchivedLogFileInfos;
	if (excludeFirstFile)
	{
		count--;
		sortedArchivedLogFileInfos = [sortedLogFileInfos subarrayWithRange:NSMakeRange(1, count)];
	}
	else
	{
		sortedArchivedLogFileInfos = sortedLogFileInfos;
	}
	NSUInteger i;
	for (i = maxNumLogFiles; i < count; i++)
	{
		DDLogFileInfo *logFileInfo = [sortedArchivedLogFileInfos objectAtIndex:i];
		NSLogInfo(@"DDLogFileManagerDefault: Deleting file: %@", logFileInfo.fileName);
		[[NSFileManager defaultManager] removeItemAtPath:logFileInfo.filePath error:nil];
	}
}
#pragma mark Log Files
- (NSString *)defaultLogsDirectory
{
#if TARGET_OS_IPHONE
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *baseDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"Logs"];
#else
	NSString *appName = [[NSProcessInfo processInfo] processName];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	NSString *logsDirectory = [[basePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:appName];
#endif
	return logsDirectory;
}
- (NSString *)logsDirectory
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:_logsDirectory])
	{
		NSError *err = nil;
		if (![[NSFileManager defaultManager] createDirectoryAtPath:_logsDirectory
		                               withIntermediateDirectories:YES attributes:nil error:&err])
		{
			NSLogError(@"DDFileLogManagerDefault: Error creating logsDirectory: %@", err);
		}
	}
	return _logsDirectory;
}
- (BOOL)isLogFile:(NSString *)fileName
{
	BOOL hasProperPrefix = [fileName hasPrefix:@"log-"];
	BOOL hasProperLength = [fileName length] >= 10;
	if (hasProperPrefix && hasProperLength)
	{
		NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
		NSString *hex = [fileName substringWithRange:NSMakeRange(4, 6)];
		NSString *nohex = [hex stringByTrimmingCharactersInSet:hexSet];
		if ([nohex length] == 0)
		{
			return YES;
		}
	}
	return NO;
}
- (NSArray *)unsortedLogFilePaths
{
	NSString *logsDirectory = [self logsDirectory];
	NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsDirectory error:nil];
	NSMutableArray *unsortedLogFilePaths = [NSMutableArray arrayWithCapacity:[fileNames count]];
	for (NSString *fileName in fileNames)
	{
		if ([self isLogFile:fileName])
		{
			NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
			[unsortedLogFilePaths addObject:filePath];
		}
	}
	return unsortedLogFilePaths;
}
- (NSArray *)unsortedLogFileNames
{
	NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	NSMutableArray *unsortedLogFileNames = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	for (NSString *filePath in unsortedLogFilePaths)
	{
		[unsortedLogFileNames addObject:[filePath lastPathComponent]];
	}
	return unsortedLogFileNames;
}
- (NSArray *)unsortedLogFileInfos
{
	NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	NSMutableArray *unsortedLogFileInfos = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	for (NSString *filePath in unsortedLogFilePaths)
	{
		DDLogFileInfo *logFileInfo = [[DDLogFileInfo alloc] initWithFilePath:filePath];
		[unsortedLogFileInfos addObject:logFileInfo];
	}
	return unsortedLogFileInfos;
}
- (NSArray *)sortedLogFilePaths
{
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	NSMutableArray *sortedLogFilePaths = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	for (DDLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFilePaths addObject:[logFileInfo filePath]];
	}
	return sortedLogFilePaths;
}
- (NSArray *)sortedLogFileNames
{
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	NSMutableArray *sortedLogFileNames = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	for (DDLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFileNames addObject:[logFileInfo fileName]];
	}
	return sortedLogFileNames;
}
- (NSArray *)sortedLogFileInfos
{
	return [[self unsortedLogFileInfos] sortedArrayUsingSelector:@selector(reverseCompareByCreationDate:)];
}
#pragma mark Creation
- (NSString *)generateShortUUID
{
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	CFStringRef fullStr = CFUUIDCreateString(NULL, uuid);
	NSString *result = (__bridge_transfer NSString *)CFStringCreateWithSubstring(NULL, fullStr, CFRangeMake(0, 6));
	CFRelease(fullStr);
	CFRelease(uuid);
	return result;
}
- (NSString *)createNewLogFile
{
	NSString *logsDirectory = [self logsDirectory];
	do
	{
		NSString *fileName = [NSString stringWithFormat:@"log-%@.txt", [self generateShortUUID]];
		NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
		if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
		{
			NSLogVerbose(@"DDLogFileManagerDefault: Creating new log file: %@", fileName);
			[[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
			[self deleteOldLogFiles];
			return filePath;
		}
	} while(YES);
}
@end
#pragma mark -
@implementation DDLogFileFormatterDefault
- (id)init
{
	return [self initWithDateFormatter:nil];
}
- (id)initWithDateFormatter:(NSDateFormatter *)aDateFormatter
{
	if ((self = [super init]))
	{
		if (aDateFormatter)
		{
			dateFormatter = aDateFormatter;
		}
		else
		{
			dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4]; 
			[dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
		}
	}
	return self;
}
- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
	NSString *dateAndTime = [dateFormatter stringFromDate:(logMessage->timestamp)];
	return [NSString stringWithFormat:@"%@  %@", dateAndTime, logMessage->logMsg];
}
@end
#pragma mark -
@implementation DDFileLogger
- (id)init
{
	DDLogFileManagerDefault *defaultLogFileManager = [[DDLogFileManagerDefault alloc] init];
	return [self initWithLogFileManager:defaultLogFileManager];
}
- (id)initWithLogFileManager:(id <DDLogFileManager>)aLogFileManager
{
	if ((self = [super init]))
	{
		maximumFileSize = DEFAULT_LOG_MAX_FILE_SIZE;
		rollingFrequency = DEFAULT_LOG_ROLLING_FREQUENCY;
		logFileManager = aLogFileManager;
		formatter = [[DDLogFileFormatterDefault alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[currentLogFileHandle synchronizeFile];
	[currentLogFileHandle closeFile];
	if (rollingTimer)
	{
		dispatch_source_cancel(rollingTimer);
		rollingTimer = NULL;
	}
}
#pragma mark Properties
@synthesize logFileManager;
- (unsigned long long)maximumFileSize
{
	__block unsigned long long result;
	dispatch_block_t block = ^{
		result = maximumFileSize;
	};
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, block);
	});
	return result;
}
- (void)setMaximumFileSize:(unsigned long long)newMaximumFileSize
{
	dispatch_block_t block = ^{ @autoreleasepool {
		maximumFileSize = newMaximumFileSize;
		[self maybeRollLogFileDueToSize];
	}};
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	dispatch_async(globalLoggingQueue, ^{
		dispatch_async(loggerQueue, block);
	});
}
- (NSTimeInterval)rollingFrequency
{
	__block NSTimeInterval result;
	dispatch_block_t block = ^{
		result = rollingFrequency;
	};
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, block);
	});
	return result;
}
- (void)setRollingFrequency:(NSTimeInterval)newRollingFrequency
{
	dispatch_block_t block = ^{ @autoreleasepool {
		rollingFrequency = newRollingFrequency;
		[self maybeRollLogFileDueToAge];
	}};
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	dispatch_async(globalLoggingQueue, ^{
		dispatch_async(loggerQueue, block);
	});
}
#pragma mark File Rolling
- (void)scheduleTimerToRollLogFileDueToAge
{
	if (rollingTimer)
	{
		dispatch_source_cancel(rollingTimer);
		rollingTimer = NULL;
	}
	if (currentLogFileInfo == nil || rollingFrequency <= 0.0)
	{
		return;
	}
	NSDate *logFileCreationDate = [currentLogFileInfo creationDate];
	NSTimeInterval ti = [logFileCreationDate timeIntervalSinceReferenceDate];
	ti += rollingFrequency;
	NSDate *logFileRollingDate = [NSDate dateWithTimeIntervalSinceReferenceDate:ti];
	NSLogVerbose(@"DDFileLogger: scheduleTimerToRollLogFileDueToAge");
	NSLogVerbose(@"DDFileLogger: logFileCreationDate: %@", logFileCreationDate);
	NSLogVerbose(@"DDFileLogger: logFileRollingDate : %@", logFileRollingDate);
	rollingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, loggerQueue);
	dispatch_source_set_event_handler(rollingTimer, ^{ @autoreleasepool {
		[self maybeRollLogFileDueToAge];
	}});
	#if !OS_OBJECT_USE_OBJC
	dispatch_source_t theRollingTimer = rollingTimer;
	dispatch_source_set_cancel_handler(rollingTimer, ^{
		dispatch_release(theRollingTimer);
	});
	#endif
	uint64_t delay = (uint64_t)([logFileRollingDate timeIntervalSinceNow] * NSEC_PER_SEC);
	dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, delay);
	dispatch_source_set_timer(rollingTimer, fireTime, DISPATCH_TIME_FOREVER, 1.0);
	dispatch_resume(rollingTimer);
}
- (void)rollLogFile
{
	dispatch_block_t block = ^{ @autoreleasepool {
		[self rollLogFileNow];
	}};
	if ([self isOnInternalLoggerQueue])
	{
		block();
	}
	else
	{
		dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
		NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
		dispatch_async(globalLoggingQueue, ^{
			dispatch_async(loggerQueue, block);
		});
	}
}
- (void)rollLogFileNow
{
	NSLogVerbose(@"DDFileLogger: rollLogFileNow");
	if (currentLogFileHandle == nil) return;
	[currentLogFileHandle synchronizeFile];
	[currentLogFileHandle closeFile];
	currentLogFileHandle = nil;
	currentLogFileInfo.isArchived = YES;
	if ([logFileManager respondsToSelector:@selector(didRollAndArchiveLogFile:)])
	{
		[logFileManager didRollAndArchiveLogFile:(currentLogFileInfo.filePath)];
	}
	currentLogFileInfo = nil;
	if (rollingTimer)
	{
		dispatch_source_cancel(rollingTimer);
		rollingTimer = NULL;
	}
}
- (void)maybeRollLogFileDueToAge
{
	if (rollingFrequency > 0.0 && currentLogFileInfo.age >= rollingFrequency)
	{
		NSLogVerbose(@"DDFileLogger: Rolling log file due to age...");
		[self rollLogFileNow];
	}
	else
	{
		[self scheduleTimerToRollLogFileDueToAge];
	}
}
- (void)maybeRollLogFileDueToSize
{
	if (maximumFileSize > 0)
	{
		unsigned long long fileSize = [currentLogFileHandle offsetInFile];
		if (fileSize >= maximumFileSize)
		{
			NSLogVerbose(@"DDFileLogger: Rolling log file due to size (%qu)...", fileSize);
			[self rollLogFileNow];
		}
	}
}
#pragma mark File Logging
- (DDLogFileInfo *)currentLogFileInfo
{
	if (currentLogFileInfo == nil)
	{
		NSArray *sortedLogFileInfos = [logFileManager sortedLogFileInfos];
		if ([sortedLogFileInfos count] > 0)
		{
			DDLogFileInfo *mostRecentLogFileInfo = [sortedLogFileInfos objectAtIndex:0];
			BOOL useExistingLogFile = YES;
			BOOL shouldArchiveMostRecent = NO;
			if (mostRecentLogFileInfo.isArchived)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = NO;
			}
			else if (maximumFileSize > 0 && mostRecentLogFileInfo.fileSize >= maximumFileSize)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = YES;
			}
			else if (rollingFrequency > 0.0 && mostRecentLogFileInfo.age >= rollingFrequency)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = YES;
			}
			if (useExistingLogFile)
			{
				NSLogVerbose(@"DDFileLogger: Resuming logging with file %@", mostRecentLogFileInfo.fileName);
				currentLogFileInfo = mostRecentLogFileInfo;
			}
			else
			{
				if (shouldArchiveMostRecent)
				{
					mostRecentLogFileInfo.isArchived = YES;
					if ([logFileManager respondsToSelector:@selector(didArchiveLogFile:)])
					{
						[logFileManager didArchiveLogFile:(mostRecentLogFileInfo.filePath)];
					}
				}
			}
		}
		if (currentLogFileInfo == nil)
		{
			NSString *currentLogFilePath = [logFileManager createNewLogFile];
			currentLogFileInfo = [[DDLogFileInfo alloc] initWithFilePath:currentLogFilePath];
		}
	}
	return currentLogFileInfo;
}
- (NSFileHandle *)currentLogFileHandle
{
	if (currentLogFileHandle == nil)
	{
		NSString *logFilePath = [[self currentLogFileInfo] filePath];
		currentLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
		[currentLogFileHandle seekToEndOfFile];
		if (currentLogFileHandle)
		{
			[self scheduleTimerToRollLogFileDueToAge];
		}
	}
	return currentLogFileHandle;
}
#pragma mark DDLogger Protocol
- (void)logMessage:(DDLogMessage *)logMessage
{
	NSString *logMsg = logMessage->logMsg;
	if (formatter)
	{
		logMsg = [formatter formatLogMessage:logMessage];
	}
	if (logMsg)
	{
		if (![logMsg hasSuffix:@"\n"])
		{
			logMsg = [logMsg stringByAppendingString:@"\n"];
		}
		NSData *logData = [logMsg dataUsingEncoding:NSUTF8StringEncoding];
		[[self currentLogFileHandle] writeData:logData];
		[self maybeRollLogFileDueToSize];
	}
}
- (void)willRemoveLogger
{
	[self rollLogFileNow];
}
- (NSString *)loggerName
{
	return @"cocoa.lumberjack.fileLogger";
}
@end
#pragma mark -
#if TARGET_IPHONE_SIMULATOR
  #define XATTR_ARCHIVED_NAME  @"archived"
#else
  #define XATTR_ARCHIVED_NAME  @"lumberjack.log.archived"
#endif
@implementation DDLogFileInfo
@synthesize filePath;
@dynamic fileName;
@dynamic fileAttributes;
@dynamic creationDate;
@dynamic modificationDate;
@dynamic fileSize;
@dynamic age;
@dynamic isArchived;
#pragma mark Lifecycle
+ (id)logFileWithPath:(NSString *)aFilePath
{
	return [[DDLogFileInfo alloc] initWithFilePath:aFilePath];
}
- (id)initWithFilePath:(NSString *)aFilePath
{
	if ((self = [super init]))
	{
		filePath = [aFilePath copy];
	}
	return self;
}
#pragma mark Standard Info
- (NSDictionary *)fileAttributes
{
	if (fileAttributes == nil)
	{
		fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
	}
	return fileAttributes;
}
- (NSString *)fileName
{
	if (fileName == nil)
	{
		fileName = [filePath lastPathComponent];
	}
	return fileName;
}
- (NSDate *)modificationDate
{
	if (modificationDate == nil)
	{
		modificationDate = [[self fileAttributes] objectForKey:NSFileModificationDate];
	}
	return modificationDate;
}
- (NSDate *)creationDate
{
	if (creationDate == nil)
	{
	#if TARGET_OS_IPHONE
		const char *path = [filePath UTF8String];
		struct attrlist attrList;
		memset(&attrList, 0, sizeof(attrList));
		attrList.bitmapcount = ATTR_BIT_MAP_COUNT;
		attrList.commonattr = ATTR_CMN_CRTIME;
		struct {
			u_int32_t attrBufferSizeInBytes;
			struct timespec crtime;
		} attrBuffer;
		int result = getattrlist(path, &attrList, &attrBuffer, sizeof(attrBuffer), 0);
		if (result == 0)
		{
			double seconds = (double)(attrBuffer.crtime.tv_sec);
			double nanos   = (double)(attrBuffer.crtime.tv_nsec);
			NSTimeInterval ti = seconds + (nanos / 1000000000.0);
			creationDate = [NSDate dateWithTimeIntervalSince1970:ti];
		}
		else
		{
			NSLogError(@"DDLogFileInfo: creationDate(%@): getattrlist result = %i", self.fileName, result);
		}
	#else
		creationDate = [[self fileAttributes] objectForKey:NSFileCreationDate];
	#endif
	}
	return creationDate;
}
- (unsigned long long)fileSize
{
	if (fileSize == 0)
	{
		fileSize = [[[self fileAttributes] objectForKey:NSFileSize] unsignedLongLongValue];
	}
	return fileSize;
}
- (NSTimeInterval)age
{
	return [[self creationDate] timeIntervalSinceNow] * -1.0;
}
- (NSString *)description
{
	return [@{@"filePath": self.filePath,
		@"fileName": self.fileName,
		@"fileAttributes": self.fileAttributes,
		@"creationDate": self.creationDate,
		@"modificationDate": self.modificationDate,
		@"fileSize": @(self.fileSize),
		@"age": @(self.age),
		@"isArchived": @(self.isArchived)} description];
}
#pragma mark Archiving
- (BOOL)isArchived
{
#if TARGET_IPHONE_SIMULATOR
	return [self hasExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
#else
	return [self hasExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
#endif
}
- (void)setIsArchived:(BOOL)flag
{
#if TARGET_IPHONE_SIMULATOR
	if (flag)
		[self addExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
	else
		[self removeExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
#else
	if (flag)
		[self addExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	else
		[self removeExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
#endif
}
#pragma mark Changes
- (void)reset
{
	fileName = nil;
	fileAttributes = nil;
	creationDate = nil;
	modificationDate = nil;
}
- (void)renameFile:(NSString *)newFileName
{
	if (![newFileName isEqualToString:[self fileName]])
	{
		NSString *fileDir = [filePath stringByDeletingLastPathComponent];
		NSString *newFilePath = [fileDir stringByAppendingPathComponent:newFileName];
		NSLogVerbose(@"DDLogFileInfo: Renaming file: '%@' -> '%@'", self.fileName, newFileName);
		NSError *error = nil;
		if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newFilePath error:&error])
		{
			NSLogError(@"DDLogFileInfo: Error renaming file (%@): %@", self.fileName, error);
		}
		filePath = newFilePath;
		[self reset];
	}
}
#pragma mark Attribute Management
#if TARGET_IPHONE_SIMULATOR
- (BOOL)hasExtensionAttributeWithName:(NSString *)attrName
{
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	NSUInteger count = [components count];
	NSUInteger max = (count >= 2) ? count-1 : count;
	NSUInteger i;
	for (i = 1; i < max; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		if ([attrName isEqualToString:attr])
		{
			return YES;
		}
	}
	return NO;
}
- (void)addExtensionAttributeWithName:(NSString *)attrName
{
	if ([attrName length] == 0) return;
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	NSUInteger count = [components count];
	NSUInteger estimatedNewLength = [[self fileName] length] + [attrName length] + 1;
	NSMutableString *newFileName = [NSMutableString stringWithCapacity:estimatedNewLength];
	if (count > 0)
	{
		[newFileName appendString:[components objectAtIndex:0]];
	}
	NSString *lastExt = @"";
	NSUInteger i;
	for (i = 1; i < count; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		if ([attr length] == 0)
		{
			continue;
		}
		if ([attrName isEqualToString:attr])
		{
			return;
		}
		if ([lastExt length] > 0)
		{
			[newFileName appendFormat:@".%@", lastExt];
		}
		lastExt = attr;
	}
	[newFileName appendFormat:@".%@", attrName];
	if ([lastExt length] > 0)
	{
		[newFileName appendFormat:@".%@", lastExt];
	}
	[self renameFile:newFileName];
}
- (void)removeExtensionAttributeWithName:(NSString *)attrName
{
	if ([attrName length] == 0) return;
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	NSUInteger count = [components count];
	NSUInteger estimatedNewLength = [[self fileName] length];
	NSMutableString *newFileName = [NSMutableString stringWithCapacity:estimatedNewLength];
	if (count > 0)
	{
		[newFileName appendString:[components objectAtIndex:0]];
	}
	BOOL found = NO;
	NSUInteger i;
	for (i = 1; i < count; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		if ([attrName isEqualToString:attr])
		{
			found = YES;
		}
		else
		{
			[newFileName appendFormat:@".%@", attr];
		}
	}
	if (found)
	{
		[self renameFile:newFileName];
	}
}
#else
- (BOOL)hasExtendedAttributeWithName:(NSString *)attrName
{
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	ssize_t result = getxattr(path, name, NULL, 0, 0, 0);
	return (result >= 0);
}
- (void)addExtendedAttributeWithName:(NSString *)attrName
{
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	int result = setxattr(path, name, NULL, 0, 0, 0);
	if (result < 0)
	{
		NSLogError(@"DDLogFileInfo: setxattr(%@, %@): error = %i", attrName, self.fileName, result);
	}
}
- (void)removeExtendedAttributeWithName:(NSString *)attrName
{
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	int result = removexattr(path, name, 0);
	if (result < 0 && errno != ENOATTR)
	{
		NSLogError(@"DDLogFileInfo: removexattr(%@, %@): error = %i", attrName, self.fileName, result);
	}
}
#endif
#pragma mark Comparisons
- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[self class]])
	{
		DDLogFileInfo *another = (DDLogFileInfo *)object;
		return [filePath isEqualToString:[another filePath]];
	}
	return NO;
}
- (NSComparisonResult)reverseCompareByCreationDate:(DDLogFileInfo *)another
{
	NSDate *us = [self creationDate];
	NSDate *them = [another creationDate];
	NSComparisonResult result = [us compare:them];
	if (result == NSOrderedAscending)
		return NSOrderedDescending;
	if (result == NSOrderedDescending)
		return NSOrderedAscending;
	return NSOrderedSame;
}
- (NSComparisonResult)reverseCompareByModificationDate:(DDLogFileInfo *)another
{
	NSDate *us = [self modificationDate];
	NSDate *them = [another modificationDate];
	NSComparisonResult result = [us compare:them];
	if (result == NSOrderedAscending)
		return NSOrderedDescending;
	if (result == NSOrderedDescending)
		return NSOrderedAscending;
	return NSOrderedSame;
}
@end
