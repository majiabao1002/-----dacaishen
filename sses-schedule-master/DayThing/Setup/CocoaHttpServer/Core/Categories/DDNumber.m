#import "DDNumber.h"
@implementation NSNumber (DDNumber)
+ (BOOL)parseString:(NSString *)str intoSInt64:(SInt64 *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	errno = 0;
	*pNum = strtoll([str UTF8String], NULL, 10);
	if(errno != 0)
		return NO;
	else
		return YES;
}
+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	errno = 0;
	*pNum = strtoull([str UTF8String], NULL, 10);
	if(errno != 0)
		return NO;
	else
		return YES;
}
+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	errno = 0;
	*pNum = strtol([str UTF8String], NULL, 10);
	if(errno != 0)
		return NO;
	else
		return YES;
}
+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	errno = 0;
	*pNum = strtoul([str UTF8String], NULL, 10);
	if(errno != 0)
		return NO;
	else
		return YES;
}
@end
