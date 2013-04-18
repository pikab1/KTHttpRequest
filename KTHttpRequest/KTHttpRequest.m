//
//  KTHttpRequest.m
//

#import "KTHttpRequest.h"
#import "SVProgressHUD.h"

NSString *const KTAuthenticationChallengeSkip = @"KTAuthenticationChallengeSkip";

//-------------------------------------------------------------------------------------//
#pragma mark -- macros --
//-------------------------------------------------------------------------------------//

#define UPDATE_UL_PROGRESS(p) if (ulProgressView) {dispatch_async(dispatch_get_main_queue(), ^{ulProgressView.progress = p;});}
#define UPDATE_DL_PROGRESS(p) if (dlProgressView) {dispatch_async(dispatch_get_main_queue(), ^{dlProgressView.progress = p;});}
#define IS_CANCEL_OPERATION [self isCancelOperation];

//-------------------------------------------------------------------------------------//
#pragma mark -- log setting --
//-------------------------------------------------------------------------------------//

// low 1 ~ 3 high
#define APP_LOG_LEVEL 0

#if APP_LOG_LEVEL >= 1
#  define KTHTTP_LOG(...) NSLog(__VA_ARGS__)
#  define KTHTTP_LOG_METHOD NSLog(@"%s line:%d", __func__ , __LINE__)
#else
#  define KTHTTP_LOG(...) ;
#  define KTHTTP_LOG_METHOD ;
#endif

//-------------------------------------------------------------------------------------//
#pragma mark -- default parameters --
//-------------------------------------------------------------------------------------//

const NSTimeInterval defaultTimeOutSeconds = 60.0f;

NSString *const defaultHttpMethod = @"POST";

const NSStringEncoding defaultStringEncoding = NSUTF8StringEncoding;

const BOOL defaultShowIndicator = NO;

const BOOL defaultIsJsonResponse = NO; // YESにするとレスポンスがJSONの場合にJSONパースする。格納先はrequest.responseJSON

NSString *const defaultIndicatorMessage = @"通信中...";

const KTPostFormat defaultKTPostFormat = KTURLEncodedPostFormat; // 通常のPOST形式

const NSURLRequestCachePolicy defaultRequestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData; // キャッシュしない

const BOOL defaultShowAuthenticationDialog = NO;

const BOOL defaultValidatesSecureCertificate = YES; // 証明書をチェックするか。NOならオレオレ証明書でも許可する

const NSInteger defaultMaxAuthenticationFailed = 5; // 認証ページでこの数値以上失敗すると通信失敗とする

const int defaultRedirectionLimit = 5; // この数値以上リダイレクトを連続で行うと通信失敗とする

@interface KTHttpRequest () {
	NSData *responseData;
	NSMutableURLRequest *_request;
	NSError *error;
	NSMutableData *requestBody;
	NSMutableDictionary *t_postBody;
	NSMutableArray *fileData;
	int responseStatusCode;
	NSMutableData *async_data;
	NSURLConnection *connection;
	NSDictionary *headerFields;
	SEL willStartSelector;
	SEL didReceiveResponseHeadersSelector;
	SEL didFinishSelector;
	SEL didFailSelector;
	__weak NSObject <KTHttpRequestDelegate> *delegate;
	NSOperationQueue *privateQueue;
	long double uploadTotalBytesWritten;
	long double _totalBytesExpectedToWrite;
	long double downloadTotalBytesLength;
	long double downloadExpectedContentLength;
	NSURLAuthenticationChallenge *_authenticationChallenge;
	int redirectCount;
	
	// operation
	BOOL isCanceled;
	BOOL _isExecuting, _isFinished;
	NSLock *cancelOperationLock;
}

@property (nonatomic, strong) NSMutableData *requestBody;
@property (nonatomic, strong) NSMutableDictionary *t_postBody;
@property (nonatomic, strong) NSMutableArray *fileData;
@property (nonatomic) NSStringEncoding stringEncoding;
@property (nonatomic, strong) NSDictionary *headerFields;

typedef void (^mainThreadProcessing)(void);

// handler
typedef void(^ConnectionHandler)(void);
@property (nonatomic, copy) ConnectionHandler connectionStartHandler;
@property (nonatomic, copy) ConnectionHandler connectionHeaderHandler;
@property (nonatomic, copy) ConnectionHandler connectionFinishHandler;
@property (nonatomic, copy) ConnectionHandler connectionFailHandler;
typedef void (^ProgressHandler)(long double bytes, long double totalBytes, long double totalBytesExpected);
@property (nonatomic, copy) ProgressHandler uploadProgressHandler;
@property (nonatomic, copy) ProgressHandler downloadProgressHandler;

