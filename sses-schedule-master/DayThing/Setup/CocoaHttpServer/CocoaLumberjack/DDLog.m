#import "DDLog.h"
#import <pthread.h>
#import <objc/runtime.h>
#import <mach/mach_host.h>
#import <mach/host_info.h>
#import <libkern/OSAtomic.h>
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
#define DD_DEBUG NO
#define NSLogDebug(frmt, ...) do{ if(DD_DEBUG) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define LOG_MAX_QUEUE_SIZE 1000 
static void *const GlobalLoggingQueueIdentityKey = (void *)&GlobalLoggingQueueIdentityKey;
@interface DDLoggerNode : NSObject {
@public 
	id <DDLogger> logger;	
	dispatch_queue_t loggerQueue;
}
+ (DDLoggerNode *)nodeWithLogger:(id <DDLogger>)logger loggerQueue:(dispatch_queue_t)loggerQueue;
@end
@interface DDLog (PrivateAPI)
+ (void)lt_addLogger:(id <DDLogger>)logger;
+ (void)lt_removeLogger:(id <DDLogger>)logger;
+ (void)lt_removeAllLoggers;
+ (void)lt_log:(DDLogMessage *)logMessage;
+ (void)lt_flush;
@end
#pragma mark -
@implementation DDLog
static NSMutableArray *loggers;
static dispatch_queue_t loggingQueue;
static dispatch_group_t loggingGroup;
static dispatch_semaphore_t queueSemaphore;
static unsigned int numProcessors;
+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		loggers = [[NSMutableArray alloc] initWithCapacity:4];
		NSLogDebug(@"DDLog: Using grand central dispatch");
		loggingQueue = dispatch_queue_create("cocoa.lumberjack", NULL);
		loggingGroup = dispatch_group_create();
		void *nonNullValue = GlobalLoggingQueueIdentityKey; 
		dispatch_queue_set_specific(loggingQueue, GlobalLoggingQueueIdentityKey, nonNullValue, NULL);
		queueSemaphore = dispatch_semaphore_create(LOG_MAX_QUEUE_SIZE);
		host_basic_info_data_t hostInfo;
		mach_msg_type_number_t infoCount;
		infoCount = HOST_BASIC_INFO_COUNT;
		host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount);
		unsigned int result = (unsigned int)(hostInfo.max_cpus);
		unsigned int one    = (unsigned int)(1);
		numProcessors = MAX(result, one);
		NSLogDebug(@"DDLog: numProcessors = %u", numProcessors);
	#if TARGET_OS_IPHONE
		NSString *notificationName = @"UIApplicationWillTerminateNotification";
	#else
		NSString *notificationName = @"NSApplicationWillTerminateNotification";
	#endif
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(applicationWillTerminate:)
		                                             name:notificationName
		                                           object:nil];
	}
}
+ (dispatch_queue_t)loggingQueue
{
	return loggingQueue;
}
#pragma mark Notifications
+ (void)applicationWillTerminate:(NSNotification *)notification
{
	[self flushLog];
}
#pragma mark Logger Management
+ (void)addLogger:(id <DDLogger>)logger
{
	if (logger == nil) return;
	dispatch_async(loggingQueue, ^{ @autoreleasepool {
		[self lt_addLogger:logger];
	}});
}
+ (void)removeLogger:(id <DDLogger>)logger
{
	if (logger == nil) return;
	dispatch_async(loggingQueue, ^{ @autoreleasepool {
		[self lt_removeLogger:logger];
	}});
}
+ (void)removeAllLoggers
{
	dispatch_async(loggingQueue, ^{ @autoreleasepool {
		[self lt_removeAllLoggers];
	}});
}
#pragma mark Master Logging
+ (void)queueLogMessage:(DDLogMessage *)logMessage asynchronously:(BOOL)asyncFlag
{
	dispatch_semaphore_wait(queueSemaphore, DISPATCH_TIME_FOREVER);
	dispatch_block_t logBlock = ^{ @autoreleasepool {
		[self lt_log:logMessage];
	}};
	if (asyncFlag)
		dispatch_async(loggingQueue, logBlock);
	else
		dispatch_sync(loggingQueue, logBlock);
}
+ (void)log:(BOOL)asynchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format, ...
{
	va_list args;
	if (format)
	{
		va_start(args, format);
		NSString *logMsg = [[NSString alloc] initWithFormat:format arguments:args];
		DDLogMessage *logMessage = [[DDLogMessage alloc] initWithLogMsg:logMsg
		                                                          level:level
		                                                           flag:flag
		                                                        context:context
		                                                           file:file
		                                                       function:function
		                                                           line:line
		                                                            tag:tag
		                                                        options:0];
		[self queueLogMessage:logMessage asynchronously:asynchronous];
		va_end(args);
	}
}
+ (void)log:(BOOL)asynchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format
       args:(va_list)args
{
	if (format)
	{
		NSString *logMsg = [[NSString alloc] initWithFormat:format arguments:args];
		DDLogMessage *logMessage = [[DDLogMessage alloc] initWithLogMsg:logMsg
		                                                          level:level
		                                                           flag:flag
		                                                        context:context
		                                                           file:file
		                                                       function:function
		                                                           line:line
		                                                            tag:tag
		                                                        options:0];
		[self queueLogMessage:logMessage asynchronously:asynchronous];
	}
}
+ (void)flushLog
{
	dispatch_sync(loggingQueue, ^{ @autoreleasepool {
		[self lt_flush];
	}});
}
#pragma mark Registered Dynamic Logging
+ (BOOL)isRegisteredClass:(Class)class
{
	SEL getterSel = @selector(ddLogLevel);
	SEL setterSel = @selector(ddSetLogLevel:);
#if TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
	BOOL result = NO;
	unsigned int methodCount, i;
	Method *methodList = class_copyMethodList(object_getClass(class), &methodCount);
	if (methodList != NULL)
	{
		BOOL getterFound = NO;
		BOOL setterFound = NO;
		for (i = 0; i < methodCount; ++i)
		{
			SEL currentSel = method_getName(methodList[i]);
			if (currentSel == getterSel)
			{
				getterFound = YES;
			}
			else if (currentSel == setterSel)
			{
				setterFound = YES;
			}
			if (getterFound && setterFound)
			{
				result = YES;
				break;
			}
		}
		free(methodList);
	}
	return result;
#else
	Method getter = class_getClassMethod(class, getterSel);
	Method setter = class_getClassMethod(class, setterSel);
	if ((getter != NULL) && (setter != NULL))
	{
		return YES;
	}
	return NO;
#endif
}
+ (NSArray *)registeredClasses
{
	int numClasses, i;
	numClasses = objc_getClassList(NULL, 0);
	Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
	numClasses = objc_getClassList(classes, numClasses);
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:numClasses];
	for (i = 0; i < numClasses; i++)
	{
		Class class = classes[i];
		if ([self isRegisteredClass:class])
		{
			[result addObject:class];
		}
	}
	free(classes);
	return result;
}
+ (NSArray *)registeredClassNames
{
	NSArray *registeredClasses = [self registeredClasses];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[registeredClasses count]];
	for (Class class in registeredClasses)
	{
		[result addObject:NSStringFromClass(class)];
	}
	return result;
}
+ (int)logLevelForClass:(Class)aClass
{
	if ([self isRegisteredClass:aClass])
	{
		return [aClass ddLogLevel];
	}
	return -1;
}
+ (int)logLevelForClassWithName:(NSString *)aClassName
{
	Class aClass = NSClassFromString(aClassName);
	return [self logLevelForClass:aClass];
}
+ (void)setLogLevel:(int)logLevel forClass:(Class)aClass
{
	if ([self isRegisteredClass:aClass])
	{
		[aClass ddSetLogLevel:logLevel];
	}
}
+ (void)setLogLevel:(int)logLevel forClassWithName:(NSString *)aClassName
{
	Class aClass = NSClassFromString(aClassName);
	[self setLogLevel:logLevel forClass:aClass];
}
#pragma mark Logging Thread
+ (void)lt_addLogger:(id <DDLogger>)logger
{
	dispatch_queue_t loggerQueue = NULL;
	if ([logger respondsToSelector:@selector(loggerQueue)])
	{
		loggerQueue = [logger loggerQueue];
	}
	if (loggerQueue == nil)
	{
		const char *loggerQueueName = NULL;
		if ([logger respondsToSelector:@selector(loggerName)])
		{
			loggerQueueName = [[logger loggerName] UTF8String];
		}
		loggerQueue = dispatch_queue_create(loggerQueueName, NULL);
	}
	DDLoggerNode *loggerNode = [DDLoggerNode nodeWithLogger:logger loggerQueue:loggerQueue];
	[loggers addObject:loggerNode];
	if ([logger respondsToSelector:@selector(didAddLogger)])
	{
		dispatch_async(loggerNode->loggerQueue, ^{ @autoreleasepool {
			[logger didAddLogger];
		}});
	}
}
+ (void)lt_removeLogger:(id <DDLogger>)logger
{
	DDLoggerNode *loggerNode = nil;
	for (DDLoggerNode *node in loggers)
	{
		if (node->logger == logger)
		{
			loggerNode = node;
			break;
		}
	}
	if (loggerNode == nil)
	{
		NSLogDebug(@"DDLog: Request to remove logger which wasn't added");
		return;
	}
	if ([logger respondsToSelector:@selector(willRemoveLogger)])
	{
		dispatch_async(loggerNode->loggerQueue, ^{ @autoreleasepool {
			[logger willRemoveLogger];
		}});
	}
	[loggers removeObject:loggerNode];
}
+ (void)lt_removeAllLoggers
{
	for (DDLoggerNode *loggerNode in loggers)
	{
		if ([loggerNode->logger respondsToSelector:@selector(willRemoveLogger)])
		{
			dispatch_async(loggerNode->loggerQueue, ^{ @autoreleasepool {
				[loggerNode->logger willRemoveLogger];
			}});
		}
	}
	[loggers removeAllObjects];
}
+ (void)lt_log:(DDLogMessage *)logMessage
{
	if (numProcessors > 1)
	{
		for (DDLoggerNode *loggerNode in loggers)
		{
			dispatch_group_async(loggingGroup, loggerNode->loggerQueue, ^{ @autoreleasepool {
				[loggerNode->logger logMessage:logMessage];
			}});
		}
		dispatch_group_wait(loggingGroup, DISPATCH_TIME_FOREVER);
	}
	else
	{
		for (DDLoggerNode *loggerNode in loggers)
		{
			dispatch_sync(loggerNode->loggerQueue, ^{ @autoreleasepool {
				[loggerNode->logger logMessage:logMessage];
			}});
		}
	}
	dispatch_semaphore_signal(queueSemaphore);
}
+ (void)lt_flush
{
	for (DDLoggerNode *loggerNode in loggers)
	{
		if ([loggerNode->logger respondsToSelector:@selector(flush)])
		{
			dispatch_group_async(loggingGroup, loggerNode->loggerQueue, ^{ @autoreleasepool {
				[loggerNode->logger flush];
			}});
		}
	}
	dispatch_group_wait(loggingGroup, DISPATCH_TIME_FOREVER);
}
#pragma mark Utilities
NSString *DDExtractFileNameWithoutExtension(const char *filePath, BOOL copy)
{
	if (filePath == NULL) return nil;
	char *lastSlash = NULL;
	char *lastDot = NULL;
	char *p = (char *)filePath;
	while (*p != '\0')
	{
		if (*p == '/')
			lastSlash = p;
		else if (*p == '.')
			lastDot = p;
		p++;
	}
	char *subStr;
	NSUInteger subLen;
	if (lastSlash)
	{
		if (lastDot)
		{
			subStr = lastSlash + 1;
			subLen = lastDot - subStr;
		}
		else
		{
			subStr = lastSlash + 1;
			subLen = p - subStr;
		}
	}
	else
	{
		if (lastDot)
		{
			subStr = (char *)filePath;
			subLen = lastDot - subStr;
		}
		else
		{
			subStr = (char *)filePath;
			subLen = p - subStr;
		}
	}
	if (copy)
	{
		return [[NSString alloc] initWithBytes:subStr
		                                length:subLen
		                              encoding:NSUTF8StringEncoding];
	}
	else
	{
		return [[NSString alloc] initWithBytesNoCopy:subStr
		                                      length:subLen
		                                    encoding:NSUTF8StringEncoding
		                                freeWhenDone:NO];
	}
}
@end
#pragma mark -
@implementation DDLoggerNode
- (id)initWithLogger:(id <DDLogger>)aLogger loggerQueue:(dispatch_queue_t)aLoggerQueue
{
	if ((self = [super init]))
	{
		logger = aLogger;
		if (aLoggerQueue) {
			loggerQueue = aLoggerQueue;
			#if !OS_OBJECT_USE_OBJC
			dispatch_retain(loggerQueue);
			#endif
		}
	}
	return self;
}
+ (DDLoggerNode *)nodeWithLogger:(id <DDLogger>)logger loggerQueue:(dispatch_queue_t)loggerQueue
{
	return [[DDLoggerNode alloc] initWithLogger:logger loggerQueue:loggerQueue];
}
- (void)dealloc
{
	#if !OS_OBJECT_USE_OBJC
	if (loggerQueue) dispatch_release(loggerQueue);
	#endif
}
@end
#pragma mark -
@implementation DDLogMessage
static char *dd_str_copy(const char *str)
{
	if (str == NULL) return NULL;
	size_t length = strlen(str);
	char * result = malloc(length + 1);
	strncpy(result, str, length);
	result[length] = 0;
	return result;
}
- (id)initWithLogMsg:(NSString *)msg
               level:(int)level
                flag:(int)flag
             context:(int)context
                file:(const char *)aFile
            function:(const char *)aFunction
                line:(int)line
                 tag:(id)aTag
             options:(DDLogMessageOptions)optionsMask
{
	if ((self = [super init]))
	{
		logMsg     = msg;
		logLevel   = level;
		logFlag    = flag;
		logContext = context;
		lineNumber = line;
		tag        = aTag;
		options    = optionsMask;
		if (options & DDLogMessageCopyFile)
			file = dd_str_copy(aFile);
		else
			file = (char *)aFile;
		if (options & DDLogMessageCopyFunction)
			function = dd_str_copy(aFunction);
		else
			function = (char *)aFunction;
		timestamp = [[NSDate alloc] init];
		machThreadID = pthread_mach_thread_np(pthread_self());
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		dispatch_queue_t currentQueue = dispatch_get_current_queue();
		#pragma clang diagnostic pop
		queueLabel = dd_str_copy(dispatch_queue_get_label(currentQueue));
		threadName = [[NSThread currentThread] name];
	}
	return self;
}
- (NSString *)threadID
{
	return [[NSString alloc] initWithFormat:@"%x", machThreadID];
}
- (NSString *)fileName
{
	return DDExtractFileNameWithoutExtension(file, NO);
}
- (NSString *)methodName
{
	if (function == NULL)
		return nil;
	else
		return [[NSString alloc] initWithUTF8String:function];
}
- (void)dealloc
{
	if (file && (options & DDLogMessageCopyFile))
		free(file);
	if (function && (options & DDLogMessageCopyFunction))
		free(function);
	if (queueLabel)
		free(queueLabel);
}
@end
#pragma mark -
@implementation DDAbstractLogger
- (id)init
{
	if ((self = [super init]))
	{
		const char *loggerQueueName = NULL;
		if ([self respondsToSelector:@selector(loggerName)])
		{
			loggerQueueName = [[self loggerName] UTF8String];
		}
		loggerQueue = dispatch_queue_create(loggerQueueName, NULL);
		void *key = (__bridge void *)self;
		void *nonNullValue = (__bridge void *)self;
		dispatch_queue_set_specific(loggerQueue, key, nonNullValue, NULL);
	}
	return self;
}
- (void)dealloc
{
	#if !OS_OBJECT_USE_OBJC
	if (loggerQueue) dispatch_release(loggerQueue);
	#endif
}
- (void)logMessage:(DDLogMessage *)logMessage
{
}
- (id <DDLogFormatter>)logFormatter
{
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	__block id <DDLogFormatter> result;
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, ^{
			result = formatter;
		});
	});
	return result;
}
- (void)setLogFormatter:(id <DDLogFormatter>)logFormatter
{
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	dispatch_block_t block = ^{ @autoreleasepool {
		if (formatter != logFormatter)
		{
			if ([formatter respondsToSelector:@selector(willRemoveFromLogger:)]) {
				[formatter willRemoveFromLogger:self];
			}
			formatter = logFormatter;
			if ([formatter respondsToSelector:@selector(didAddToLogger:)]) {
				[formatter didAddToLogger:self];
			}
		}
	}};
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	dispatch_async(globalLoggingQueue, ^{
		dispatch_async(loggerQueue, block);
	});
}
- (dispatch_queue_t)loggerQueue
{
	return loggerQueue;
}
- (NSString *)loggerName
{
	return NSStringFromClass([self class]);
}
- (BOOL)isOnGlobalLoggingQueue
{
	return (dispatch_get_specific(GlobalLoggingQueueIdentityKey) != NULL);
}
- (BOOL)isOnInternalLoggerQueue
{
	void *key = (__bridge void *)self;
	return (dispatch_get_specific(key) != NULL);
}
@end
