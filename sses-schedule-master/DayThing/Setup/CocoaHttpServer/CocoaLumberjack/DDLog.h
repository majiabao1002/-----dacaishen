#import <Foundation/Foundation.h>
@class DDLogMessage;
@protocol DDLogger;
@protocol DDLogFormatter;
#define LOG_MACRO(isAsynchronous, lvl, flg, ctx, atag, fnct, frmt, ...) \
  [DDLog log:isAsynchronous                                             \
       level:lvl                                                        \
        flag:flg                                                        \
     context:ctx                                                        \
        file:__FILE__                                                   \
    function:fnct                                                       \
        line:__LINE__                                                   \
         tag:atag                                                       \
      format:(frmt), ##__VA_ARGS__]
#define LOG_OBJC_MACRO(async, lvl, flg, ctx, frmt, ...) \
             LOG_MACRO(async, lvl, flg, ctx, nil, sel_getName(_cmd), frmt, ##__VA_ARGS__)
#define LOG_C_MACRO(async, lvl, flg, ctx, frmt, ...) \
          LOG_MACRO(async, lvl, flg, ctx, nil, __FUNCTION__, frmt, ##__VA_ARGS__)
#define  SYNC_LOG_OBJC_MACRO(lvl, flg, ctx, frmt, ...) \
              LOG_OBJC_MACRO( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define ASYNC_LOG_OBJC_MACRO(lvl, flg, ctx, frmt, ...) \
              LOG_OBJC_MACRO(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define  SYNC_LOG_C_MACRO(lvl, flg, ctx, frmt, ...) \
              LOG_C_MACRO( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define ASYNC_LOG_C_MACRO(lvl, flg, ctx, frmt, ...) \
              LOG_C_MACRO(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define LOG_MAYBE(async, lvl, flg, ctx, fnct, frmt, ...) \
  do { if(lvl & flg) LOG_MACRO(async, lvl, flg, ctx, nil, fnct, frmt, ##__VA_ARGS__); } while(0)
#define LOG_OBJC_MAYBE(async, lvl, flg, ctx, frmt, ...) \
             LOG_MAYBE(async, lvl, flg, ctx, sel_getName(_cmd), frmt, ##__VA_ARGS__)
#define LOG_C_MAYBE(async, lvl, flg, ctx, frmt, ...) \
          LOG_MAYBE(async, lvl, flg, ctx, __FUNCTION__, frmt, ##__VA_ARGS__)
#define  SYNC_LOG_OBJC_MAYBE(lvl, flg, ctx, frmt, ...) \
              LOG_OBJC_MAYBE( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define ASYNC_LOG_OBJC_MAYBE(lvl, flg, ctx, frmt, ...) \
              LOG_OBJC_MAYBE(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define  SYNC_LOG_C_MAYBE(lvl, flg, ctx, frmt, ...) \
              LOG_C_MAYBE( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define ASYNC_LOG_C_MAYBE(lvl, flg, ctx, frmt, ...) \
              LOG_C_MAYBE(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)
#define LOG_OBJC_TAG_MACRO(async, lvl, flg, ctx, tag, frmt, ...) \
                 LOG_MACRO(async, lvl, flg, ctx, tag, sel_getName(_cmd), frmt, ##__VA_ARGS__)
#define LOG_C_TAG_MACRO(async, lvl, flg, ctx, tag, frmt, ...) \
              LOG_MACRO(async, lvl, flg, ctx, tag, __FUNCTION__, frmt, ##__VA_ARGS__)
#define LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, fnct, frmt, ...) \
  do { if(lvl & flg) LOG_MACRO(async, lvl, flg, ctx, tag, fnct, frmt, ##__VA_ARGS__); } while(0)
#define LOG_OBJC_TAG_MAYBE(async, lvl, flg, ctx, tag, frmt, ...) \
             LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, sel_getName(_cmd), frmt, ##__VA_ARGS__)
#define LOG_C_TAG_MAYBE(async, lvl, flg, ctx, tag, frmt, ...) \
          LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, __FUNCTION__, frmt, ##__VA_ARGS__)
#define LOG_FLAG_ERROR    (1 << 0)  
#define LOG_FLAG_WARN     (1 << 1)  
#define LOG_FLAG_INFO     (1 << 2)  
#define LOG_FLAG_VERBOSE  (1 << 3)  
#define LOG_LEVEL_OFF     0
#define LOG_LEVEL_ERROR   (LOG_FLAG_ERROR)                                                    
#define LOG_LEVEL_WARN    (LOG_FLAG_ERROR | LOG_FLAG_WARN)                                    
#define LOG_LEVEL_INFO    (LOG_FLAG_ERROR | LOG_FLAG_WARN | LOG_FLAG_INFO)                    
#define LOG_LEVEL_VERBOSE (LOG_FLAG_ERROR | LOG_FLAG_WARN | LOG_FLAG_INFO | LOG_FLAG_VERBOSE) 
#define LOG_ERROR   (ddLogLevel & LOG_FLAG_ERROR)
#define LOG_WARN    (ddLogLevel & LOG_FLAG_WARN)
#define LOG_INFO    (ddLogLevel & LOG_FLAG_INFO)
#define LOG_VERBOSE (ddLogLevel & LOG_FLAG_VERBOSE)
#define LOG_ASYNC_ENABLED YES
#define LOG_ASYNC_ERROR   ( NO && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_WARN    (YES && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_INFO    (YES && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_VERBOSE (YES && LOG_ASYNC_ENABLED)
#define DDLogError(frmt, ...)   LOG_OBJC_MAYBE(LOG_ASYNC_ERROR,   ddLogLevel, LOG_FLAG_ERROR,   0, frmt, ##__VA_ARGS__)
#define DDLogWarn(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_WARN,    ddLogLevel, LOG_FLAG_WARN,    0, frmt, ##__VA_ARGS__)
#define DDLogInfo(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_INFO,    ddLogLevel, LOG_FLAG_INFO,    0, frmt, ##__VA_ARGS__)
#define DDLogVerbose(frmt, ...) LOG_OBJC_MAYBE(LOG_ASYNC_VERBOSE, ddLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)
#define DDLogCError(frmt, ...)   LOG_C_MAYBE(LOG_ASYNC_ERROR,   ddLogLevel, LOG_FLAG_ERROR,   0, frmt, ##__VA_ARGS__)
#define DDLogCWarn(frmt, ...)    LOG_C_MAYBE(LOG_ASYNC_WARN,    ddLogLevel, LOG_FLAG_WARN,    0, frmt, ##__VA_ARGS__)
#define DDLogCInfo(frmt, ...)    LOG_C_MAYBE(LOG_ASYNC_INFO,    ddLogLevel, LOG_FLAG_INFO,    0, frmt, ##__VA_ARGS__)
#define DDLogCVerbose(frmt, ...) LOG_C_MAYBE(LOG_ASYNC_VERBOSE, ddLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)
NSString *DDExtractFileNameWithoutExtension(const char *filePath, BOOL copy);
#define THIS_FILE (DDExtractFileNameWithoutExtension(__FILE__, NO))
#define THIS_METHOD NSStringFromSelector(_cmd)
#pragma mark -
@interface DDLog : NSObject
+ (dispatch_queue_t)loggingQueue;
+ (void)log:(BOOL)synchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format, ... __attribute__ ((format (__NSString__, 9, 10)));
+ (void)log:(BOOL)asynchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format
       args:(va_list)argList;
+ (void)flushLog;
+ (void)addLogger:(id <DDLogger>)logger;
+ (void)removeLogger:(id <DDLogger>)logger;
+ (void)removeAllLoggers;
+ (NSArray *)registeredClasses;
+ (NSArray *)registeredClassNames;
+ (int)logLevelForClass:(Class)aClass;
+ (int)logLevelForClassWithName:(NSString *)aClassName;
+ (void)setLogLevel:(int)logLevel forClass:(Class)aClass;
+ (void)setLogLevel:(int)logLevel forClassWithName:(NSString *)aClassName;
@end
#pragma mark -
@protocol DDLogger <NSObject>
@required
- (void)logMessage:(DDLogMessage *)logMessage;
- (id <DDLogFormatter>)logFormatter;
- (void)setLogFormatter:(id <DDLogFormatter>)formatter;
@optional
- (void)didAddLogger;
- (void)willRemoveLogger;
- (void)flush;
- (dispatch_queue_t)loggerQueue;
- (NSString *)loggerName;
@end
#pragma mark -
@protocol DDLogFormatter <NSObject>
@required
- (NSString *)formatLogMessage:(DDLogMessage *)logMessage;
@optional
- (void)didAddToLogger:(id <DDLogger>)logger;
- (void)willRemoveFromLogger:(id <DDLogger>)logger;
@end
#pragma mark -
@protocol DDRegisteredDynamicLogging
+ (int)ddLogLevel;
+ (void)ddSetLogLevel:(int)logLevel;
@end
#pragma mark -
enum {
	DDLogMessageCopyFile     = 1 << 0,
	DDLogMessageCopyFunction = 1 << 1
};
typedef int DDLogMessageOptions;
@interface DDLogMessage : NSObject
{
@public
	int logLevel;
	int logFlag;
	int logContext;
	NSString *logMsg;
	NSDate *timestamp;
	char *file;
	char *function;
	int lineNumber;
	mach_port_t machThreadID;
    char *queueLabel;
	NSString *threadName;
	id tag;
	DDLogMessageOptions options;
}
- (id)initWithLogMsg:(NSString *)logMsg
               level:(int)logLevel
                flag:(int)logFlag
             context:(int)logContext
                file:(const char *)file
            function:(const char *)function
                line:(int)line
                 tag:(id)tag
             options:(DDLogMessageOptions)optionsMask;
- (NSString *)threadID;
- (NSString *)fileName;
- (NSString *)methodName;
@end
#pragma mark -
@interface DDAbstractLogger : NSObject <DDLogger>
{
	id <DDLogFormatter> formatter;
	dispatch_queue_t loggerQueue;
}
- (id <DDLogFormatter>)logFormatter;
- (void)setLogFormatter:(id <DDLogFormatter>)formatter;
- (BOOL)isOnGlobalLoggingQueue;
- (BOOL)isOnInternalLoggerQueue;
@end