- (NSString*)encodeURL:(NSString *)string;
- (NSString *)encodeWithData:(NSData *)data;
- (void)settingRequest;
- (void)settingMultipartFormDataPostBody;
- (void)startOperation;
- (void)clear;
- (void)mainThread:(mainThreadProcessing)block;
- (void)retryingAuthenticationWithId:(NSString *)userId password:(NSString *)password;

@end;

@implementation KTHttpRequest

@synthesize connectionStartHandler;
@synthesize connectionHeaderHandler;
@synthesize connectionFinishHandler;
@synthesize connectionFailHandler;
@synthesize responseString;
@synthesize responseJSON;
@synthesize responseData;
@synthesize error;
@synthesize requestBody;
@synthesize t_postBody;
@synthesize fileData;
@synthesize timeOutSeconds;
@synthesize stringEncoding;
@synthesize showIndicator;
@synthesize isJsonResponse;
@synthesize responseStatusCode;
@synthesize willStartSelector;
@synthesize didReceiveResponseHeadersSelector;
@synthesize didFinishSelector;
@synthesize didFailSelector;
@synthesize delegate;
@synthesize headerFields;
@synthesize postFormat;
@synthesize tag;
@synthesize indicatorMessage;
@synthesize httpMethod;
@synthesize dlProgressView;
@synthesize ulProgressView;
@synthesize showAuthenticationDialog;
@synthesize authenticationId;
@synthesize authenticationPw;
@synthesize validatesSecureCertificate;
@synthesize maxAuthenticationFailed;
@synthesize redirectionLimit;
@synthesize uploadProgressHandler;
@synthesize downloadProgressHandler;

//-------------------------------------------------------------------------------------//
#pragma mark -- init and dealloc --
//-------------------------------------------------------------------------------------//

+ (id)requestWithURL:(NSURL *)newURL {
	return [[self alloc] initWithURL:newURL];
}

+ (id)requestWithURLString:(NSString *)newURL {
	return [[self alloc] initWithURL:[NSURL URLWithString:newURL]];
}

- (id)initWithURL:(NSURL *)newURL {
	KTHTTP_LOG_METHOD;
	self = [super init];
	
	cancelOperationLock = [[NSLock alloc] init];
	
	[self setPostFormat:defaultKTPostFormat];
	[self setStringEncoding:defaultStringEncoding];
	[self showIndicator:defaultShowIndicator];
	[self isJsonResponse:defaultIsJsonResponse];
	[self setIndicatorMessage:defaultIndicatorMessage];
	[self setHTTPMethod:defaultHttpMethod];
	[self setTimeOutSeconds:defaultTimeOutSeconds];
	[self setCachePolicy:defaultRequestCachePolicy];
	[self showAuthenticationDialog:defaultShowAuthenticationDialog];
	[self setValidatesSecureCertificate:defaultValidatesSecureCertificate];
	[self setMaxAuthenticationFailed:defaultMaxAuthenticationFailed];
	[self setRedirectionLimit:defaultRedirectionLimit];
	
	self.t_postBody = [NSMutableDictionary dictionary];
	self.requestBody = [NSMutableData data];
	
	_request = [[NSMutableURLRequest alloc] initWithURL:newURL];
	
	_isExecuting = NO;
	_isFinished = NO;
	
	return self;
}

- (void)dealloc {
#if APP_LOG_LEVEL >= 1
	KTHTTP_LOG(@"dealloc");
#endif
}

/**
	受信したデータ類を全て初期化する。
	設定されているHTTPヘッダなどはそのまま保持する
 */
- (void)clear {
	async_data = nil;
	error = nil;
	responseStatusCode = 0;
	self.headerFields = nil;
	responseData = nil;
	responseString = nil;
	responseJSON = nil;
	UPDATE_DL_PROGRESS(0.0f);
	UPDATE_UL_PROGRESS(0.0f);
	uploadTotalBytesWritten = 0.0f;
	//_totalBytesExpectedToWrite = 0.0f;
	downloadTotalBytesLength = 0.0f;
	downloadExpectedContentLength = 0.0f;
	redirectCount = -1;
}

//-------------------------------------------------------------------------------------//
#pragma mark -- setter and getter --
//-------------------------------------------------------------------------------------//

