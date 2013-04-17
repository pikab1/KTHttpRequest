//
//  KTHttpRequest.h
//  Created by pikab1 on 1.3.0
//  
//  required iOS5,ARC
//

#import <Foundation/Foundation.h>

typedef enum {
    KTMultipartFormDataPostFormat = 0,	// マルチパート
    KTURLEncodedPostFormat = 1			// POST
} KTPostFormat;

@protocol KTHttpRequestDelegate;

@interface KTHttpRequest : NSOperation 

// delegate and selector
@property (weak) NSObject <KTHttpRequestDelegate> *delegate;
@property (assign) SEL didReceiveResponseHeadersSelector;					// ヘッダを受信した時点で呼び出すセレクタ
@property (assign) SEL didFinishSelector;									// 通信が成功した時点で呼び出すセレクタ
@property (assign) SEL didFailSelector;										// 通信が失敗した時点で呼び出すセレクタ

// ReadOnly
@property (nonatomic, strong, readonly) NSData *responseData;				// NSData型のレスポンス
@property (nonatomic, strong, readonly) NSString *responseString;			// NSString型のレスポンス
@property (nonatomic, strong, readonly) NSMutableDictionary *responseJSON;	// JSONに成形したレスポンス
@property (nonatomic, strong, readonly) NSError *error;						// NSURLConnectionのエラーを格納
@property (assign, readonly) int responseStatusCode;						// HTTPステータスコード

// Setting
@property (nonatomic) KTPostFormat postFormat;									// ポストのタイプを設定します					default:KTURLEncodedPostFormat
@property (nonatomic, setter=showIndicator:) BOOL showIndicator;				// インジケータの表示有無を設定します				default:NO
@property (nonatomic, setter=isJsonResponse:) BOOL isJsonResponse;				// レスポンスをJSONパースするかどうかを設定します	default:NO
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

// other
@property (assign) int tag;							// タグ
@property (weak) UIProgressView *dlProgressView;	// ダウンロード進捗の更新を請け負います
@property (weak) UIProgressView *ulProgressView;	// アップロード進捗の更新を請け負います

// create instance
- (id)initWithURL:(NSURL *)newURL;
+ (id)requestWithURL:(NSURL *)newURL;

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
- (NSString *)getUrl;				// 通信先を取得します
- (void)addPostValue:(NSString *)value forKey:(NSString *)key;			// body部にkey=value形式で追加します
- (void)appendPostValue:(NSString *)value;								// body部にvalueをそのまま追加します
- (void)appendPostData:(NSData *)data;									// body部にdataをそのまま追加します
- (void)addData:(NSData *)data forKey:(NSString *)key;																			// マルチパートのデータを設定します。
- (void)addData:(NSData *)data withFileName:(NSString *)fileName andContentType:(NSString *)contentType forKey:(NSString *)key;	// マルチパートのデータを設定します。
- (void)addRequestHeader:(NSString *)header value:(NSString *)value;	// requestオブジェクトに対してRequestHeaderを設定します
- (NSDictionary *)allHeaderFields;	// レスポンスヘッダを返します

// タスクが開始した時点で呼び出すBlock
- (void)setTaskStartBlock:(void(^)(void))block;

// タスクが終了した時点で呼び出すBlock
- (void)setTaskFinishBlock:(void(^)(void))block;

// タスクがキャンセルされた時点で呼び出すBlock
- (void)setTaskCancelBlock:(void(^)(void))block;

// ヘッダを受信した時点で呼び出すBlock
- (void)setConnectionHeaderBlock:(void(^)(void))block;

// 通信が成功した時点で呼び出すBlock
- (void)setConnectionFinishBlock:(void(^)(void))block;

// 通信が失敗した時点で呼び出すBlock
- (void)setConnectionFailBlock:(void(^)(void))block;

// アップロード進捗を返すBlock
- (void)setUploadProgressBlock:(void (^)(long double bytes, long double totalBytes, long double totalBytesExpected))block;

// ダウンロード進捗を返すBlock
- (void)setDownloadProgressBlock:(void (^)(long double bytes, long double totalBytes, long double totalBytesExpected))block;

// 通信開始／ヘッダ受信／通信成功／通信失敗／それぞれのタイミングで別処理を行う場合はこれらをOVERRIDEする
/* ON MAIN THREAD */
- (void)connectionStart;
- (void)connectionHeader;
- (void)connectionSuccess;
- (void)connectionError;

/* ON SUB THREAD */
- (void)settingRequest;
- (void)finishOperation;

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
