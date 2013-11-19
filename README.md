KTHttpRequest
=============

簡単な通信ライブラリです。

Required
-----------------
iOS5  
ARC  
[SVProgressHUD](https://github.com/samvermette/SVProgressHUD "SVProgressHUD")  

How to use simple
-----------------

    KTHttpRequest *request = [KTHttpRequest requestWithURL:[NSURL URLWithString:@"http://example.com/"]];
	
    __weak KTHttpRequest *weakObject = request;
	
  	[request setConnectionFinishBlock:^{
  		NSLog(@"通信成功");
  		NSLog(@"%@", weakObject.responseData);	 // NSData
  		NSLog(@"%@", weakObject.responseString); // NSString
  		NSLog(@"%@", weakObject.responseJSON);	 // JSON
  		NSLog(@"%@", weakObject.responseDictionaryByPostValue);	// NSDictionary
  	}];
  	[request setConnectionFailBlock:^{
  		NSLog(@"通信失敗 fail %d / error %@", weakObject.responseStatusCode, weakObject.error);
  	}];
  	
  	[request startAsynchronous];
	

Options
---------------
    
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
    @property (weak) UIProgressView *dlProgressView;	// ダウンロード進捗の更新を請け負います
    @property (weak) UIProgressView *ulProgressView;	// アップロード進捗の更新を請け負います
    
    etc...

