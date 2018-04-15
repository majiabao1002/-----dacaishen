#import <Foundation/Foundation.h>
enum {
    contentTransferEncoding_unknown,
    contentTransferEncoding_7bit,
    contentTransferEncoding_8bit,
    contentTransferEncoding_binary,
    contentTransferEncoding_base64,
    contentTransferEncoding_quotedPrintable,    
};
@interface MultipartMessageHeader : NSObject {
    NSMutableDictionary*                    fields;
    int                                     encoding;
    NSString*                               contentDispositionName;
}
@property (strong,readonly) NSDictionary* fields;
@property (readonly) int encoding;
- (id) initWithData:(NSData*) data formEncoding:(NSStringEncoding) encoding;
@end