// 通信を開始する直前に時点で呼ばれるBlock
- (void)setConnectionStartBlock:(void(^)(void))block {
	self.connectionStartHandler = block;
}

// ヘッダを受信した時点で呼び出すBlock
- (void)setConnectionHeaderBlock:(void(^)(void))block {
	self.connectionHeaderHandler = block;
}

// 通信が成功した時点で呼び出すBlock
- (void)setConnectionFinishBlock:(void(^)(void))block {
	self.connectionFinishHandler = block;
}

// 通信が失敗した時点で呼び出すBlock
- (void)setConnectionFailBlock:(void(^)(void))block {
	self.connectionFailHandler = block;
}

// アップロード進捗を返すBlock
- (void)setUploadProgressBlock:(void (^)(long double bytes, long double totalBytes, long double totalBytesExpected))block {
	self.uploadProgressHandler = block;
}

// ダウンロード進捗を返すBlock
- (void)setDownloadProgressBlock:(void (^)(long double bytes, long double totalBytes, long double totalBytesExpected))block {
	self.downloadProgressHandler = block;
}

/**
	接続先を設定します
	@param url 
 */
- (void)setUrl:(NSString *)url {
	_request.URL = [NSURL URLWithString:url];
}

/**
	接続先URLを追記します
	@param url 
 */
- (void)appendUrl:(NSString *)url {
	_request.URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [self getUrl], url]];
}

/**
	接続先URLを返します
	@returns 
 */
- (NSString *)getUrl {
	return [_request.URL absoluteString];
}

/**
	requestオブジェクトに対してRequestHeaderを設定します
	@param header ヘッダ名
	@param value ヘッダ値
 */
- (void)addRequestHeader:(NSString *)header value:(NSString *)value {
	[_request addValue:value forHTTPHeaderField:header];
}

/**
	body部にkey=value形式で追加します
	@param value
	@param key 
 */
- (void)addPostValue:(NSString *)value forKey:(NSString *)key {
	[t_postBody setObject:value forKey:key];
}

/**
	body部にvalueをそのまま追加します
	@param value
 */
- (void)appendPostValue:(NSString *)value {
	[requestBody appendData:[value dataUsingEncoding:[self stringEncoding]]];
}

/**
	body部にdataをそのまま追加します
	@param data 
 */
- (void)appendPostData:(NSData *)data {
	[requestBody appendData:data];
}

/**
	マルチパートでデータを設定します
	@param data
	@param key 
 */
- (void)addData:(NSData *)data forKey:(NSString *)key {
	[self addData:data withFileName:@"file" andContentType:nil forKey:key];
}

/**
	マルチパートでデータを設定します。
	@param data
	@param fileName
	@param contentType
	@param key 
 */
- (void)addData:(NSData *)data withFileName:(NSString *)fileName andContentType:(NSString *)contentType forKey:(NSString *)key {
	if (![self fileData]) {
		[self setFileData:[NSMutableArray array]];
	}
	if (!contentType) {
		contentType = @"application/octet-stream";
	}
	
	NSDictionary *fileInfo = [NSDictionary dictionaryWithObjectsAndKeys:data, @"data", contentType, @"contentType", fileName, @"fileName", key, @"key", nil];
	[[self fileData] addObject:fileInfo];
}

/**
	レスポンスヘッダを返します
	@returns
 */
- (NSDictionary *)allHeaderFields {
	return self.headerFields;
}

/**
	通信直前にbody部を設定します
 */
- (void)settingRequest {
	KTHTTP_LOG_METHOD;
	
	[_request setTimeoutInterval:[self timeOutSeconds]];
	[_request setHTTPMethod:[self httpMethod]];
	[_request setCachePolicy:[self cachePolicy]];
	
	if ([[self fileData] count] > 0 || postFormat == KTMultipartFormDataPostFormat) {
		
		[self settingMultipartFormDataPostBody];
	
	} else {
		
		for (id key in [t_postBody keyEnumerator]) {
			if ([requestBody length] != 0) {
				[requestBody appendData:[@"&" dataUsingEncoding:[self stringEncoding]]];
			}
			NSString *value = [t_postBody valueForKey:key];
			[requestBody appendData:[[NSString stringWithFormat:@"%@=%@", [self encodeURL:key], [self encodeURL:value]] dataUsingEncoding:[self stringEncoding]]];
		}
		
	}
	
#if APP_LOG_LEVEL >= 2
	KTHTTP_LOG(@"==== requestBody start ====\n");
	KTHTTP_LOG(@"%@", [[NSString alloc] initWithData:requestBody encoding:[self stringEncoding]]);
	KTHTTP_LOG(@"\n==== requestBody end ====");
#endif
	
	[_request setHTTPBody:requestBody];
	
	_totalBytesExpectedToWrite = [requestBody length];
}

