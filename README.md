# QWechatManager

微信支付，微信分享，微信登录

1.第一步，导入头文件  #import "QWechatManager.h"

2.AppDelegate 中注册方法didFinishLaunchingWithOptions中
[[QWechatManager shareInstance] initSDKWithAppId:@"wxdd6619e99fb****" appSecret:@"2e3bdb5505f7f10******745e3c23c6" universalLink:@"https://api.xueyouxuele.com/.well-known/"];

3.AppDelegate 中代理 - (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options；
return  [[QWechatManager shareInstance] handleOpenURL:url];

4.在需要登录分享或支付的地方直接单例调用调用封装方法：
分享朋友圈：[[QWechatManager shareInstance] shareToSceneTimelineWithTitle:_shareTitle content:_shareContent url:_shareUrl image:_shareImage];
分享微信好友：[[QWechatManager shareInstance] shareToWeixinFriendWithTitle:_shareTitle content:_shareContent url:_shareUrl image:_shareImage];
微信支付：                [[QWechatManager shareInstance] payForWechat:payModel.appid partnerId:payModel.partnerid prepayId:payModel.prepayid nonceStr:payModel.noncestr timeStamp:payModel.timestamp package:payModel.package sign:payModel.sign viewController:self resultBlock:^(NSNumber * _Nonnull errCode) {}];

5.备选方法：
/// 初始化微信SDK
/// @param appId 微信平台申请的appId
/// @param appSecret 微信平台申请的AppSecret
/// @param universalLink 唤起App的通用链接universalLink
- (void)initSDKWithAppId:(NSString *)appId appSecret:(NSString *)appSecret universalLink:(NSString *)universalLink;


/// 微信打开其他app的回调
/// @param url 微信启动第三方应用时传递过来的url
- (BOOL)handleOpenURL:(NSURL *)url;


/// 查看当前App是否已安装微信
- (BOOL)isWeiXinInstall;

/// 处理微信通过Universal Link启动App时传递的数据
- (BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;


/// 调用微信登录接口
/// @param viewController 传入当前app的viewController
/// @param resultBlock 回调
- (void)sendWeixinLoginRequestWithViewController:(UIViewController *)viewController resultBlock:(void (^) (NSDictionary *userInfo))resultBlock;

/// 分享到微信好友
/// @param title title
/// @param content content
/// @param url url
/// @param image 图片
- (void)shareToWeixinFriendWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url image:(id)image;


/// 分享到微信朋友圈
/// @param title title
/// @param content content
/// @param url url
/// @param image 图片
- (void)shareToSceneTimelineWithTitle:(NSString *)title content:(NSString *)content url:(NSString *)url image:(id)image;


/// 微信支付
/// @param openID   微信开放平台审核通过的应用APPID
/// @param partnerId   微信支付分配的商户号
/// @param prepayId   微信返回的支付交易会话ID
/// @param nonceStr   随机字符串，不长于32位。推荐随机数生成算法
/// @param timeStamp   时间戳，请见接口规则-参数规定
/// @param package  暂填写固定值Sign=WXPay
/// @param sign   签名，详见签名生成算法注意：签名方式一定要与统一下单接口使用的一致
/// @param viewController   传入当前app的viewController
/// @param resultBlock   回调
- (void)payForWechat:(NSString *)openID partnerId:(NSString *)partnerId prepayId:(NSString *)prepayId nonceStr:(NSString *)nonceStr timeStamp:(NSString *)timeStamp package:(NSString *)package sign:(NSString *)sign viewController:(UIViewController *)viewController resultBlock:(void (^) (NSNumber *errCode))resultBlock;

/** 分享图片到： 0聊天界面 1朋友圈 2收藏 3指定联系人
 参数scene : 请求发送场景 枚举
 WXSceneSession          = 0,         聊天界面
 WXSceneTimeline         = 1,         朋友圈
 WXSceneFavorite         = 2,          收藏
 WXSceneSpecifiedSession = 3,   指定联系人
  */
- (void)shareToImage:(id)image scene:(int)scene;

/** 分享视频到  0聊天界面 1朋友圈 2收藏 3指定联系人
 参数scene : 请求发送场景 枚举
 WXSceneSession          = 0,         聊天界面
 WXSceneTimeline         = 1,         朋友圈
 WXSceneFavorite         = 2,          收藏
 WXSceneSpecifiedSession = 3,   指定联系人
 */
- (void)shareVideoWithTitle:( NSString * _Nullable )title description:(NSString * _Nullable )description videoUrl:(NSString *)videoUrl videoLowBandUrl:(NSString * _Nullable)videoLowBandUrl thumbImage:(id _Nullable)thumbImage scene:(int)scene completion:(void (^ __nullable)(BOOL success))completion;

6.补充说明：使用前先导入微信SDK，我是直接使用了pod  ----pod 'WechatOpenSDK', '~> 1.8.7.1'



