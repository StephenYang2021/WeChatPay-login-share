//
//  QWechatManager.m
//  LearnPublic
//
//  Created by Brother one on 2020/12/4.
//  Copyright © 2020 FZ. All rights reserved.
//

#import "QWechatManager.h"
#import "WXApi.h"

#define Weixin_GetAccessTokenURL    @"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code"
#define Weixin_isAccessTokenCanUse     @"https://api.weixin.qq.com/sns/auth?access_token=%@&openid=%@"
#define Weixin_UseRefreshToken      @"https://api.weixin.qq.com/sns/oauth2/refresh_token?appid=%@&grant_type=refresh_token&refresh_token=%@"
#define Weixin_GetUserInformation  @"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@"


@interface QWechatManager () <WXApiDelegate>

@property (nonatomic, copy) NSString *appId;

@property (nonatomic, copy) NSString *appSecret;

@property (nonatomic, strong) NSMutableDictionary * userInfo;

@property (nonatomic, copy) void (^WeChatLoginBlock) (NSDictionary *userInfo);

@property (nonatomic, copy) void (^WeChatPayResultBlock)(NSNumber *errCode);///0:支付成功 -2:中途退出 其他:支付失败

@end
@implementation QWechatManager

static NSURL *safeURL(NSString *origin) {
    NSCharacterSet *encodeUrlSet = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *encodeUrl = [origin stringByAddingPercentEncodingWithAllowedCharacters:encodeUrlSet];
    return [NSURL URLWithString:encodeUrl];
}

+ (instancetype)shareInstance {
    static QWechatManager *weChatSDK;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        weChatSDK = [[QWechatManager allocWithZone:nil] init];
    });
    return weChatSDK;
}

/// 初始化微信SDK
- (void)initSDKWithAppId:(NSString *)appId appSecret:(NSString *)appSecret universalLink:(NSString *)universalLink {
    _appId = appId;
    _appSecret = appSecret;
    [WXApi registerApp:appId universalLink:universalLink];
}

/// 微信打开其他app的回调
- (BOOL)handleOpenURL:(NSURL *)url {
    [WXApi handleOpenURL:url delegate:self];
    return YES;
}

/// 查看微信是否安装
- (BOOL)isWeiXinInstall {
    return [WXApi isWXAppInstalled] || [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"weixin://"]] || [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"Whatapp://"]];
}

/// 处理微信通过Universal Link启动App时传递的数据
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    return [WXApi handleOpenUniversalLink:userActivity delegate:self];
    
}


#pragma mark - WXApiDelegate

/// 收到一个来自微信的处理结果。调用一次sendReq后会收到onResp。可能收到的处理结果有SendMessageToWXResp、SendAuthResp等。
/// @param resp  具体的回应内容，是自动释放的
- (void)onResp:(BaseResp *)resp {
    if ([resp isKindOfClass:[SendAuthResp class]]) {// 微信登录
        if (resp.errCode == 0) {// 登录成功
            [self loginWeixinSuccessWithBaseResp:resp];
            NSLog(@"====成功====");
        }else {// 登录失败
            NSLog(@"====失败====");

        }
    }
    if ([resp isKindOfClass:[PayResp class]]) {// 微信支付
        PayResp *response = (PayResp *)resp;
        if (self.WeChatPayResultBlock) {
            self.WeChatPayResultBlock(@(response.errCode));
        }
    }
}

- (void)onReq:(BaseReq *)req {
    
}

#pragma mark - 微信登录成功获取token
- (void)loginWeixinSuccessWithBaseResp:(BaseResp *)resp {
    SendAuthResp *auth = (SendAuthResp *)resp;
    NSString *code = auth.code;
    //Weixin_AppID和Weixin_AppSecret是微信申请下发的.
    [self.userInfo setObject:@"weixin" forKey:@"oauthName"];
    NSString *str = [NSString stringWithFormat:Weixin_GetAccessTokenURL,_appId,_appSecret,code];
    __weak typeof(self)wself = self;
    [self getRequestWithUrl:[NSURL URLWithString:str] success:^(NSDictionary *responseDict) {
        NSString *access_token = responseDict[@"access_token"];
        NSString *refresh_token = responseDict[@"refresh_token"];
        NSString *openid = responseDict[@"openid"];
        NSString *unionid = [responseDict objectForKey:@"unionid"];
        if (unionid) {
            [wself.userInfo setObject:unionid forKey:@"unionid"];
        }
        [wself isAccessTokenCanUseWithAccessToken:access_token openID:openid completionHandler:^(BOOL isCanUse) {
            if (isCanUse) {
                [wself getUserInformationWithAccessToken:access_token openID:openid];
            }else{
                [wself useRefreshToken:refresh_token];
            }
        }];
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
    }];
    
}

