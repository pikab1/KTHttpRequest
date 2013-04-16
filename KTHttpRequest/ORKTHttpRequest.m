//
//  ORKTHttpRequest.m
//  KTHTTPRequestDemo
//
//  Created by UNI on 2013/04/10.
//
//

#import "ORKTHttpRequest.h"

@implementation ORKTHttpRequest

- (id)initWithURL:(NSURL *)newURL {
	self = [super initWithURL:newURL];
	
	// ここで設定変更してもいい
	
	return self;
}

/**************************************/
// Getterメソッドをoverrideしての設定変更
/**************************************/

// override
- (NSStringEncoding)stringEncoding {
	return NSUTF8StringEncoding;
}

// override
- (NSTimeInterval)timeOutSeconds {
	return 120.0f;
}

// override
- (BOOL)showIndicator {
	return YES;
}

// override
- (BOOL)isJsonResponse {
	return YES;
}

// override
- (NSString *)indicatorMessage {
	return @"準備中...";
}

// override
- (NSString *)httpMethod {
	return @"POST";
}

// override
- (NSURLRequestCachePolicy)cachePolicy {
	return NSURLRequestReloadIgnoringLocalCacheData;
}

// override
- (BOOL)validatesSecureCertificate {
	return YES;
}

// override
- (NSUInteger)maxAuthenticationFailed {
	return 3;
}

// override
- (int)redirectionLimit {
	return 10;
}

/*****************************************/
// 各プロセスのオーバーライド、全てMainThread
/*****************************************/

// override
- (void)connectionStart {
	NSLog(@"■通信の準備を開始する");
	
	//[NSThread sleepForTimeInterval:5.0f];
	
	[super connectionStart];
}

// override
- (void)connectionHeader {
	NSLog(@"■ヘッダを受信した");
	[super connectionHeader];
}

// override
- (void)connectionSuccess {
	NSLog(@"■通信が成功した");
	[super connectionSuccess];
}

// override
- (void)connectionError {
	NSLog(@"■通信エラーが発生した");
	[super connectionError];
}

@end
