#import <Foundation/Foundation.h>
@protocol HTTPResponse
- (UInt64)contentLength;
- (UInt64)offset;
- (void)setOffset:(UInt64)offset;
- (NSData *)readDataOfLength:(NSUInteger)length;
- (BOOL)isDone;
@optional
- (BOOL)delayResponseHeaders;
- (NSInteger)status;
- (NSDictionary *)httpHeaders;
- (BOOL)isChunked;
- (void)connectionDidClose;
@end