// マルチパートのbody部を設定します
/*
 参考
 http://allseeing-i.com/ASIHTTPRequest/
 */
- (void)settingMultipartFormDataPostBody {
	KTHTTP_LOG_METHOD;
	
	NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding([self stringEncoding]));
	
	NSString *stringBoundary = [self randomStringWithLength:20];
	
	[self addRequestHeader:@"Content-Type" value:[NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@", charset, stringBoundary]];
	
	[self appendPostValue:[NSString stringWithFormat:@"--%@\r\n",stringBoundary]];
	
	// Adds post data
	NSString *endItemBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary];
	NSUInteger i = 0;
	
	for (id key in [t_postBody keyEnumerator]) {
		[self appendPostValue:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n",key]];
		[self appendPostValue:[t_postBody valueForKey:key]];
		i++;
		if (i != [[self t_postBody] count] || [[self fileData] count] > 0) { //Only add the boundary if this is not the last item in the post body
			[self appendPostValue:endItemBoundary];
		}
	}
	
	i = 0;
	for (NSDictionary *val in [self fileData]) {
		
		[self appendPostValue:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", [val objectForKey:@"key"], [val objectForKey:@"fileName"]]];
		[self appendPostValue:[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", [val objectForKey:@"contentType"]]];
		
		NSData *data = [val objectForKey:@"data"];
		[self appendPostData:data];
		
		i++;
		// Only add the boundary if this is not the last item in the post body
		if (i != [[self fileData] count]) {
			[self appendPostValue:endItemBoundary];
		}
	}
	
	[self appendPostValue:[NSString stringWithFormat:@"\r\n--%@--\r\n",stringBoundary]];
}

/**
	同期通信開始メソッド（2013/04/10 takeuchi このメソッドはもう更新しません）
 */
- (void)startSynchronous {
	KTHTTP_LOG_METHOD;
	[self performSelectorOnMainThread:@selector(connectionStart) withObject:nil waitUntilDone:[NSThread isMainThread]];
	
	[self clear]; // 受信データ初期化
	
	[self settingRequest];
	
	NSURLResponse *response = nil;
	NSError *err = nil;
	NSData *data = [
					NSURLConnection
					sendSynchronousRequest : _request
					returningResponse : &response
					error : &err
					];
	
	// ステータスコード
	responseStatusCode = [(NSHTTPURLResponse *)response statusCode];
	
	// エラー取得
	if (err != nil || self.responseStatusCode >= 400) {
		error = err;
		[self performSelectorOnMainThread:@selector(connectionError) withObject:nil waitUntilDone:[NSThread isMainThread]];
	} else {
		responseData = data;
		[self performSelectorOnMainThread:@selector(connectionSuccess) withObject:nil waitUntilDone:[NSThread isMainThread]];
	}
}

/**
	非同期通信開始メソッド
 */
- (void)startAsynchronous {
	if (!privateQueue) {
		privateQueue = [[NSOperationQueue alloc] init];
		privateQueue.maxConcurrentOperationCount = 1;
	}
	[privateQueue addOperation:self];
}

// 非同期通信本体
- (void)asynchronous {
	KTHTTP_LOG_METHOD;
	
	IS_CANCEL_OPERATION;
	
	[self performSelectorOnMainThread:@selector(connectionStart) withObject:nil waitUntilDone:YES];
	
	[self clear]; // 受信データ初期化
	
	[self settingRequest];
	
	connection = [
				  [NSURLConnection alloc]
				  initWithRequest : _request
				  delegate : self
				  ];
	if (connection == nil) {
		[self performSelectorOnMainThread:@selector(connectionError) withObject:nil waitUntilDone:[NSThread isMainThread]];
	}
}

/**
	NSOperation:start時に使用される(Private)
 */
- (void)startOperation {

	[self asynchronous];
	
	if (connection != nil) {
		do {
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
		} while (_isExecuting);
	}
}

//-------------------------------------------------------------------------------------//
#pragma mark -- NSURLConnectionDelegate --
//-------------------------------------------------------------------------------------//

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
	NSString *authenticationMethod = protectionSpace.authenticationMethod;
	if ([authenticationMethod isEqual:NSURLAuthenticationMethodHTTPBasic]) {
		return YES;
	}
	if ([authenticationMethod isEqual:NSURLAuthenticationMethodServerTrust]) {
		return YES;
	}
	return NO;
}

-(void)connection:(NSURLConnection *)_connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {		// iOS5~
//- (void)connection:(NSURLConnection *)_connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {			// iOS4~
    KTHTTP_LOG_METHOD;
    
	IS_CANCEL_OPERATION;
	
	// 認証失敗回数を確認
	if ([challenge previousFailureCount] > [self maxAuthenticationFailed] - 1) {
		[[challenge sender] cancelAuthenticationChallenge:challenge]; // 通信失敗
		return;
	}
	
	NSString *authenticationMethod = [[challenge protectionSpace] authenticationMethod];
	
	if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]) { // BASIC認証
		
		KTHTTP_LOG(@"[challenge previousFailureCount] %d", [challenge previousFailureCount]);
		KTHTTP_LOG(@"[[challenge proposedCredential] user] %@", [[challenge proposedCredential] user]);
		KTHTTP_LOG(@"[[challenge proposedCredential] password] %@", [[challenge proposedCredential] password]);
		
        if ([challenge previousFailureCount] == 0 && [[challenge proposedCredential] user] && [[challenge proposedCredential] password]) {
            [[challenge sender] performDefaultHandlingForAuthenticationChallenge: challenge];
            return;
        }
		
		_authenticationChallenge = challenge;
		
		/*
		 ダイレクト認証
		 */
		NSString *authId = [self authenticationId];
		NSString *authPw = [self authenticationPw];
		if (authId && authPw) {
			[self retryingAuthenticationWithId:authId password:authPw];
		}
		
		[self mainThread:^{
			
			/*
			 デリゲート認証
			 */
			if (delegate && [delegate respondsToSelector:@selector(connection:didReceiveAuthenticationChallenge:withObject:)]) {
				id authenticationData = [delegate connection:_connection didReceiveAuthenticationChallenge:challenge withObject:self];
				
				if (authenticationData && [authenticationData isKindOfClass:[NSString class]] &&
					[authenticationData isEqualToString:KTAuthenticationChallengeSkip]) {
					
					// Do Nothing
					
				} else {
					
					if (authenticationData == nil || ![authenticationData isKindOfClass:[NSArray class]] || [authenticationData count] != 2) {
						[[challenge sender] cancelAuthenticationChallenge:challenge];
						return;
					}
					
					[self retryingAuthenticationWithId:[authenticationData objectAtIndex:0]
											  password:[authenticationData objectAtIndex:1]];
					
				}
			}
			
			/*
			 ダイアログ認証
			 */
			if ([self showAuthenticationDialog]) {
				UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Authentication"
																  message:nil
																 delegate:self
														cancelButtonTitle:@"Cancel"
														otherButtonTitles:@"OK", nil];
				[message setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
				[message show];
			}
			
		}];
		
    } else if ([authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) { // SSL
		
		// SSL証明書をチェックするか
		if ([self validatesSecureCertificate]) {
			[[challenge sender] performDefaultHandlingForAuthenticationChallenge: challenge];
		} else {
			[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
			[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
		}
		
    } else { // その他
		[[challenge sender] cancelAuthenticationChallenge:challenge];
	}
}

/**
	リクエスト又はリダイレクトが発生した際に呼ばれるデリゲート
	@param connection
	@param request
	@param redirectResponse
	@returns 
 */
-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSHTTPURLResponse *)redirectResponse {
#if APP_LOG_LEVEL >= 1
	KTHTTP_LOG(@"willSendRequest URL:%@", [[request URL] absoluteString]);
#endif
    NSURLRequest *newRequest = request;
	if (redirectCount > [self redirectionLimit]) {
		newRequest = nil;
	}
	redirectCount++;
    return newRequest;
}

/**
	NSURLConnectionでHTTPリクエスト時に呼ばれるデリゲート
	アップロードの進捗に使います
	
	@param connection
	@param bytesWritten 今回投げたバイト数
	@param totalBytesWritten 今まで投げたバイト数
	@param totalBytesExpectedToWrite 全体のバイト数
 */
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
	
	IS_CANCEL_OPERATION;
	
	uploadTotalBytesWritten += bytesWritten;
	UPDATE_UL_PROGRESS(uploadTotalBytesWritten / _totalBytesExpectedToWrite);

#if APP_LOG_LEVEL >= 3
	KTHTTP_LOG(@"============ UPLOAD ============");
	KTHTTP_LOG(@"bytesWritten %Lf", bytesWritten);
	KTHTTP_LOG(@"totalBytesWritten %Lf", uploadTotalBytesWritten);
	KTHTTP_LOG(@"totalBytesExpectedToWrite %Lf", _totalBytesExpectedToWrite);
	KTHTTP_LOG(@"progress %Lf", uploadTotalBytesWritten / _totalBytesExpectedToWrite);
	KTHTTP_LOG(@"============ UPLOAD ============");
#endif
	
	if (delegate && [delegate respondsToSelector:@selector(progressSend:totalBytes:totalBytesExpected:withObject:)]) {
		[self mainThread:^{
			[delegate progressSend:bytesWritten totalBytes:uploadTotalBytesWritten totalBytesExpected:_totalBytesExpectedToWrite withObject:self];
		}];
	}
	
	if (self.uploadProgressHandler) {
		[self mainThread:^{
			self.uploadProgressHandler(bytesWritten, uploadTotalBytesWritten, _totalBytesExpectedToWrite);
		}];
	}
}

/**
	NSURLConnectionでHTTPHeader受信時に呼ばれるデリゲート
	@param connection
	@param response 
 */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {

	KTHTTP_LOG_METHOD;
	
	IS_CANCEL_OPERATION;
	
	// ダウンロードするファイルのサイズを取得
	downloadExpectedContentLength = [response expectedContentLength];
	
	// レスポンスデータ初期化
	async_data = [[NSMutableData alloc] initWithData:0];
	
	// HTTPステータスコード取得
	NSHTTPURLResponse *res = (NSHTTPURLResponse *)response;
	responseStatusCode = [res statusCode];
	
	// レスポンスヘッダを取得
	@try {
		if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
			self.headerFields = [(NSHTTPURLResponse *)response allHeaderFields];
		}
	}
	@catch (NSException *exception) {
		//KTHTTP_LOG(@"main: Caught %@: %@", [exception name], [exception reason]);
	}
	
	[self performSelectorOnMainThread:@selector(connectionHeader) withObject:nil waitUntilDone:[NSThread isMainThread]];
	
	// HTTPステータスコードが400以上の場合はエラー処理にする
	// 2013/03/14 takeuchi
	// connectionDidFinishLoadingのエラーチェックにも引っかかって、2重ダイアログになってしまっていたのでコメントアウト
//	if(self.responseStatusCode >= 400){
//		[self performSelectorOnMainThread:@selector(connectionError) withObject:nil waitUntilDone:[NSThread isMainThread]];
//		return;
//	}
}

/**
	NSURLConnection通信でレスポンスを受信する度に呼ばれるデリゲート
	@param connection
	@param data
 */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	IS_CANCEL_OPERATION;
	
	long double readBytes = (long double)[data length];
	
	downloadTotalBytesLength += readBytes;
	
	UPDATE_DL_PROGRESS((long double)downloadTotalBytesLength / (long double)downloadExpectedContentLength);
	
	if (delegate && [delegate respondsToSelector:@selector(progressReceive:totalBytes:totalBytesExpected:withObject:)]) {
		[self mainThread:^{
			[delegate progressReceive:readBytes totalBytes:downloadTotalBytesLength totalBytesExpected:downloadExpectedContentLength withObject:self];
		}];
	}
	
	if (self.downloadProgressHandler) {
		[self mainThread:^{
			self.downloadProgressHandler((long double)[data length], (long double)downloadTotalBytesLength, (long double)downloadExpectedContentLength);
		}];
	}
	
	[async_data appendData:data];
}

