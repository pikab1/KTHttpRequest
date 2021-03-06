//
//  KTHttpRequest.h
//  Created by pikab1 on 1.3.7
//  
//  required iOS5,ARC
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, KTPostFormat) {
    KTMultipartFormDataPostFormat = 0,	// マルチパート
    KTURLEncodedPostFormat = 1			// POST
};

@protocol KTHttpRequestDelegate;

@interface KTHttpRequest : NSOperation 

// delegate and selector
@property (weak) NSObject <KTHttpRequestDelegate> *delegate;
@property (assign) SEL willStartSelector;									// 通信を開始する直前に呼び出すセレクタ
@property (assign) SEL didReceiveResponseHeadersSelector;					// ヘッダを受信した時点で呼び出すセレクタ
@property (assign) SEL didFinishSelector;									// 通信が成功した時点で呼び出すセレクタ
@property (assign) SEL didFailSelector;										// 通信が失敗した時点で呼び出すセレクタ
@property (assign) SEL didCancellSelector;									// 通信をキャンセルした時点で呼び出すセレクタ

// ReadOnly
@property (nonatomic, strong, readonly) NSData *responseData;				// NSData型のレスポンス
@property (nonatomic, readonly) NSString *responseString;					// NSString型のレスポンス
@property (nonatomic, readonly) id responseJSON;							// JSONに成形したレスポンス
@property (nonatomic, readonly) NSDictionary *responseDictionaryByPostValue;// key=valueのレスポンスをNSDictionaryに変換したレスポンス
@property (nonatomic, strong, readonly) NSError *error;						// NSURLConnectionのエラーを格納
@property (assign, readonly) int responseStatusCode;						// HTTPステータスコード

// Setting
@property (nonatomic) KTPostFormat postFormat;									// ポストのタイプを設定します					default:KTURLEncodedPostFormat
@property (nonatomic, setter=showIndicator:) BOOL showIndicator;				// インジケータの表示有無を設定します				default:NO
@property (nonatomic, strong) NSString *indicatorMessage;						// インジケータ内の文字列を設定します				default:通信中
@property (nonatomic) NSTimeInterval timeOutSeconds;							// タイムアウト時間を設定します					default:60.0f
@property (nonatomic, strong, setter=setHTTPMethod:) NSString *httpMethod;		// HTTPメソッドを設定します						default:POST
@property (nonatomic) NSURLRequestCachePolicy cachePolicy;						// キャッシュポリシーを設定します					default:キャッシュしない
@property (nonatomic, setter=showAuthenticationDialog:) BOOL showAuthenticationDialog;	// 認証が必要なサイトでダイアログを表示するか否か	defualt:NO
@property (nonatomic, strong) NSString *authenticationId;						// 認証ページのIDを設定します default:nil
@property (nonatomic, strong) NSString *authenticationPw;						// 認証ページのパスワードを設定します default:nil
@property (nonatomic) BOOL validatesSecureCertificate;							// SSL証明書をチェックするかどうかを設定します default:NO
@property (nonatomic) NSUInteger maxAuthenticationFailed;						// 認証ページの最大失敗許容回数 default:5
@property (nonatomic) int redirectionLimit;										// リダイレクト回数の制限 default:5
@property (nonatomic) BOOL writeCharset;										// リクエストヘッダにcharsetを設定するかどうか default:YES

// other
@property (assign) int tag;							// タグ
@property (weak) UIProgressView *dlProgressView;	// ダウンロード進捗の更新を請け負います
@property (weak) UIProgressView *ulProgressView;	// アップロード進捗の更新を請け負います

// create instance
- (id)initWithURL:(NSURL *)newURL;
+ (id)requestWithURL:(NSURL *)newURL;
+ (id)requestWithURLString:(NSString *)newURL;

/**
	同期通信を開始します
 */
//- (void)startSynchronous;

/**
	非同期通信を開始します
 */
- (void)startAsynchronous;

/**
	非同期通信をキャンセルします
 */
- (void)cancelConnection;

