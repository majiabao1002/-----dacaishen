#import <Foundation/Foundation.h>
#import "DDLog.h"
@class ContextFilterLogFormatter;
@interface ContextWhitelistFilterLogFormatter : NSObject <DDLogFormatter>
- (id)init;
- (void)addToWhitelist:(int)loggingContext;
- (void)removeFromWhitelist:(int)loggingContext;
- (NSArray *)whitelist;
- (BOOL)isOnWhitelist:(int)loggingContext;
@end
#pragma mark -
@interface ContextBlacklistFilterLogFormatter : NSObject <DDLogFormatter>
- (id)init;
- (void)addToBlacklist:(int)loggingContext;
- (void)removeFromBlacklist:(int)loggingContext;
- (NSArray *)blacklist;
- (BOOL)isOnBlacklist:(int)loggingContext;
@end
