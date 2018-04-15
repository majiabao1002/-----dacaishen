#import "DispatchQueueLogFormatter.h"
#import <libkern/OSAtomic.h>
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
@implementation DispatchQueueLogFormatter
{
	int32_t atomicLoggerCount;
	NSDateFormatter *threadUnsafeDateFormatter; 
	OSSpinLock lock;
	NSUInteger _minQueueLength;           
	NSUInteger _maxQueueLength;           
	NSMutableDictionary *_replacements;   
}
- (id)init
{
	if ((self = [super init]))
	{
		dateFormatString = @"yyyy-MM-dd HH:mm:ss:SSS";
		atomicLoggerCount = 0;
		threadUnsafeDateFormatter = nil;
		_minQueueLength = 0;
		_maxQueueLength = 0;
		_replacements = [[NSMutableDictionary alloc] init];
		[_replacements setObject:@"main" forKey:@"com.apple.main-thread"];
	}
	return self;
}
#pragma mark Configuration
@synthesize minQueueLength = _minQueueLength;
@synthesize maxQueueLength = _maxQueueLength;
- (NSString *)replacementStringForQueueLabel:(NSString *)longLabel
{
	NSString *result = nil;
	OSSpinLockLock(&lock);
	{
		result = [_replacements objectForKey:longLabel];
	}
	OSSpinLockUnlock(&lock);
	return result;
}
- (void)setReplacementString:(NSString *)shortLabel forQueueLabel:(NSString *)longLabel
{
	OSSpinLockLock(&lock);
	{
		if (shortLabel)
			[_replacements setObject:shortLabel forKey:longLabel];
		else
			[_replacements removeObjectForKey:longLabel];
	}
	OSSpinLockUnlock(&lock);
}
#pragma mark DDLogFormatter
- (NSString *)stringFromDate:(NSDate *)date
{
	int32_t loggerCount = OSAtomicAdd32(0, &atomicLoggerCount);
	if (loggerCount <= 1)
	{
		if (threadUnsafeDateFormatter == nil)
		{
			threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
			[threadUnsafeDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
			[threadUnsafeDateFormatter setDateFormat:dateFormatString];
		}
		return [threadUnsafeDateFormatter stringFromDate:date];
	}
	else
	{
		NSString *key = @"DispatchQueueLogFormatter_NSDateFormatter";
		NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
		NSDateFormatter *dateFormatter = [threadDictionary objectForKey:key];
		if (dateFormatter == nil)
		{
			dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
			[dateFormatter setDateFormat:dateFormatString];
			[threadDictionary setObject:dateFormatter forKey:key];
		}
		return [dateFormatter stringFromDate:date];
	}
}
- (NSString *)queueThreadLabelForLogMessage:(DDLogMessage *)logMessage
{
	NSUInteger minQueueLength = self.minQueueLength;
	NSUInteger maxQueueLength = self.maxQueueLength;
	NSString *queueThreadLabel = nil;
	BOOL useQueueLabel = YES;
	BOOL useThreadName = NO;
	if (logMessage->queueLabel)
	{
		char *names[] = { "com.apple.root.low-priority",
		                  "com.apple.root.default-priority",
		                  "com.apple.root.high-priority",
		                  "com.apple.root.low-overcommit-priority",
		                  "com.apple.root.default-overcommit-priority",
		                  "com.apple.root.high-overcommit-priority"     };
		int length = sizeof(names) / sizeof(char *);
		int i;
		for (i = 0; i < length; i++)
		{
			if (strcmp(logMessage->queueLabel, names[i]) == 0)
			{
				useQueueLabel = NO;
				useThreadName = [logMessage->threadName length] > 0;
				break;
			}
		}
	}
	else
	{
		useQueueLabel = NO;
		useThreadName = [logMessage->threadName length] > 0;
	}
	if (useQueueLabel || useThreadName)
	{
		NSString *fullLabel;
		NSString *abrvLabel;
		if (useQueueLabel)
			fullLabel = @(logMessage->queueLabel);
		else
			fullLabel = logMessage->threadName;
		OSSpinLockLock(&lock);
		{
			abrvLabel = [_replacements objectForKey:fullLabel];
		}
		OSSpinLockUnlock(&lock);
		if (abrvLabel)
			queueThreadLabel = abrvLabel;
		else
			queueThreadLabel = fullLabel;
	}
	else
	{
		queueThreadLabel = [NSString stringWithFormat:@"%x", logMessage->machThreadID];
	}
	NSUInteger labelLength = [queueThreadLabel length];
	if ((maxQueueLength > 0) && (labelLength > maxQueueLength))
	{
		return [queueThreadLabel substringToIndex:maxQueueLength];
	}
	else if (labelLength < minQueueLength)
	{
		NSUInteger numSpaces = minQueueLength - labelLength;
		char spaces[numSpaces + 1];
		memset(spaces, ' ', numSpaces);
		spaces[numSpaces] = '\0';
		return [NSString stringWithFormat:@"%@%s", queueThreadLabel, spaces];
	}
	else
	{
		return queueThreadLabel;
	}
}
- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
	NSString *timestamp = [self stringFromDate:(logMessage->timestamp)];
	NSString *queueThreadLabel = [self queueThreadLabelForLogMessage:logMessage];
	return [NSString stringWithFormat:@"%@ [%@] %@", timestamp, queueThreadLabel, logMessage->logMsg];
}
- (void)didAddToLogger:(id <DDLogger>)logger
{
	OSAtomicIncrement32(&atomicLoggerCount);
}
- (void)willRemoveFromLogger:(id <DDLogger>)logger
{
	OSAtomicDecrement32(&atomicLoggerCount);
}
@end
