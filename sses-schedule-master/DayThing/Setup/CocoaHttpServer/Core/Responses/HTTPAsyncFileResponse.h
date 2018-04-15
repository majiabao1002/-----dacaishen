#import <Foundation/Foundation.h>
#import "HTTPResponse.h"
@class HTTPConnection;
@interface HTTPAsyncFileResponse : NSObject <HTTPResponse>
{	
	HTTPConnection *connection;
	NSString *filePath;
	UInt64 fileLength;
	UInt64 fileOffset;  
	UInt64 readOffset;  
	BOOL aborted;
	NSData *data;
	int fileFD;
	void *readBuffer;
	NSUInteger readBufferSize;     
	NSUInteger readBufferOffset;   
	NSUInteger readRequestLength;
	dispatch_queue_t readQueue;
	dispatch_source_t readSource;
	BOOL readSourceSuspended;
}
- (id)initWithFilePath:(NSString *)filePath forConnection:(HTTPConnection *)connection;
- (NSString *)filePath;
@end
