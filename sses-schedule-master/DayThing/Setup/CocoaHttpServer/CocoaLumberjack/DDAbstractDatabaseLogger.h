#import <Foundation/Foundation.h>
#import "DDLog.h"
@interface DDAbstractDatabaseLogger : DDAbstractLogger {
@protected
	NSUInteger saveThreshold;
	NSTimeInterval saveInterval;
	NSTimeInterval maxAge;
	NSTimeInterval deleteInterval;
	BOOL deleteOnEverySave;
	BOOL saveTimerSuspended;
	NSUInteger unsavedCount;
	dispatch_time_t unsavedTime;
	dispatch_source_t saveTimer;
	dispatch_time_t lastDeleteTime;
	dispatch_source_t deleteTimer;
}
@property (assign, readwrite) NSUInteger saveThreshold;
@property (assign, readwrite) NSTimeInterval saveInterval;
@property (assign, readwrite) NSTimeInterval maxAge;
@property (assign, readwrite) NSTimeInterval deleteInterval;
@property (assign, readwrite) BOOL deleteOnEverySave;
- (void)savePendingLogEntries;
- (void)deleteOldLogEntries;
@end