/**
	NSURLConnectionエラー発生時に呼ばれるデリゲート（ドメインが存在しない場合などに呼ばれる）
	@param _connection
	@param _error 
 */
- (void)connection:(NSURLConnection *)_connection didFailWithError:(NSError *)_error {
	KTHTTP_LOG_METHOD;
	
	if (_error != nil) {
		error = _error;
	}
	
	[self performSelectorOnMainThread:@selector(connectionError) withObject:nil waitUntilDone:[NSThread isMainThread]];
}

/**
	NSURLConnection完了時に呼ばれるデリゲート
	@param _connection 
 */
- (void)connectionDidFinishLoading:(NSURLConnection *)_connection {
	KTHTTP_LOG_METHOD;
	
	if (responseStatusCode != 200) {
		[self performSelectorOnMainThread:@selector(connectionError) withObject:nil waitUntilDone:[NSThread isMainThread]];
		return;
	}
	
	UPDATE_DL_PROGRESS(1.0f);
	
	responseData = async_data;
	responseString = [self encodeWithData:[self responseData]];
	
	if ([self isJsonResponse] && [self responseData] != nil) {
		NSError *jsonError = nil;
		responseJSON = [NSJSONSerialization JSONObjectWithData:[self responseData]
													   options:NSJSONReadingMutableContainers //kNilOptions
														 error:&jsonError];
		if (jsonError) {
			KTHTTP_LOG(@"KTHttpRequest.json.error %@", [jsonError localizedDescription]);
		}
	}
	
	[self performSelectorOnMainThread:@selector(connectionSuccess) withObject:nil waitUntilDone:[NSThread isMainThread]];
}