- (void)setUrl:(NSString *)url;		// 通信先を設定します
- (void)appendUrl:(NSString *)url;	// 通信先を追記します
- (NSString *)getUrl;				// 通信先を取得します
- (void)addParameter:(NSString *)value forKey:(NSString *)key;			// POSTならbody部に、GETならURLに、key=value形式で追加します
//- (void)addPostValue:(NSString *)value forKey:(NSString *)key;			// POSTならbody部に、GETならURLに、key=value形式で追加します
- (void)appendPostValue:(NSString *)value;								// body部にvalueをそのまま追加します
- (void)appendPostData:(NSData *)data;									// body部にdataをそのまま追加します
- (void)addData:(NSData *)data forKey:(NSString *)key;																			// マルチパートのデータを設定します。
- (void)addData:(NSData *)data withFileName:(NSString *)fileName andContentType:(NSString *)contentType forKey:(NSString *)key;	// マルチパートのデータを設定します。
- (void)addRequestHeader:(NSString *)header value:(NSString *)value;	// requestオブジェクトに対してRequestHeaderを設定します
- (NSDictionary *)allRequestHeaderFields;	// リクエストヘッダを返します
- (NSDictionary *)allHeaderFields;			// レスポンスヘッダを返します

// 通信を開始する直前に時点で呼ばれるBlock
- (void)setConnectionStartBlock:(void(^)(void))block;	/* ON MAIN THREAD */

// ヘッダを受信した時点で呼び出すBlock
- (void)setConnectionHeaderBlock:(void(^)(void))block;	/* ON MAIN THREAD */

// 通信が成功した時点で呼び出すBlock
- (void)setConnectionFinishBlock:(void(^)(void))block;	/* ON MAIN THREAD */

// 通信が失敗した時点で呼び出すBlock
- (void)setConnectionFailBlock:(void(^)(void))block;	/* ON MAIN THREAD */

// 通信をキャンセルした時点で呼び出すBlock
- (void)setConnectionCancellBlock:(void(^)(void))block;	/* ON MAIN THREAD */

// アップロード進捗を返すBlock
- (void)setUploadProgressBlock:(void (^)(long double bytes, long double totalBytes, long double totalBytesExpected))block;		/* ON MAIN THREAD */

// ダウンロード進捗を返すBlock
- (void)setDownloadProgressBlock:(void (^)(long double bytes, long double totalBytes, long double totalBytesExpected))block;	/* ON MAIN THREAD */

// 通信開始／ヘッダ受信／通信成功／通信失敗／それぞれのタイミングで別処理を行う場合はこれらをOVERRIDEする
- (void)connectionStart __attribute__((objc_requires_super));		/* ON MAIN THREAD */
- (void)connectionHeader __attribute__((objc_requires_super));		/* ON MAIN THREAD */
- (void)connectionSuccess __attribute__((objc_requires_super));		/* ON MAIN THREAD */
- (void)connectionError __attribute__((objc_requires_super));		/* ON MAIN THREAD */

- (void)settingRequest;		/* ON SUB THREAD */
- (void)finishOperation;	/* ON SUB THREAD */

@end

@protocol KTHttpRequestDelegate <NSObject>

@optional

/*
	アップロード進捗を返すデリゲート
*/
/* ON MAIN THREAD */
- (void)progressSend:(long double)bytes totalBytes:(long double)totalBytes totalBytesExpected:(long double)totalBytesExpected withObject:(KTHttpRequest *)object;

/*
	ダウンロード進捗を返すデリゲート
*/
/* ON MAIN THREAD */
- (void)progressReceive:(long double)bytes totalBytes:(long double)totalBytes totalBytesExpected:(long double)totalBytesExpected withObject:(KTHttpRequest *)object;

/**
	認証の必要なURLにアクセスした際のデリゲート
	@param connection
	@param challenge
	@param object 
	@returns [NSArray arrayWithObjects:@"id", @"pass", nil];
	@returns nil 通信エラー
	@returns KTAuthenticationChallengeSkip 次の認証方法へ移行
 */
extern NSString *const KTAuthenticationChallengeSkip;
/* ON MAIN THREAD */
- (id)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge withObject:(KTHttpRequest *)object;

/**
	認証ダイアログで入力されたIDとPASSを返す
	@param inputId
	@param inputPassword
 */
/* ON MAIN THREAD */
- (void)authenticationChallengeInputId:(NSString *)inputId inputPassword:(NSString *)inputPassword;

@end