/// 获取appstore上app的信息
- (void)getRequestWithUrl:(NSURL *)url success:(void (^) (NSDictionary *responseDict))success failure:(void (^) (NSError *error))failure {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                if (success) success(responseDict);
            }else {
                if (failure) failure(error);
            }
        });
    }];
    [dataTask resume];
}

#pragma mark - 判断access_token是否过期
- (void)isAccessTokenCanUseWithAccessToken:(NSString *)accessToken openID:(NSString *)openID completionHandler:(void(^)(BOOL isCanUse))completeHandler {
    NSString *strOfSeeAccess_tokenCanUse = [NSString stringWithFormat:Weixin_isAccessTokenCanUse, accessToken, openID];
    [self getRequestWithUrl:[NSURL URLWithString:strOfSeeAccess_tokenCanUse] success:^(NSDictionary *responseDict) {
        if ([responseDict[@"errmsg"] isEqualToString:@"ok"]) {
            completeHandler(YES);
        }else{
            completeHandler(NO);
        }
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
        completeHandler(NO);
    }];
}

#pragma mark - 若未过期,获取用户信息
- (void)getUserInformationWithAccessToken:(NSString *)access_token openID:(NSString *)openID {
    if (access_token) {
        [self.userInfo setObject:access_token forKey:@"accessToken"];
    }
    if (openID) {
        [self.userInfo setObject:openID forKey:@"openid"];
    }
    __weak typeof(self) wself = self;
    NSString *strOfGetUserInformation = [NSString stringWithFormat:Weixin_GetUserInformation, access_token, openID];
    [self getRequestWithUrl:[NSURL URLWithString:strOfGetUserInformation] success:^(NSDictionary *responseDict) {
        NSString *nickname = responseDict[@"nickname"];
        NSString *headimgurl = responseDict[@"headimgurl"];
        NSNumber *sexnumber = responseDict[@"sex"];
        NSString *sexstr = [NSString stringWithFormat:@"%@",sexnumber];
        NSString *sex;
        if ([sexstr isEqualToString:@"1"]) {
            sex = @"男";
        }else if ([sexstr isEqualToString:@"2"]){
            sex = @"女";
        }else{
            sex = @"未知";
        }
        [wself.userInfo setObject:sex forKey:@"sex"];
        if (nickname) {
            [wself.userInfo setObject:nickname forKey:@"nickname"];
        }
        if (headimgurl) {
            [wself.userInfo setObject:headimgurl forKey:@"icon"];
        }
        if (wself.WeChatLoginBlock) {
            wself.WeChatLoginBlock(wself.userInfo);
        }
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
    }];
}

#pragma mark - 若过期,使用refresh_token获取新的access_token
- (void)useRefreshToken:(NSString *)refreshToken {
    NSString *strOfUseRefreshToken = [NSString stringWithFormat:Weixin_UseRefreshToken, _appId, refreshToken];
    __weak typeof(self) wself = self;
    [self getRequestWithUrl:[NSURL URLWithString:strOfUseRefreshToken] success:^(NSDictionary *responseDict) {
        NSString *openid = responseDict[@"openid"];
        NSString *access_token = responseDict[@"access_token"];
        NSString *refresh_tokenNew = responseDict[@"refresh_token"];
        [wself isAccessTokenCanUseWithAccessToken:access_token openID:openid completionHandler:^(BOOL isCanUse) {
            if (isCanUse) {
                [wself getUserInformationWithAccessToken:access_token openID:openid];
            }else{
                [wself useRefreshToken:refresh_tokenNew];
            }
        }];
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
    }];
}

/// 调用微信登录接口
- (void)sendWeixinLoginRequestWithViewController:(UIViewController *)viewController resultBlock:(void (^)(NSDictionary * _Nonnull))resultBlock {
    _WeChatLoginBlock = resultBlock;
    SendAuthReq *req = [[SendAuthReq alloc] init];
    req.scope = @"snsapi_userinfo";
    req.state = @"manjiwang";
    if ([self isWeiXinInstall]) {
        [WXApi sendReq:req completion:nil];
    }else {
        [WXApi sendAuthReq:req viewController:viewController delegate:self completion:nil];
    }
}

/// 分享到微信好友
- (void)shareToWeixinFriendWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url image:(id)image {
    [self shareWithTitle:title content:content url:url image:image scene:WXSceneSession];
}

