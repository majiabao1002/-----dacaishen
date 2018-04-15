#import <Foundation/Foundation.h>
#import "HTTPResponse.h"
#import "HTTPAsyncFileResponse.h"
@interface HTTPDynamicFileResponse : HTTPAsyncFileResponse
{
	NSData *separator;
	NSDictionary *replacementDict;
}
- (id)initWithFilePath:(NSString *)filePath
         forConnection:(HTTPConnection *)connection
             separator:(NSString *)separatorStr
 replacementDictionary:(NSDictionary *)dictionary;
@end
