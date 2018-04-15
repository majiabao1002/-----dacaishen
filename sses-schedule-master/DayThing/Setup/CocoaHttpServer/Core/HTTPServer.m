#import "HTTPServer.h"
#import "GCDAsyncSocket.h"
#import "HTTPConnection.h"
#import "WebSocket.h"
#import "HTTPLogging.h"
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
static const int httpLogLevel = HTTP_LOG_LEVEL_INFO; 
@interface HTTPServer (PrivateAPI)
- (void)unpublishBonjour;
- (void)publishBonjour;
+ (void)startBonjourThreadIfNeeded;
+ (void)performBonjourBlock:(dispatch_block_t)block;
@end
#pragma mark -
@implementation HTTPServer
- (id)init
{
	if ((self = [super init]))
	{
		HTTPLogTrace();
		serverQueue = dispatch_queue_create("HTTPServer", NULL);
		connectionQueue = dispatch_queue_create("HTTPConnection", NULL);
		IsOnServerQueueKey = &IsOnServerQueueKey;
		IsOnConnectionQueueKey = &IsOnConnectionQueueKey;
		void *nonNullUnusedPointer = (__bridge void *)self; 
		dispatch_queue_set_specific(serverQueue, IsOnServerQueueKey, nonNullUnusedPointer, NULL);
		dispatch_queue_set_specific(connectionQueue, IsOnConnectionQueueKey, nonNullUnusedPointer, NULL);
		asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:serverQueue];
		connectionClass = [HTTPConnection self];
		interface = nil;
		port = 0;
		domain = @"local.";
		name = @"";
		connections = [[NSMutableArray alloc] init];
		webSockets  = [[NSMutableArray alloc] init];
		connectionsLock = [[NSLock alloc] init];
		webSocketsLock  = [[NSLock alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(connectionDidDie:)
		                                             name:HTTPConnectionDidDieNotification
		                                           object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(webSocketDidDie:)
		                                             name:WebSocketDidDieNotification
		                                           object:nil];
		isRunning = NO;
	}
	return self;
}
- (void)dealloc
{
	HTTPLogTrace();
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self stop];
	#if !OS_OBJECT_USE_OBJC
	dispatch_release(serverQueue);
	dispatch_release(connectionQueue);
	#endif
	[asyncSocket setDelegate:nil delegateQueue:NULL];
}
#pragma mark Server Configuration
- (NSString *)documentRoot
{
	__block NSString *result;
	dispatch_sync(serverQueue, ^{
		result = documentRoot;
	});
	return result;
}
- (void)setDocumentRoot:(NSString *)value
{
	HTTPLogTrace();
	if (value && ![value isKindOfClass:[NSString class]])
	{
		HTTPLogWarn(@"%@: %@ - Expecting NSString parameter, received %@ parameter",
					THIS_FILE, THIS_METHOD, NSStringFromClass([value class]));
		return;
	}
	NSString *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		documentRoot = valueCopy;
	});
}
- (Class)connectionClass
{
	__block Class result;
	dispatch_sync(serverQueue, ^{
		result = connectionClass;
	});
	return result;
}
- (void)setConnectionClass:(Class)value
{
	HTTPLogTrace();
	dispatch_async(serverQueue, ^{
		connectionClass = value;
	});
}
- (NSString *)interface
{
	__block NSString *result;
	dispatch_sync(serverQueue, ^{
		result = interface;
	});
	return result;
}
- (void)setInterface:(NSString *)value
{
	NSString *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		interface = valueCopy;
	});
}
- (UInt16)port
{
	__block UInt16 result;
	dispatch_sync(serverQueue, ^{
		result = port;
	});
    return result;
}
- (UInt16)listeningPort
{
	__block UInt16 result;
	dispatch_sync(serverQueue, ^{
		if (isRunning)
			result = [asyncSocket localPort];
		else
			result = 0;
	});
	return result;
}
- (void)setPort:(UInt16)value
{
	HTTPLogTrace();
	dispatch_async(serverQueue, ^{
		port = value;
	});
}
- (NSString *)domain
{
	__block NSString *result;
	dispatch_sync(serverQueue, ^{
		result = domain;
	});
    return result;
}
- (void)setDomain:(NSString *)value
{
	HTTPLogTrace();
	NSString *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		domain = valueCopy;
	});
}
- (NSString *)name
{
	__block NSString *result;
	dispatch_sync(serverQueue, ^{
		result = name;
	});
	return result;
}
- (NSString *)publishedName
{
	__block NSString *result;
	dispatch_sync(serverQueue, ^{
		if (netService == nil)
		{
			result = nil;
		}
		else
		{
			dispatch_block_t bonjourBlock = ^{
				result = [[netService name] copy];
			};
			[[self class] performBonjourBlock:bonjourBlock];
		}
	});
	return result;
}
- (void)setName:(NSString *)value
{
	NSString *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		name = valueCopy;
	});
}
- (NSString *)type
{
	__block NSString *result;
	dispatch_sync(serverQueue, ^{
		result = type;
	});
	return result;
}
- (void)setType:(NSString *)value
{
	NSString *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		type = valueCopy;
	});
}
- (NSDictionary *)TXTRecordDictionary
{
	__block NSDictionary *result;
	dispatch_sync(serverQueue, ^{
		result = txtRecordDictionary;
	});
	return result;
}
- (void)setTXTRecordDictionary:(NSDictionary *)value
{
	HTTPLogTrace();
	NSDictionary *valueCopy = [value copy];
	dispatch_async(serverQueue, ^{
		txtRecordDictionary = valueCopy;
		if (netService)
		{
			NSNetService *theNetService = netService;
			NSData *txtRecordData = nil;
			if (txtRecordDictionary)
				txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDictionary];
			dispatch_block_t bonjourBlock = ^{
				[theNetService setTXTRecordData:txtRecordData];
			};
			[[self class] performBonjourBlock:bonjourBlock];
		}
	});
}
#pragma mark Server Control
- (BOOL)start:(NSError **)errPtr
{
	HTTPLogTrace();
	__block BOOL success = YES;
	__block NSError *err = nil;
	dispatch_sync(serverQueue, ^{ @autoreleasepool {
		success = [asyncSocket acceptOnInterface:interface port:port error:&err];
		if (success)
		{
			HTTPLogInfo(@"%@: Started HTTP server on port %hu", THIS_FILE, [asyncSocket localPort]);
			isRunning = YES;
			[self publishBonjour];
		}
		else
		{
			HTTPLogError(@"%@: Failed to start HTTP Server: %@", THIS_FILE, err);
		}
	}});
	if (errPtr)
		*errPtr = err;
	return success;
}
- (void)stop
{
	[self stop:NO];
}
- (void)stop:(BOOL)keepExistingConnections
{
	HTTPLogTrace();
	dispatch_sync(serverQueue, ^{ @autoreleasepool {
		[self unpublishBonjour];
		[asyncSocket disconnect];
		isRunning = NO;
		if (!keepExistingConnections)
		{
			[connectionsLock lock];
			for (HTTPConnection *connection in connections)
			{
				[connection stop];
			}
			[connections removeAllObjects];
			[connectionsLock unlock];
			[webSocketsLock lock];
			for (WebSocket *webSocket in webSockets)
			{
				[webSocket stop];
			}
			[webSockets removeAllObjects];
			[webSocketsLock unlock];
		}
	}});
}
- (BOOL)isRunning
{
	__block BOOL result;
	dispatch_sync(serverQueue, ^{
		result = isRunning;
	});
	return result;
}
- (void)addWebSocket:(WebSocket *)ws
{
	[webSocketsLock lock];
	HTTPLogTrace();
	[webSockets addObject:ws];
	[webSocketsLock unlock];
}
#pragma mark Server Status
- (NSUInteger)numberOfHTTPConnections
{
	NSUInteger result = 0;
	[connectionsLock lock];
	result = [connections count];
	[connectionsLock unlock];
	return result;
}
- (NSUInteger)numberOfWebSocketConnections
{
	NSUInteger result = 0;
	[webSocketsLock lock];
	result = [webSockets count];
	[webSocketsLock unlock];
	return result;
}
#pragma mark Incoming Connections
- (HTTPConfig *)config
{
	return [[HTTPConfig alloc] initWithServer:self documentRoot:documentRoot queue:connectionQueue];
}
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	HTTPConnection *newConnection = (HTTPConnection *)[[connectionClass alloc] initWithAsyncSocket:newSocket
	                                                                                 configuration:[self config]];
	[connectionsLock lock];
	[connections addObject:newConnection];
	[connectionsLock unlock];
	[newConnection start];
}
#pragma mark Bonjour
- (void)publishBonjour
{
	HTTPLogTrace();
	NSAssert(dispatch_get_specific(IsOnServerQueueKey) != NULL, @"Must be on serverQueue");
	if (type)
	{
		netService = [[NSNetService alloc] initWithDomain:domain type:type name:name port:[asyncSocket localPort]];
		[netService setDelegate:self];
		NSNetService *theNetService = netService;
		NSData *txtRecordData = nil;
		if (txtRecordDictionary)
			txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDictionary];
		dispatch_block_t bonjourBlock = ^{
			[theNetService removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
			[theNetService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
			[theNetService publish];
			if (txtRecordData)
			{
				[theNetService setTXTRecordData:txtRecordData];
			}
		};
		[[self class] startBonjourThreadIfNeeded];
		[[self class] performBonjourBlock:bonjourBlock];
	}
}
- (void)unpublishBonjour
{
	HTTPLogTrace();
	NSAssert(dispatch_get_specific(IsOnServerQueueKey) != NULL, @"Must be on serverQueue");
	if (netService)
	{
		NSNetService *theNetService = netService;
		dispatch_block_t bonjourBlock = ^{
			[theNetService stop];
		};
		[[self class] performBonjourBlock:bonjourBlock];
		netService = nil;
	}
}
- (void)republishBonjour
{
	HTTPLogTrace();
	dispatch_async(serverQueue, ^{
		[self unpublishBonjour];
		[self publishBonjour];
	});
}
- (void)netServiceDidPublish:(NSNetService *)ns
{
	HTTPLogInfo(@"Bonjour Service Published: domain(%@) type(%@) name(%@)", [ns domain], [ns type], [ns name]);
}
- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	HTTPLogWarn(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@",
	                                         [ns domain], [ns type], [ns name], errorDict);
}
#pragma mark Notifications
- (void)connectionDidDie:(NSNotification *)notification
{
	[connectionsLock lock];
	HTTPLogTrace();
	[connections removeObject:[notification object]];
	[connectionsLock unlock];
}
- (void)webSocketDidDie:(NSNotification *)notification
{
	[webSocketsLock lock];
	HTTPLogTrace();
	[webSockets removeObject:[notification object]];
	[webSocketsLock unlock];
}
#pragma mark Bonjour Thread
static NSThread *bonjourThread;
+ (void)startBonjourThreadIfNeeded
{
	HTTPLogTrace();
	static dispatch_once_t predicate;
	dispatch_once(&predicate, ^{
		HTTPLogVerbose(@"%@: Starting bonjour thread...", THIS_FILE);
		bonjourThread = [[NSThread alloc] initWithTarget:self
		                                        selector:@selector(bonjourThread)
		                                          object:nil];
		[bonjourThread start];
	});
}
+ (void)bonjourThread
{
	@autoreleasepool {
		HTTPLogVerbose(@"%@: BonjourThread: Started", THIS_FILE);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
		[NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow]
		                                 target:self
		                               selector:@selector(donothingatall:)
		                               userInfo:nil
		                                repeats:YES];
#pragma clang diagnostic pop
		[[NSRunLoop currentRunLoop] run];
		HTTPLogVerbose(@"%@: BonjourThread: Aborted", THIS_FILE);
	}
}
+ (void)executeBonjourBlock:(dispatch_block_t)block
{
	HTTPLogTrace();
	NSAssert([NSThread currentThread] == bonjourThread, @"Executed on incorrect thread");
	block();
}
+ (void)performBonjourBlock:(dispatch_block_t)block
{
	HTTPLogTrace();
	[self performSelector:@selector(executeBonjourBlock:)
	             onThread:bonjourThread
	           withObject:block
	        waitUntilDone:YES];
}
@end