/// 分享到微信朋友圈
- (void)shareToSceneTimelineWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url image:(id)image {
    [self shareWithTitle:title content:content url:url image:image scene:WXSceneTimeline];
}

/**
 参数scene : 请求发送场景 枚举
 WXSceneSession          = 0,         聊天界面
 WXSceneTimeline         = 1,         朋友圈
 WXSceneFavorite         = 2,          收藏
 WXSceneSpecifiedSession = 3,   指定联系人
 */
- (void)shareWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url image:(id)image scene:(int)scene {
    WXWebpageObject *webpageObjcet = [WXWebpageObject object];
    webpageObjcet.webpageUrl = url;
    
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = title;
    message.description = content;
    
    UIImage *imageObject;
    NSURL *imageUrl;
    
    if ([image isKindOfClass:[UIImage class]]) {
        imageObject = image;
    }else if ([image isKindOfClass:[NSData class]]) {
        imageObject = [UIImage imageWithData:image];
    }else if ([image isKindOfClass:[NSString class]]) {
        imageUrl = safeURL(image);
    }else if ([image isKindOfClass:[NSURL class]]) {
        imageUrl = image;
    }
    if (imageObject) {
        [message setThumbImage:imageObject];
    }
    if (imageUrl) {
        dispatch_queue_t globalQueue = dispatch_get_global_queue(0, 0);
        dispatch_async(globalQueue, ^{//异步下载图片
            NSData *data = [NSData dataWithContentsOfURL:imageUrl];
            UIImage *image = [UIImage imageWithData:data];
            if (image != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{//回到主线程刷新UI
                    [message setThumbImage:[self compressImage:image toByte:32765]];
                    message.mediaObject = webpageObjcet;
                    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
                    req.bText = NO;
                    req.message = message;
                    req.scene = scene;
                    [WXApi startLogByLevel:WXLogLevelNormal logBlock:^(NSString * _Nonnull log) {
                        NSLog(@"~~~~~~~~~~~~ %@ ~~~~~~~~~~~~~~",log);
                    }];
                    [WXApi sendReq:req completion:nil];
                });
            }else {
                NSLog(@"图片下载出现错误!");
            }
        });
        return;
    }
    message.mediaObject = webpageObjcet;
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = scene;
    [WXApi sendReq:req completion:nil];
}

#pragma mark - 压缩图片
- (UIImage *)compressImage:(UIImage *)image toByte:(NSUInteger)maxLength {
    // Compress by quality
    CGFloat compression = 1;
    NSData *data = UIImageJPEGRepresentation(image, compression);
    if (data.length < maxLength) return image;
    
    CGFloat max = 1;
    CGFloat min = 0;
    for (int i = 0; i < 6; ++i) {
        compression = (max + min) / 2;
        data = UIImageJPEGRepresentation(image, compression);
        if (data.length < maxLength * 0.9) {
            min = compression;
        } else if (data.length > maxLength) {
            max = compression;
        } else {
            break;
        }
    }
    UIImage *resultImage = [UIImage imageWithData:data];
    if (data.length < maxLength) return resultImage;
    
    // Compress by size
    NSUInteger lastDataLength = 0;
    while (data.length > maxLength && data.length != lastDataLength) {
        lastDataLength = data.length;
        CGFloat ratio = (CGFloat)maxLength / data.length;
        CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
                                 (NSUInteger)(resultImage.size.height * sqrtf(ratio))); // Use NSUInteger to prevent white blank
        UIGraphicsBeginImageContext(size);
        [resultImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
        resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        data = UIImageJPEGRepresentation(resultImage, compression);
    }
    
    return resultImage;
}

/// 分享图片到： 0聊天界面 1朋友圈 2收藏 3指定联系人
- (void)shareToImage:(id)image scene:(int)scene {
    NSData *imageData;
    NSURL *imageUrl;
    if ([image isKindOfClass:[UIImage class]]) {
        imageData = UIImageJPEGRepresentation(image, 1);;
    }else if ([image isKindOfClass:[NSData class]]) {
        imageData = image;
    }else if ([image isKindOfClass:[NSString class]]) {
        imageUrl = safeURL((NSString *)image);
    }else if ([image isKindOfClass:[NSURL class]]) {
        imageUrl = image;
    }
    if (imageData) {
        [self shareImageDataToImage:imageData scene:scene];
        return;
    }
    if (imageUrl) {
        dispatch_queue_t globalQueue = dispatch_get_global_queue(0, 0);
        dispatch_async(globalQueue,^{
            NSData *data = [NSData dataWithContentsOfURL:imageUrl];
            if (data) {
                [self shareImageDataToImage:data scene:scene];
            }else {
                NSLog(@"图片下载出现错误");
            }
        });
    }
}

