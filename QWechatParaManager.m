//
//  QWechatParaManager.m
//  LearnPublic
//
//  Created by Brother one on 2020/12/4.
//  Copyright © 2020 FZ. All rights reserved.
//

#import "QWechatParaManager.h"
#import "QWechatManager.h"

typedef void (^loginResultBlock)(NSDictionary * info);
@implementation QWechatParaManager

- (id)Action_WeChatInit:(NSDictionary *)params {
    NSString *appId = [params objectForKey:@"appId"];
    NSString *appSecret = [params objectForKey:@"appSecret"];
    NSString *universalLink = [params objectForKey:@"universalLink"];
    [[QWechatManager shareInstance] initSDKWithAppId:appId appSecret:appSecret universalLink:universalLink];
    return nil;
}

- (id)Action_WeChatLogin:(NSDictionary *)params {
    UIViewController *viewController = [params objectForKey:@"viewController"];
    loginResultBlock block = [params objectForKey:@"completion"];
    [[QWechatManager shareInstance] sendWeixinLoginRequestWithViewController:viewController resultBlock:^(NSDictionary * _Nonnull userInfo) {
        if (block) {
            block(userInfo);
        }
    }];
    return nil;
}

- (id)Action_isWeiXinInstall:(NSDictionary *)params {
    return @([[QWechatManager shareInstance] isWeiXinInstall]);
}

- (id)Action_shareImage:(NSDictionary *)params {
    id image = [params objectForKey:@"image"];
    int scene = [[params objectForKey:@"scene"] intValue];
    [[QWechatManager shareInstance] shareToImage:image scene:scene];
    return nil;
}

- (id)Action_shareVideo:(NSDictionary *)params {
    NSString *title = [params objectForKey:@"title"];
    NSString *description = [params objectForKey:@"description"];
    NSString *videoUrl = [params objectForKey:@"videoUrl"];
    NSString *videoLowBandUrl = [params objectForKey:@"videoLowBandUrl"];
    id thumbImage = [params objectForKey:@"thumbImage"];
    int scene = [[params objectForKey:@"scene"] intValue];
    id completion = [params objectForKey:@"completion"];
    [[QWechatManager shareInstance] shareVideoWithTitle:title description:description videoUrl:videoUrl videoLowBandUrl:videoLowBandUrl thumbImage:thumbImage scene:scene completion:completion];
    return nil;
}

- (id)Action_pay:(NSDictionary *)params {
    NSString *openID = [params objectForKey:@"appid"];
    NSString *partnerId = [params objectForKey:@"partnerid"];
    NSString *prepayId = [params objectForKey:@"prepayid"];
    NSString *nonceStr = [params objectForKey:@"noncestr"];
    NSString *timeStamp = [params objectForKey:@"timestamp"];
    NSString *package = [params objectForKey:@"package"];
    NSString *sign = [params objectForKey:@"sign"];
    UIViewController *viewController = [params objectForKey:@"viewController"];
    id resultBlock = [params objectForKey:@"resultBlock"];
    [[QWechatManager shareInstance] payForWechat:openID partnerId:partnerId prepayId:prepayId nonceStr:nonceStr timeStamp:timeStamp package:package sign:sign viewController:viewController resultBlock:resultBlock];
    return nil;
}

@end