/* ON MAIN THREAD */
// 通信開始時に必ず呼ばれるメソッド
- (void)connectionStart {
	KTHTTP_LOG_METHOD;
	
	IS_CANCEL_OPERATION;
	
	if (self.connectionStartHandler) {
		self.connectionStartHandler();
	}
	
	if (delegate && [delegate respondsToSelector:willStartSelector]) {
		[delegate performSelector:willStartSelector withObject:self afterDelay:0.0f];
	}
	
	if ([self showIndicator]) {
		[SVProgressHUD showWithStatus:self.indicatorMessage maskType:SVProgressHUDMaskTypeClear];
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	}
}

/* ON MAIN THREAD */
// HTTPヘッダ受信時に必ず呼ばれるメソッド（同期通信を除く）
- (void)connectionHeader {
	KTHTTP_LOG_METHOD;
	
	IS_CANCEL_OPERATION;
	
	if (self.connectionHeaderHandler) {
		self.connectionHeaderHandler();
	}
	
	if (delegate && [delegate respondsToSelector:didReceiveResponseHeadersSelector]) {
		[delegate performSelector:didReceiveResponseHeadersSelector withObject:self afterDelay:0.0f];
	}
}

/* ON MAIN THREAD */
// 通信エラー時に必ず呼ばれるメソッド
- (void)connectionError {
	KTHTTP_LOG_METHOD;
	
	[self dismissIndicator];
	
	IS_CANCEL_OPERATION;
	
	if (self.connectionFailHandler) {
		self.connectionFailHandler();
	}
	
	if (delegate && [delegate respondsToSelector:didFailSelector]) {
		[delegate performSelector:didFailSelector withObject:self afterDelay:0.0f];
	}
	
	[self finishOperation];
}