- (void)shareImageDataToImage:(NSData *)imageData scene:(int)scene {
    WXImageObject *imageObject = [WXImageObject object];
    imageObject.imageData = imageData;
    WXMediaMessage *message = [WXMediaMessage message];
//    UIImage *image = [UIImage imageWithData:imageData];
//    UIImage *thumbImage =  [self compressImage:image toByte:192];
//    NSData *thumbData = UIImageJPEGRepresentation(thumbImage, 1);
//    message.thumbData = nil;
    message.mediaObject = imageObject;

    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = scene;
    [WXApi sendReq:req completion:^(BOOL success) {
        NSLog(@"%@", success?@"YES":@"NO");
    }];
}

/// 视频分享
- (void)shareVideoWithTitle:( NSString * _Nullable )title description:(NSString * _Nullable )description videoUrl:(NSString *)videoUrl videoLowBandUrl:(NSString * _Nullable)videoLowBandUrl thumbImage:(id _Nullable)thumbImage scene:(int)scene completion:(void (^ __nullable)(BOOL success))completion; {
    WXVideoObject *videoObject = [WXVideoObject object];
    videoObject.videoUrl = videoUrl;
    if (videoLowBandUrl) {
        videoObject.videoLowBandUrl = videoLowBandUrl;
    }
    WXMediaMessage *message = [WXMediaMessage message];
    if (title) {
        message.title = title;
    }
    if (description) {
        message.description = description;
    }
    UIImage *imageObject;
    NSURL *imageUrl;
    if (!thumbImage) {
        SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
        req.bText = NO;
        req.message = message;
        req.scene = scene;
        [WXApi sendReq:req completion:^(BOOL success) {
            if (completion) {
                completion(success);
            }
        }];
        return;
    }
    if ([thumbImage isKindOfClass:[UIImage class]]) {
        imageObject = thumbImage;
    }else if ([thumbImage isKindOfClass:[NSData class]]) {
        imageObject = [UIImage imageWithData:thumbImage];
    }else if ([thumbImage isKindOfClass:[NSString class]]) {
        imageUrl = safeURL(thumbImage);
    }else if ([thumbImage isKindOfClass:[NSURL class]]) {
        imageUrl = thumbImage;
    }
    if (imageObject) {
        [message setThumbImage:imageObject];
    }
    if (imageUrl) {
        dispatch_queue_t globalQueue = dispatch_get_global_queue(0, 0);
        dispatch_async(globalQueue,^{
            NSData *data = [NSData dataWithContentsOfURL:imageUrl];
            UIImage *image = [UIImage imageWithData:data];
            if(image != nil){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [message setThumbImage:[self compressImage:image toByte:32765]];
                    message.mediaObject = videoObject;
                    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
                    req.bText = NO;
                    req.message = message;
                    req.scene = scene;
                    [WXApi sendReq:req completion:^(BOOL success) {
                        if (completion) {
                            completion(success);
                        }
                    }];
                });
            } else{
                SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
                req.bText = NO;
                req.message = message;
                req.scene = scene;
                [WXApi sendReq:req completion:^(BOOL success) {
                    if (completion) {
                        completion(success);
                    }
                }];
            }
        });
    }
}

/// 微信支付
- (void)payForWechat:(NSString *)openID partnerId:(NSString *)partnerId prepayId:(NSString *)prepayId nonceStr:(NSString *)nonceStr timeStamp:(NSString *)timeStamp package:(NSString *)package sign:(NSString *)sign viewController:(UIViewController *)viewController resultBlock:(void(^)(NSNumber *errCode))resultBlock {
    _WeChatPayResultBlock = resultBlock;
    if ([self isWeiXinInstall]) {
        PayReq *req = [[PayReq alloc] init];
        req.openID = openID;
        req.partnerId = partnerId;
        req.prepayId = prepayId;
        req.nonceStr = nonceStr;
        req.timeStamp = timeStamp.intValue;
        req.package = package;
        req.sign = sign;
        [WXApi sendReq:req completion:nil];
    }else {
        SendAuthReq *req = [[SendAuthReq alloc] init];
        req.scope = @"snsapi_userinfo";
        req.state = @"manjiwang";
        [WXApi sendAuthReq:req viewController:viewController delegate:self completion:nil];
    }
}

- (NSMutableDictionary *)userInfo {
    if (!_userInfo) {
        _userInfo = [NSMutableDictionary dictionary];
    }
    return _userInfo;
}

@end
