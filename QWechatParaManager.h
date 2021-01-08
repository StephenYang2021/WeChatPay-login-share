//
//  QWechatParaManager.h
//  LearnPublic
//
//  Created by Brother one on 2020/12/4.
//  Copyright © 2020 FZ. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QWechatParaManager : NSObject

- (id)Action_WeChatInit:(NSDictionary *)params;

- (id)Action_WeChatLogin:(NSDictionary *)params;

- (id)Action_isWeiXinInstall:(NSDictionary *)params;

- (id)Action_shareImage:(NSDictionary *)params;

- (id)Action_pay:(NSDictionary *)params;

@end

NS_ASSUME_NONNULL_END
