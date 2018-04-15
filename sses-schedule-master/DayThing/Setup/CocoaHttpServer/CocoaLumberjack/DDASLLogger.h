#import <Foundation/Foundation.h>
#import <asl.h>
#import "DDLog.h"
@interface DDASLLogger : DDAbstractLogger <DDLogger>
{
	aslclient client;
}
+ (DDASLLogger *)sharedInstance;
@end
