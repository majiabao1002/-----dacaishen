#import <Foundation/Foundation.h>
@interface MultipartMessageHeaderField : NSObject {
	NSString*						name;
    NSString*						value;
    NSMutableDictionary*			params;
}
@property (strong, readonly) NSString*		value;
@property (strong, readonly) NSDictionary*	params;
@property (strong, readonly) NSString*		name;
- (id) initWithData:(NSData*) data contentEncoding:(NSStringEncoding) encoding;
@end
