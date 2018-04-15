#import "HTTPAuthenticationRequest.h"
#import "HTTPMessage.h"
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
@interface HTTPAuthenticationRequest (PrivateAPI)
- (NSString *)quotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header;
- (NSString *)nonquotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header;
@end
@implementation HTTPAuthenticationRequest
- (id)initWithRequest:(HTTPMessage *)request
{
	if ((self = [super init]))
	{
		NSString *authInfo = [request headerField:@"Authorization"];
		isBasic = NO;
		if ([authInfo length] >= 6)
		{
			isBasic = [[authInfo substringToIndex:6] caseInsensitiveCompare:@"Basic "] == NSOrderedSame;
		}
		isDigest = NO;
		if ([authInfo length] >= 7)
		{
			isDigest = [[authInfo substringToIndex:7] caseInsensitiveCompare:@"Digest "] == NSOrderedSame;
		}
		if (isBasic)
		{
			NSMutableString *temp = [[authInfo substringFromIndex:6] mutableCopy];
			CFStringTrimWhitespace((__bridge CFMutableStringRef)temp);
			base64Credentials = [temp copy];
		}
		if (isDigest)
		{
			username = [self quotedSubHeaderFieldValue:@"username" fromHeaderFieldValue:authInfo];
			realm    = [self quotedSubHeaderFieldValue:@"realm" fromHeaderFieldValue:authInfo];
			nonce    = [self quotedSubHeaderFieldValue:@"nonce" fromHeaderFieldValue:authInfo];
			uri      = [self quotedSubHeaderFieldValue:@"uri" fromHeaderFieldValue:authInfo];
			qop      = [self nonquotedSubHeaderFieldValue:@"qop" fromHeaderFieldValue:authInfo];
			if(qop && ([qop characterAtIndex:0] == '"'))
			{
				qop  = [self quotedSubHeaderFieldValue:@"qop" fromHeaderFieldValue:authInfo];
			}
			nc       = [self nonquotedSubHeaderFieldValue:@"nc" fromHeaderFieldValue:authInfo];
			cnonce   = [self quotedSubHeaderFieldValue:@"cnonce" fromHeaderFieldValue:authInfo];
			response = [self quotedSubHeaderFieldValue:@"response" fromHeaderFieldValue:authInfo];
		}
	}
	return self;
}
#pragma mark Accessors:
- (BOOL)isBasic {
	return isBasic;
}
- (BOOL)isDigest {
	return isDigest;
}
- (NSString *)base64Credentials {
	return base64Credentials;
}
- (NSString *)username {
	return username;
}
- (NSString *)realm {
	return realm;
}
- (NSString *)nonce {
	return nonce;
}
- (NSString *)uri {
	return uri;
}
- (NSString *)qop {
	return qop;
}
- (NSString *)nc {
	return nc;
}
- (NSString *)cnonce {
	return cnonce;
}
- (NSString *)response {
	return response;
}
#pragma mark Private API:
- (NSString *)quotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header
{
	NSRange startRange = [header rangeOfString:[NSString stringWithFormat:@"%@=\"", param]];
	if(startRange.location == NSNotFound)
	{
		return nil;
	}
	NSUInteger postStartRangeLocation = startRange.location + startRange.length;
	NSUInteger postStartRangeLength = [header length] - postStartRangeLocation;
	NSRange postStartRange = NSMakeRange(postStartRangeLocation, postStartRangeLength);
	NSRange endRange = [header rangeOfString:@"\"" options:0 range:postStartRange];
	if(endRange.location == NSNotFound)
	{
		return nil;
	}
	NSRange subHeaderRange = NSMakeRange(postStartRangeLocation, endRange.location - postStartRangeLocation);
	return [header substringWithRange:subHeaderRange];
}
- (NSString *)nonquotedSubHeaderFieldValue:(NSString *)param fromHeaderFieldValue:(NSString *)header
{
	NSRange startRange = [header rangeOfString:[NSString stringWithFormat:@"%@=", param]];
	if(startRange.location == NSNotFound)
	{
		return nil;
	}
	NSUInteger postStartRangeLocation = startRange.location + startRange.length;
	NSUInteger postStartRangeLength = [header length] - postStartRangeLocation;
	NSRange postStartRange = NSMakeRange(postStartRangeLocation, postStartRangeLength);
	NSRange endRange = [header rangeOfString:@"," options:0 range:postStartRange];
	if(endRange.location == NSNotFound)
	{
		NSRange endRange2 = [header rangeOfString:@" " options:0 range:postStartRange];
		if(endRange2.location != NSNotFound)
		{
			return nil;
		}
		else
		{
			return [header substringWithRange:postStartRange];
		}
	}
	else
	{
		NSRange subHeaderRange = NSMakeRange(postStartRangeLocation, endRange.location - postStartRangeLocation);
		return [header substringWithRange:subHeaderRange];
	}
}
@end