/* ON MAIN THREAD */
// 通信成功時に必ず呼ばれるメソッド
- (void)connectionSuccess {
	KTHTTP_LOG_METHOD;
	
	[self dismissIndicator];
	
	IS_CANCEL_OPERATION;
	
	if (self.connectionFinishHandler) {
		self.connectionFinishHandler();
	}
	
	if (delegate && [delegate respondsToSelector:didFinishSelector]) {
		[delegate performSelector:didFinishSelector withObject:self afterDelay:0.0f];
	}
	
	[self finishOperation];
}

// インジケータを非表示にします
- (void)dismissIndicator {
	if ([self showIndicator]) {
		if ([SVProgressHUD isVisible]) {
			[SVProgressHUD dismiss];
		}
		if ([UIApplication sharedApplication].isNetworkActivityIndicatorVisible) {
			[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		}
	}
}

// 認証用のAlertViewデリゲート
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 0) {
		[[_authenticationChallenge sender] cancelAuthenticationChallenge:_authenticationChallenge]; // 通信失敗
	} else if (buttonIndex == 1) {
		
		NSString *inputId = [[alertView textFieldAtIndex:0] text];
		NSString *inputPw = [[alertView textFieldAtIndex:1] text];
		
		if (delegate && [delegate respondsToSelector:@selector(authenticationChallengeInputId:inputPassword:)]) {
			[delegate authenticationChallengeInputId:inputId
									   inputPassword:inputPw];
		}
		
		[self retryingAuthenticationWithId:inputId
								  password:inputPw];
	}
}

/**
	認証のサイトでIDとパスワードを設定して再度アクセスする
	@param userId
	@param password 
 */
