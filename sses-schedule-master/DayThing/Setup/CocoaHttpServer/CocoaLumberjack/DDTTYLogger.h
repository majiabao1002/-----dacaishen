#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIColor.h>
#else
#import <AppKit/NSColor.h>
#endif
#import "DDLog.h"
@interface DDTTYLogger : DDAbstractLogger <DDLogger>
{
	NSCalendar *calendar;
	NSUInteger calendarUnitFlags;
	NSString *appName;
	char *app;
	size_t appLen;
	NSString *processID;
	char *pid;
	size_t pidLen;
	BOOL colorsEnabled;
	NSMutableArray *colorProfilesArray;
	NSMutableDictionary *colorProfilesDict;
}
+ (DDTTYLogger *)sharedInstance;
@property (readwrite, assign) BOOL colorsEnabled;
#if TARGET_OS_IPHONE
- (void)setForegroundColor:(UIColor *)txtColor backgroundColor:(UIColor *)bgColor forFlag:(int)mask;
#else
- (void)setForegroundColor:(NSColor *)txtColor backgroundColor:(NSColor *)bgColor forFlag:(int)mask;
#endif
#if TARGET_OS_IPHONE
- (void)setForegroundColor:(UIColor *)txtColor backgroundColor:(UIColor *)bgColor forFlag:(int)mask context:(int)ctxt;
#else
- (void)setForegroundColor:(NSColor *)txtColor backgroundColor:(NSColor *)bgColor forFlag:(int)mask context:(int)ctxt;
#endif
#if TARGET_OS_IPHONE
- (void)setForegroundColor:(UIColor *)txtColor backgroundColor:(UIColor *)bgColor forTag:(id <NSCopying>)tag;
#else
- (void)setForegroundColor:(NSColor *)txtColor backgroundColor:(NSColor *)bgColor forTag:(id <NSCopying>)tag;
#endif
- (void)clearColorsForFlag:(int)mask;
- (void)clearColorsForFlag:(int)mask context:(int)context;
- (void)clearColorsForTag:(id <NSCopying>)tag;
- (void)clearColorsForAllFlags;
- (void)clearColorsForAllTags;
- (void)clearAllColors;
@end
