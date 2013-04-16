//
//  ViewController.m
//  KTHttpRequest
//
//  Created by UNI on 2013/04/16.
//  Copyright (c) 2013年 UNI. All rights reserved.
//

#import "ViewController.h"
#import "ORKTHttpRequest.h"

@interface ViewController () {
	NSOperationQueue *queue;
	__block KTHttpRequest *request;
}

@property (nonatomic, weak) IBOutlet UIProgressView *ulProgressView;
@property (nonatomic, weak) IBOutlet UIProgressView *dlProgressView;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)cancel:(id)sender {
	[request cancelConnection];
	//[queue cancelAllOperations];
}

- (IBAction)send:(id)sender {
	
	
	request = [ORKTHttpRequest requestWithURL:[NSURL URLWithString:@"http://example.com/"]];
	
	__weak KTHttpRequest *weakObject = request;
	
	[request setTaskStartBlock:^{
		NSLog(@"タスク開始");
	}];
	[request setTaskFinishBlock:^{
		NSLog(@"タスク終了");
	}];
	[request setUploadProgressBlock:^(long double bytes, long double totalBytes, long double totalBytesExpected) {
		NSLog(@"upload %Lf %Lf %Lf", bytes, totalBytes, totalBytesExpected);
	}];
	[request setDownloadProgressBlock:^(long double bytes, long double totalBytes, long double totalBytesExpected) {
		NSLog(@"download %Lf %Lf %Lf", bytes, totalBytes, totalBytesExpected);
	}];
	[request setFinishBlock:^{
		NSLog(@"blocks success tag:%d", weakObject.tag);
		NSLog(@"%@", weakObject.responseString);
		NSLog(@"json %@", weakObject.responseJSON);
	}];
	[request setFailBlock:^{
		NSLog(@"通信エラー %d / error %@", weakObject.responseStatusCode, weakObject.error);
	}];
	[request setHeaderBlock:^{
		NSLog(@"ヘッダ受信");
	}];
	
	// ベーシック認証サイトにアクセスする場合の設定
	//request.delegate = self;						// デリゲートでIDとパスワードを返すと認証できる。
	[request showAuthenticationDialog:YES];			// ダイアログにIDとパスワードを入力すると認証できる。
	//[request setAuthenticationId:@"userid0001"];	// ダイレクトにユーザを設定します。
	//[request setAuthenticationPw:@"password0001"];	// ダイレクトにパスワードを設定します。
	
	[request setHTTPMethod:@"POST"];
	[request setTimeOutSeconds:10];
	[request addRequestHeader:@"Content-Type" value:@"application/x-www-form-urlencoded"];
	[request addRequestHeader:@"User-Agent" value:@"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Mobile/9A405 Safari/7534.48.3"];
	
	// post data
	[request addPostValue:@"userid0001" forKey:@"login_id"];
	[request addPostValue:@"password0001" forKey:@"login_password"];
	
	// add data
//	NSBundle *bundle = [NSBundle mainBundle];
//	NSString *path = [bundle pathForResource:@"dataFile" ofType:@"zip"];
//	NSData *fileData = [[NSData alloc] initWithContentsOfFile:path];
//	[request addData:fileData forKey:@"data"];
	
	// POST or Multipart
	[request setPostFormat:KTMultipartFormDataPostFormat];
	
	[request showIndicator:NO];
	[request setIndicatorMessage:@"データ受信中"];
	[request isJsonResponse:NO];
	[request setTag:100];
	[request setValidatesSecureCertificate:YES]; // 証明書のチェック
	
	// プログレスバーの更新をKTHttpRequestに委譲する
	request.ulProgressView = self.ulProgressView;
	request.dlProgressView = self.dlProgressView;
	
	
	// 非同期通信:サブスレッド
	dispatch_async(dispatch_get_global_queue(0, 0), ^{
		[request startAsynchronous];
	});
	
	// 非同期通信:メインスレッド
	/*
	 [request startAsynchronous];
	 */
	
	// 非同期通信:サブスレッドNSOperation
	/*
	 queue = [[NSOperationQueue alloc] init];
	 [queue addOperation:request];
	 */
	
	// 非同期通信:メインスレッドNSOperation
	/*
	 queue = [NSOperationQueue mainQueue];
	 [queue addOperation:request];
	 */
	
}

- (void)success:(KTHttpRequest *)_response {
	//NSLog(@"%@", _response.responseData); // Response Data By NSData
	//NSLog(@"%@", _response.responseString); // Response Data By NSString
	NSLog(@"delegate success tag:%d", _response.tag);
	//NSLog(@"%@", _response.responseString);
}

- (void)fail:(KTHttpRequest *)_response {
	NSLog(@"delegate fail %d / error %@", _response.responseStatusCode, _response.error);
}

- (void)header:(KTHttpRequest *)_response {
	//NSLog(@"=============");
	//NSLog(@"%@", _response.headerFields);
	//NSLog(@"=============");
}

- (id)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge withObject:(KTHttpRequest *)object {
	
	if ([object.getUrl isEqualToString:@"http://test1.com"]) {
		
		return [NSArray arrayWithObjects:@"userid0001", @"password0001",  nil];
		
	} else if ([object.getUrl isEqualToString:@"http://test2.com"]) {
		
		return [NSArray arrayWithObjects:@"test0001", @"password0001",  nil];
		
	} else {
		
		return nil; // KTAuthenticationChallengeSkip or nil
		
	}
}

- (void)authenticationChallengeInputId:(NSString *)inputId inputPassword:(NSString *)inputPassword {
	NSLog(@"inputId %@, inputPassword %@", inputId, inputPassword);
}

- (void)progressSend:(long double)bytes totalBytes:(long double)totalBytes totalBytesExpected:(long double)totalBytesExpected withObject:(KTHttpRequest *)object {
	NSLog(@"upload %Lf %Lf %Lf", bytes, totalBytes, totalBytesExpected);
}

- (void)progressReceive:(long double)bytes totalBytes:(long double)totalBytes totalBytesExpected:(long double)totalBytesExpected withObject:(KTHttpRequest *)object {
	NSLog(@"download %Lf %Lf %Lf", bytes, totalBytes, totalBytesExpected);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
