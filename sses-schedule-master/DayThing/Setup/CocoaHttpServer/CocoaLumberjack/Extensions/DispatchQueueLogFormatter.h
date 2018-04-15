#import <Foundation/Foundation.h>
#import <libkern/OSAtomic.h>
#import "DDLog.h"
@interface DispatchQueueLogFormatter : NSObject <DDLogFormatter> {
@protected
	NSString *dateFormatString;
}
- (id)init;
@property (assign) NSUInteger minQueueLength;
@property (assign) NSUInteger maxQueueLength;
- (NSString *)replacementStringForQueueLabel:(NSString *)longLabel;
- (void)setReplacementString:(NSString *)shortLabel forQueueLabel:(NSString *)longLabel;
@end
