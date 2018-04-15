#import "DDAbstractDatabaseLogger.h"
#import <math.h>
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
@interface DDAbstractDatabaseLogger ()
- (void)destroySaveTimer;
- (void)destroyDeleteTimer;
@end
#pragma mark -
@implementation DDAbstractDatabaseLogger
- (id)init
{
	if ((self = [super init]))
	{
        saveThreshold = 500;
		saveInterval = 60;           
		maxAge = (60 * 60 * 24 * 7); 
		deleteInterval = (60 * 5);   
	}
	return self;
}
- (void)dealloc
{
	[self destroySaveTimer];
	[self destroyDeleteTimer];
}
#pragma mark Override Me
- (BOOL)db_log:(DDLogMessage *)logMessage
{
	return NO;
}
- (void)db_save
{
}
- (void)db_delete
{
}
- (void)db_saveAndDelete
{
}
#pragma mark Private API
- (void)performSaveAndSuspendSaveTimer
{
	if (unsavedCount > 0)
	{
		if (deleteOnEverySave)
			[self db_saveAndDelete];
		else
			[self db_save];
	}
	unsavedCount = 0;
	unsavedTime = 0;
	if (saveTimer && !saveTimerSuspended)
	{
		dispatch_suspend(saveTimer);
		saveTimerSuspended = YES;
	}
}
- (void)performDelete
{
	if (maxAge > 0.0)
	{
		[self db_delete];
		lastDeleteTime = dispatch_time(DISPATCH_TIME_NOW, 0);
	}
}
#pragma mark Timers
- (void)destroySaveTimer
{
	if (saveTimer)
	{
		dispatch_source_cancel(saveTimer);
		if (saveTimerSuspended)
		{
			dispatch_resume(saveTimer);
			saveTimerSuspended = NO;
		}
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(saveTimer);
		#endif
		saveTimer = NULL;
	}
}
- (void)updateAndResumeSaveTimer
{
	if ((saveTimer != NULL) && (saveInterval > 0.0) && (unsavedTime > 0.0))
	{
		uint64_t interval = (uint64_t)(saveInterval * NSEC_PER_SEC);
		dispatch_time_t startTime = dispatch_time(unsavedTime, interval);
		dispatch_source_set_timer(saveTimer, startTime, interval, 1.0);
		if (saveTimerSuspended)
		{
			dispatch_resume(saveTimer);
			saveTimerSuspended = NO;
		}
	}
}
- (void)createSuspendedSaveTimer
{
	if ((saveTimer == NULL) && (saveInterval > 0.0))
	{
		saveTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, loggerQueue);
		dispatch_source_set_event_handler(saveTimer, ^{ @autoreleasepool {
			[self performSaveAndSuspendSaveTimer];
		}});
		saveTimerSuspended = YES;
	}
}
- (void)destroyDeleteTimer
{
	if (deleteTimer)
	{
		dispatch_source_cancel(deleteTimer);
		#if !OS_OBJECT_USE_OBJC
		dispatch_release(deleteTimer);
		#endif
		deleteTimer = NULL;
	}
}
- (void)updateDeleteTimer
{
	if ((deleteTimer != NULL) && (deleteInterval > 0.0) && (maxAge > 0.0))
	{
		uint64_t interval = (uint64_t)(deleteInterval * NSEC_PER_SEC);
		dispatch_time_t startTime;
		if (lastDeleteTime > 0)
			startTime = dispatch_time(lastDeleteTime, interval);
		else
			startTime = dispatch_time(DISPATCH_TIME_NOW, interval);
		dispatch_source_set_timer(deleteTimer, startTime, interval, 1.0);
	}
}
- (void)createAndStartDeleteTimer
{
	if ((deleteTimer == NULL) && (deleteInterval > 0.0) && (maxAge > 0.0))
	{
		deleteTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, loggerQueue);
        if (deleteTimer != NULL) {
            dispatch_source_set_event_handler(deleteTimer, ^{ @autoreleasepool {
                [self performDelete];
            }});
            [self updateDeleteTimer];
            dispatch_resume(deleteTimer);
        }
	}
}
#pragma mark Configuration
- (NSUInteger)saveThreshold
{
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	__block NSUInteger result;
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, ^{
			result = saveThreshold;
		});
	});
	return result;
}
- (void)setSaveThreshold:(NSUInteger)threshold
{
	dispatch_block_t block = ^{ @autoreleasepool {
		if (saveThreshold != threshold)
		{
			saveThreshold = threshold;
			if ((unsavedCount >= saveThreshold) && (saveThreshold > 0))
			{
				[self performSaveAndSuspendSaveTimer];
			}
		}
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
- (NSTimeInterval)saveInterval
{
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	__block NSTimeInterval result;
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, ^{
			result = saveInterval;
		});
	});
	return result;
}
- (void)setSaveInterval:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{ @autoreleasepool {
		if ( islessgreater(saveInterval, interval))
		{
			saveInterval = interval;
			if (saveInterval > 0.0)
			{
				if (saveTimer == NULL)
				{
					[self createSuspendedSaveTimer];
					[self updateAndResumeSaveTimer];
				}
				else
				{
					[self updateAndResumeSaveTimer];
				}
			}
			else if (saveTimer)
			{
				[self destroySaveTimer];
			}
		}
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
- (NSTimeInterval)maxAge
{
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	__block NSTimeInterval result;
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, ^{
			result = maxAge;
		});
	});
	return result;
}
- (void)setMaxAge:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{ @autoreleasepool {
		if ( islessgreater(maxAge, interval))
		{
			NSTimeInterval oldMaxAge = maxAge;
			NSTimeInterval newMaxAge = interval;
			maxAge = interval;
			BOOL shouldDeleteNow = NO;
			if (oldMaxAge > 0.0)
			{
				if (newMaxAge <= 0.0)
				{
					[self destroyDeleteTimer];
				}
				else if (oldMaxAge > newMaxAge)
				{
					shouldDeleteNow = YES;
				}
			}
			else if (newMaxAge > 0.0)
			{
				shouldDeleteNow = YES;
			}
			if (shouldDeleteNow)
			{
				[self performDelete];
				if (deleteTimer)
					[self updateDeleteTimer];
				else
					[self createAndStartDeleteTimer];
			}
		}
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
- (NSTimeInterval)deleteInterval
{
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	__block NSTimeInterval result;
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, ^{
			result = deleteInterval;
		});
	});
	return result;
}
- (void)setDeleteInterval:(NSTimeInterval)interval
{
	dispatch_block_t block = ^{ @autoreleasepool {
		if ( islessgreater(deleteInterval, interval))
		{
			deleteInterval = interval;
			if (deleteInterval > 0.0)
			{
				if (deleteTimer == NULL)
				{
					[self createAndStartDeleteTimer];
				}
				else
				{
					[self updateDeleteTimer];
				}
			}
			else if (deleteTimer)
			{
				[self destroyDeleteTimer];
			}
		}
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
- (BOOL)deleteOnEverySave
{
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	__block BOOL result;
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, ^{
			result = deleteOnEverySave;
		});
	});
	return result;
}
- (void)setDeleteOnEverySave:(BOOL)flag
{
	dispatch_block_t block = ^{
		deleteOnEverySave = flag;
	};
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
#pragma mark Public API
- (void)savePendingLogEntries
{
	dispatch_block_t block = ^{ @autoreleasepool {
		[self performSaveAndSuspendSaveTimer];
	}};
	if ([self isOnInternalLoggerQueue])
		block();
	else
		dispatch_async(loggerQueue, block);
}
- (void)deleteOldLogEntries
{
	dispatch_block_t block = ^{ @autoreleasepool {
		[self performDelete];
	}};
	if ([self isOnInternalLoggerQueue])
		block();
	else
		dispatch_async(loggerQueue, block);
}
#pragma mark DDLogger
- (void)didAddLogger
{
	[self createSuspendedSaveTimer];
	[self createAndStartDeleteTimer];
}
- (void)willRemoveLogger
{
	[self performSaveAndSuspendSaveTimer];
	[self destroySaveTimer];
	[self destroyDeleteTimer];
}
- (void)logMessage:(DDLogMessage *)logMessage
{
	if ([self db_log:logMessage])
	{
		BOOL firstUnsavedEntry = (++unsavedCount == 1);
		if ((unsavedCount >= saveThreshold) && (saveThreshold > 0))
		{
			[self performSaveAndSuspendSaveTimer];
		}
		else if (firstUnsavedEntry)
		{
			unsavedTime = dispatch_time(DISPATCH_TIME_NOW, 0);
			[self updateAndResumeSaveTimer];
		}
	}
}
- (void)flush
{
	[self performSaveAndSuspendSaveTimer];
}
@end