- (void)retryingAuthenticationWithId:(NSString *)userId password:(NSString *)password {
	
	IS_CANCEL_OPERATION;
	
	[self clear];
	
	NSURLCredential *credential = [NSURLCredential credentialWithUser:userId
															 password:password
														  persistence:NSURLCredentialPersistenceForSession]; // NSURLCredentialPersistenceNone:セッションで保存しない
	[[_authenticationChallenge sender] useCredential:credential forAuthenticationChallenge:_authenticationChallenge];
}

//-------------------------------------------------------------------------------------//
#pragma mark -- utilities --
//-------------------------------------------------------------------------------------//

/**
	URLエンコード
	@param string
	@returns 
 */
- (NSString*)encodeURL:(NSString *)string
{	
	return ((NSString*)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																				 (CFStringRef)string,
																				 NULL,
																				 (CFStringRef)@":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`",
																				 CFStringConvertNSStringEncodingToEncoding([self stringEncoding]))));
}

/**
	NSDataをNSStringに変換する
	@param _data
	@returns
 */
- (NSString *)encodeWithData:(NSData *)_data {
	
	int enc_arr[] = {
		NSUTF8StringEncoding,			// UTF-8
		NSShiftJISStringEncoding,		// Shift_JIS
		NSJapaneseEUCStringEncoding,	// EUC-JP
		NSISO2022JPStringEncoding,		// JIS
		NSUnicodeStringEncoding,		// Unicode
		NSASCIIStringEncoding			// ASCII
	};
	NSString *data_str = nil;
	int max = sizeof(enc_arr) / sizeof(enc_arr[0]);
	for (int i = 0; i < max; i++) {
		data_str = [
					[NSString alloc]
					initWithData:_data
					encoding:enc_arr[i]
					];
		if (data_str != nil) {
			break;
		}
	}
	return data_str;
}

/**
	指定した文字数分のランダム文字列を返す
	@param length
	@returns
 */
- (NSString *)randomStringWithLength:(int)length {
	NSString *ascii = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	int asciiLen = [ascii length];
	if (length > asciiLen) {
		length = asciiLen;
	}
	NSMutableString *resultStr = [NSMutableString stringWithCapacity:length];
	for (int i = 0; i < length; i++) {
		int randomNumber = arc4random_uniform(asciiLen);
		[resultStr appendString:[ascii substringWithRange:NSMakeRange(randomNumber, 1)]];
	}
	return resultStr;
}

/**
	渡したブロックをメインスレッドで処理します
	@param block 
 */
- (void)mainThread:(mainThreadProcessing)block {
	if ([NSThread isMainThread]) {
		block();
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			block();
		});
	}
}

//-------------------------------------------------------------------------------------//
#pragma mark -- Operating --
//-------------------------------------------------------------------------------------//

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString*)key
{
	if ([key isEqualToString:@"isExecuting"] ||
        [key isEqualToString:@"isFinished"])
    {
		return YES;
	}
	
	return [super automaticallyNotifiesObserversForKey:key];
}

- (BOOL)isConcurrent
{
	return YES;
}

- (BOOL)isExecuting
{
	return _isExecuting;
}

- (BOOL)isFinished
{
	return _isFinished;
}

- (void)start
{
	KTHTTP_LOG_METHOD;
	@autoreleasepool {
		// ダウンロードを開始する
		IS_CANCEL_OPERATION;
		
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"isExecuting"];
		[self startOperation];
	}
}

/**
	NSURLConnectionをキャンセルしてリリースする
 */
- (void)cancelConnection {
	KTHTTP_LOG_METHOD;
	
	if (connection) {
		[connection cancel];
		connection = nil;
		
		[self performSelectorOnMainThread:@selector(connectionError) withObject:nil waitUntilDone:[NSThread isMainThread]];
	}
}

/*
	queueがキャンセルされていた時の処理
 */
- (void)isCancelOperation {
	
	[cancelOperationLock lock];
	
	if ([self isCancelled] && !isCanceled) {
		
		isCanceled = YES;
		
		[cancelOperationLock unlock];
		
		[self cancelConnection];
		
		return;
	}
	[cancelOperationLock unlock];
}

/**
	オペレーションを終了させる
 */
- (void)finishOperation {
	KTHTTP_LOG_METHOD;
	
	// 開始してないなら一度開始させてから終了させる。（下記のメッセージが表示される為の対処）
	// *** went isFinished=YES without being started by the queue it is in
	if (![self isExecuting]) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"isExecuting"];
	}
	
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"isExecuting"];
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"isFinished"];
	
}

@end
