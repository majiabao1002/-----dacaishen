#import <Foundation/Foundation.h>
#import "DDLog.h"
@class DDLogFileInfo;
#define DEFAULT_LOG_MAX_FILE_SIZE     (1024 * 1024)   
#define DEFAULT_LOG_ROLLING_FREQUENCY (60 * 60 * 24)  
#define DEFAULT_LOG_MAX_NUM_LOG_FILES (5)             
#pragma mark -
@protocol DDLogFileManager <NSObject>
@required
@property (readwrite, assign) NSUInteger maximumNumberOfLogFiles;
- (NSString *)logsDirectory;
- (NSArray *)unsortedLogFilePaths;
- (NSArray *)unsortedLogFileNames;
- (NSArray *)unsortedLogFileInfos;
- (NSArray *)sortedLogFilePaths;
- (NSArray *)sortedLogFileNames;
- (NSArray *)sortedLogFileInfos;
- (NSString *)createNewLogFile;
@optional
- (void)didArchiveLogFile:(NSString *)logFilePath;
- (void)didRollAndArchiveLogFile:(NSString *)logFilePath;
@end
#pragma mark -
@interface DDLogFileManagerDefault : NSObject <DDLogFileManager>
{
	NSUInteger maximumNumberOfLogFiles;
	NSString *_logsDirectory;
}
- (id)init;
- (id)initWithLogsDirectory:(NSString *)logsDirectory;
@end
#pragma mark -
@interface DDLogFileFormatterDefault : NSObject <DDLogFormatter>
{
	NSDateFormatter *dateFormatter;
}
- (id)init;
- (id)initWithDateFormatter:(NSDateFormatter *)dateFormatter;
@end
#pragma mark -
@interface DDFileLogger : DDAbstractLogger <DDLogger>
{
	__strong id <DDLogFileManager> logFileManager;
	DDLogFileInfo *currentLogFileInfo;
	NSFileHandle *currentLogFileHandle;
	dispatch_source_t rollingTimer;
	unsigned long long maximumFileSize;
	NSTimeInterval rollingFrequency;
}
- (id)init;
- (id)initWithLogFileManager:(id <DDLogFileManager>)logFileManager;
@property (readwrite, assign) unsigned long long maximumFileSize;
@property (readwrite, assign) NSTimeInterval rollingFrequency;
@property (strong, nonatomic, readonly) id <DDLogFileManager> logFileManager;
- (void)rollLogFile;
@end
#pragma mark -
@interface DDLogFileInfo : NSObject
{
	__strong NSString *filePath;
	__strong NSString *fileName;
	__strong NSDictionary *fileAttributes;
	__strong NSDate *creationDate;
	__strong NSDate *modificationDate;
	unsigned long long fileSize;
}
@property (strong, nonatomic, readonly) NSString *filePath;
@property (strong, nonatomic, readonly) NSString *fileName;
@property (strong, nonatomic, readonly) NSDictionary *fileAttributes;
@property (strong, nonatomic, readonly) NSDate *creationDate;
@property (strong, nonatomic, readonly) NSDate *modificationDate;
@property (nonatomic, readonly) unsigned long long fileSize;
@property (nonatomic, readonly) NSTimeInterval age;
@property (nonatomic, readwrite) BOOL isArchived;
+ (id)logFileWithPath:(NSString *)filePath;
- (id)initWithFilePath:(NSString *)filePath;
- (void)reset;
- (void)renameFile:(NSString *)newFileName;
#if TARGET_IPHONE_SIMULATOR
- (BOOL)hasExtensionAttributeWithName:(NSString *)attrName;
- (void)addExtensionAttributeWithName:(NSString *)attrName;
- (void)removeExtensionAttributeWithName:(NSString *)attrName;
#else
- (BOOL)hasExtendedAttributeWithName:(NSString *)attrName;
- (void)addExtendedAttributeWithName:(NSString *)attrName;
- (void)removeExtendedAttributeWithName:(NSString *)attrName;
#endif
- (NSComparisonResult)reverseCompareByCreationDate:(DDLogFileInfo *)another;
- (NSComparisonResult)reverseCompareByModificationDate:(DDLogFileInfo *)another;
@end
