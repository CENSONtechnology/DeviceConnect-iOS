//
//  DPChromecastMediaPlayerProfile.m
//  DConnectSDK
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DPChromecastManager.h"
#import "DPChromecastMediaPlayerProfile.h"
#import "DPChromecastDevicePlugin.h"
#import <GoogleCast/GoogleCast.h>


@interface DPChromecastMediaPlayerProfile()

@end

@implementation DPChromecastMediaPlayerProfile

- (id)init
{
    self = [super init];
    if (self) {
        self.delegate = self;
    }
    return self;
}

// 共通リクエスト処理
- (BOOL)handleRequest:(DConnectRequestMessage *)request
             response:(DConnectResponseMessage *)response
             serviceId:(NSString *)serviceId
             callback:(void(^)())callback
{
    // パラメータチェック
    if (serviceId == nil) {
        [response setErrorToEmptyServiceId];
        return YES;
    }
    
    // 接続＆メッセージクリア
    DPChromecastManager *mgr = [DPChromecastManager sharedManager];
    [mgr connectToDeviceWithID:serviceId completion:^(BOOL success, NSString *error) {
        if (success) {
            callback();
            [response setResult:DConnectMessageResultTypeOk];
        } else {
            // エラー
            [response setErrorToNotFoundService];
        }
        [[DConnectManager sharedManager] sendResponse:response];
    }];
    return NO;
}


#pragma mark - Get Methods

// 再生状態取得リクエストを受け取った
- (BOOL)               profile:(DConnectMediaPlayerProfile *)profile
didReceiveGetPlayStatusRequest:(DConnectRequestMessage *)request
                      response:(DConnectResponseMessage *)response
                      serviceId:(NSString *)serviceId
{
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 再生状態取得
                NSString *status = [[DPChromecastManager sharedManager] mediaPlayerStateWithID:serviceId];
                [response setString:status forKey:@"status"];
            }];
}

// コンテンツ情報取得リクエストを受け取った
- (BOOL)          profile:(DConnectMediaPlayerProfile *)profile
didReceiveGetMediaRequest:(DConnectRequestMessage *)request
                 response:(DConnectResponseMessage *)response
                 serviceId:(NSString *)serviceId
                  mediaId:(NSString *)mediaId
{
    response.result = DConnectMessageResultTypeOk;
    [DConnectMediaPlayerProfile setMIMEType:@"video/mov" target:response];
    [DConnectMediaPlayerProfile setTitle:@"test title" target:response];
    [DConnectMediaPlayerProfile setType:@"test type" target:response];
    [DConnectMediaPlayerProfile setLanguage:@"ja" target:response];
    [DConnectMediaPlayerProfile setDescription:@"test description" target:response];
    [DConnectMediaPlayerProfile setDuration:60000 target:response];
    
    DConnectMessage *creator = [DConnectMessage message];
    [DConnectMediaPlayerProfile setCreator:@"test creator" target:creator];
    [DConnectMediaPlayerProfile setRole:@"test composer" target:creator];
    
    DConnectArray *creators = [DConnectArray array];
    [creators addMessage:creator];
    
    DConnectArray *keywords = [DConnectArray array];
    [keywords addString:@"keyword1"];
    [keywords addString:@"keyword2"];
    
    DConnectArray *genres = [DConnectArray array];
    [genres addString:@"test1"];
    [genres addString:@"test2"];
    
    [DConnectMediaPlayerProfile setCreators:creators target:response];
    [DConnectMediaPlayerProfile setKeywords:keywords target:response];
    [DConnectMediaPlayerProfile setGenres:genres target:response];
    
    return YES;
}

// コンテンツ情報取得リクエストを受け取った
- (BOOL)              profile:(DConnectMediaPlayerProfile *)profile
didReceiveGetMediaListRequest:(DConnectRequestMessage *)request
                     response:(DConnectResponseMessage *)response
                     serviceId:(NSString *)serviceId
                        query:(NSString *)query
                     mimeType:(NSString *)mimeType
                        order:(NSString *)order
                       offset:(NSNumber *)offset
                        limit:(NSNumber *)limit
{
    response.result = DConnectMessageResultTypeOk;
    [DConnectMediaPlayerProfile setCount:1 target:response];
    
    DConnectMessage *medium = [DConnectMessage message];
    [DConnectMediaPlayerProfile setMediaId:@"https://raw.githubusercontent.com/DeviceConnect/DeviceConnect/master/sphero_demo.MOV" target:medium];
    [DConnectMediaPlayerProfile setMIMEType:@"video/mov" target:medium];
    [DConnectMediaPlayerProfile setTitle:@"test title" target:medium];
    [DConnectMediaPlayerProfile setType:@"test type" target:medium];
    [DConnectMediaPlayerProfile setLanguage:@"ja" target:medium];
    [DConnectMediaPlayerProfile setDescription:@"test description" target:medium];
    [DConnectMediaPlayerProfile setDuration:60000 target:medium];
    
    DConnectMessage *creator = [DConnectMessage message];
    [DConnectMediaPlayerProfile setCreator:@"test creator" target:creator];
    [DConnectMediaPlayerProfile setRole:@"test composer" target:creator];
    
    DConnectArray *creators = [DConnectArray array];
    [creators addMessage:creator];
    
    DConnectArray *keywords = [DConnectArray array];
    [keywords addString:@"keyword1"];
    [keywords addString:@"keyword2"];
    
    DConnectArray *genres = [DConnectArray array];
    [genres addString:@"test1"];
    [genres addString:@"test2"];
    
    [DConnectMediaPlayerProfile setCreators:creators target:medium];
    [DConnectMediaPlayerProfile setKeywords:keywords target:medium];
    [DConnectMediaPlayerProfile setGenres:genres target:medium];
    
    DConnectArray *media = [DConnectArray array];
    [media addMessage:medium];
    
    [DConnectMediaPlayerProfile setMedia:media target:response];
    
    return YES;
}

// 再生位置取得リクエストを受け取った
- (BOOL)         profile:(DConnectMediaPlayerProfile *)profile
didReceiveGetSeekRequest:(DConnectRequestMessage *)request
                response:(DConnectResponseMessage *)response
                serviceId:(NSString *)serviceId
{
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 再生位置取得
                NSTimeInterval pos = [[DPChromecastManager sharedManager] streamPositionWithID:serviceId];
                [response setDouble:pos forKey:@"pos"];
            }];
}

// メディアプレーヤーの音量取得リクエストを受け取った
- (BOOL)           profile:(DConnectMediaPlayerProfile *)profile
didReceiveGetVolumeRequest:(DConnectRequestMessage *)request
                  response:(DConnectResponseMessage *)response
                  serviceId:(NSString *)serviceId
{
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 音量取得
                float vol = [[DPChromecastManager sharedManager] volumeWithID:serviceId];
                [response setDouble:vol forKey:@"volume"];
            }];
}

// メディアプレーヤーミュート状態取得リクエストを受け取った
- (BOOL)         profile:(DConnectMediaPlayerProfile *)profile
didReceiveGetMuteRequest:(DConnectRequestMessage *)request
                response:(DConnectResponseMessage *)response
                serviceId:(NSString *)serviceId
{
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // ミュート状態取得
                BOOL mute = [[DPChromecastManager sharedManager] isMutedWithID:serviceId];
                [response setBool:mute forKey:@"mute"];
            }];
}


#pragma mark - Put Methods

// 再生コンテンツ変更リクエストを受け取った
- (BOOL)            profile:(DConnectMediaPlayerProfile *)profile
  didReceivePutMediaRequest:(DConnectRequestMessage *)request
                   response:(DConnectResponseMessage *)response
                   serviceId:(NSString *)serviceId
                    mediaId:(NSString *)mediaId
{
    // パラメータチェック
    if (mediaId == nil) {
        [response setErrorToInvalidRequestParameterWithMessage:@"Content ID cannot be empty"];
        return YES;
    }
    
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // ロード
				NSInteger requestId = [[DPChromecastManager sharedManager] loadMediaWithID:serviceId mediaID:mediaId];
                //リクエストを送信できなかった
                if(requestId == kGCKInvalidRequestID){
                    [response setString:@"mediaId is not exist" forKey:@"value"];
                }
            }];
}

// 再生開始リクエストを受け取った
- (BOOL)         profile:(DConnectMediaPlayerProfile *)profile
didReceivePutPlayRequest:(DConnectRequestMessage *)request
                response:(DConnectResponseMessage *)response
                serviceId:(NSString *)serviceId
{
    //パラメータチェック
	NSString *status = [[DPChromecastManager sharedManager] mediaPlayerStateWithID:serviceId];
	
    if([status  isEqual: @"play"]){
        [response setErrorToIllegalDeviceStateWithMessage:@"Playstate is not idle"];
        return YES;
    }
    
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 再生
                NSInteger requestId = [[DPChromecastManager sharedManager] playWithID:serviceId];
                //リクエストを送信できなかった
                if(requestId == kGCKInvalidRequestID){
                    [response setErrorToInvalidRequestParameterWithMessage:@"Media is not selected"];
                }
            }];
}

// 再生停止リクエストを受け取った
- (BOOL)         profile:(DConnectMediaPlayerProfile *)profile
didReceivePutStopRequest:(DConnectRequestMessage *)request
                response:(DConnectResponseMessage *)response
                serviceId:(NSString *)serviceId
{
    //パラメータチェック
    NSString *status = [[DPChromecastManager sharedManager] mediaPlayerStateWithID:serviceId];
    
    if(![status  isEqual: @"play"]){
        [response setErrorToIllegalDeviceStateWithMessage:@"Playstate is not playing"];
        return YES;
    }
    
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 停止
                NSInteger requestId = [[DPChromecastManager sharedManager] stopWithID:serviceId];
                // リクエストを送信できなかった
                if(requestId == kGCKInvalidRequestID){
                    [response setErrorToInvalidRequestParameterWithMessage:@"Media is not selected"];
                }
            }];
}

// 再生一時停止リクエストを受け取った
- (BOOL)          profile:(DConnectMediaPlayerProfile *)profile
didReceivePutPauseRequest:(DConnectRequestMessage *)request
                 response:(DConnectResponseMessage *)response
                 serviceId:(NSString *)serviceId
{
    //パラメータチェック
    NSString *status = [[DPChromecastManager sharedManager] mediaPlayerStateWithID:serviceId];
    
    if(![status  isEqual: @"play"]){
        [response setErrorToIllegalDeviceStateWithMessage:@"Playstate is not playing"];
        return YES;
    }
    
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 一時停止
                NSInteger requestId = [[DPChromecastManager sharedManager] pauseWithID:serviceId];
                //リクエストを送信できなかった
                if(requestId == kGCKInvalidRequestID){
                    [response setErrorToInvalidRequestParameterWithMessage:@"Media is not selected"];
                }
            }];
}

// 再生再開リクエストを受け取った
- (BOOL)           profile:(DConnectMediaPlayerProfile *)profile
didReceivePutResumeRequest:(DConnectRequestMessage *)request
                  response:(DConnectResponseMessage *)response
                  serviceId:(NSString *)serviceId
{
    // 再生状態取得
    NSString *status = [[DPChromecastManager sharedManager] mediaPlayerStateWithID:serviceId];

    if(![status  isEqual: @"pause"]){
        [response setErrorToIllegalDeviceStateWithMessage:@"Playstate is not paused"];
        return YES;
    }
    
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 再生
                NSInteger requestId = [[DPChromecastManager sharedManager] playWithID:serviceId];
                //リクエストを送信できなかった
                if(requestId == kGCKInvalidRequestID){
                    [response setErrorToInvalidRequestParameterWithMessage:@"Media is not selected"];
                }
            }];
}

// 再生位置変更リクエストを受け取った
- (BOOL)         profile:(DConnectMediaPlayerProfile *)profile
didReceivePutSeekRequest:(DConnectRequestMessage *)request
                response:(DConnectResponseMessage *)response
                serviceId:(NSString *)serviceId
                     pos:(NSNumber *)pos
{
    DPChromecastManager *mgr = [DPChromecastManager sharedManager];
    
    // パラメータチェック
    if (pos == nil || [pos doubleValue] < 0 || [mgr durationWithID:serviceId] <[pos doubleValue]) {
        [response setErrorToInvalidRequestParameter];
        return YES;
    }
    
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 再生位置変更
                [[DPChromecastManager sharedManager] setStreamPositionWithID:serviceId position:[pos doubleValue]];
            }];
}

// メディアプレーヤーの音量変更リクエストを受け取った
- (BOOL)           profile:(DConnectMediaPlayerProfile *)profile
didReceivePutVolumeRequest:(DConnectRequestMessage *)request
                  response:(DConnectResponseMessage *)response
                  serviceId:(NSString *)serviceId
                    volume:(NSNumber *)volume
{
    // パラメータチェック
    float vol = [volume floatValue];
    if (!volume || vol < 0 || vol > 1.0) {
        [response setErrorToInvalidRequestParameter];
        return YES;
    }
    
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // 音量変更
                [[DPChromecastManager sharedManager] setVolumeWithID:serviceId volume:vol];
            }];
}

// メディアプレーヤーミュート有効化リクエストを受け取った
- (BOOL)         profile:(DConnectMediaPlayerProfile *)profile
didReceivePutMuteRequest:(DConnectRequestMessage *)request
                response:(DConnectResponseMessage *)response
                serviceId:(NSString *)serviceId
{
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // ミュート有効化
                [[DPChromecastManager sharedManager] setIsMutedWithID:serviceId muted:YES];
            }];
}


#pragma mark - Delete Methods

// メディアプレーヤーミュート無効化リクエストを受け取った
- (BOOL)            profile:(DConnectMediaPlayerProfile *)profile
didReceiveDeleteMuteRequest:(DConnectRequestMessage *)request
                   response:(DConnectResponseMessage *)response
                   serviceId:(NSString *)serviceId
{
    // リクエスト処理
    return [self handleRequest:request
                      response:response
                      serviceId:serviceId
                      callback:
            ^{
                // ミュート無効化
				[[DPChromecastManager sharedManager] setIsMutedWithID:serviceId muted:NO];
            }];
}


#pragma mark - Event

// 共通イベントリクエスト処理
- (void)handleEventRequest:(DConnectRequestMessage *)request
				  response:(DConnectResponseMessage *)response
				  isRemove:(BOOL)isRemove
				  callback:(void(^)())callback
{
	DConnectEventManager *mgr = [DConnectEventManager sharedManagerForClass:[DPChromecastDevicePlugin class]];
	DConnectEventError error;
	if (isRemove) {
		error = [mgr removeEventForRequest:request];
	} else {
		error = [mgr addEventForRequest:request];
	}
	switch (error) {
		case DConnectEventErrorNone:
			[response setResult:DConnectMessageResultTypeOk];
			callback();
			break;
		case DConnectEventErrorInvalidParameter:
			[response setErrorToInvalidRequestParameter];
			break;
		case DConnectEventErrorFailed:
		case DConnectEventErrorNotFound:
		default:
			[response setErrorToUnknown];
			break;
	}
}

// onstatuschangeイベント登録リクエストを受け取った
- (BOOL)                   profile:(DConnectMediaPlayerProfile *)profile
didReceivePutOnStatusChangeRequest:(DConnectRequestMessage *)request
                          response:(DConnectResponseMessage *)response
                          serviceId:(NSString *)serviceId
                        sessionKey:(NSString *)sessionkey
{
	[self handleEventRequest:request response:response isRemove:NO callback:^{
		[self addMediaEvent:serviceId];
	}];
    return YES;
}

// イベント追加
- (void) addMediaEvent:(NSString *)serviceId
{
	__block DConnectDevicePlugin *_self = (DConnectDevicePlugin *)self.provider;
	
	DConnectEventManager *evtMgr = [DConnectEventManager sharedManagerForClass:[DPChromecastDevicePlugin class]];
	
	[[DPChromecastManager sharedManager] setEventCallbackWithID:serviceId callback:^(NSString *mediaID) {
		DPChromecastManager *mgr = [DPChromecastManager sharedManager];
		DConnectMessage *message = [DConnectMessage message];
		[DConnectMediaPlayerProfile setMediaId:mediaID target:message];
		[DConnectMediaPlayerProfile setMIMEType:@"video/mp4" target:message];
		[DConnectMediaPlayerProfile setStatus:[mgr mediaPlayerStateWithID:serviceId] target:message];
		[DConnectMediaPlayerProfile setPos:[mgr streamPositionWithID:serviceId] target:message];
		[DConnectMediaPlayerProfile setVolume:[mgr volumeWithID:serviceId] target:message];
		
		NSArray *evts = [evtMgr eventListForServiceId:serviceId
											 profile:DConnectMediaPlayerProfileName
										   attribute:DConnectMediaPlayerProfileAttrOnStatusChange];
		for (DConnectEvent *evt in evts) {
			DConnectMessage *eventMsg = [DConnectEventManager createEventMessageWithEvent:evt];
			[DConnectMediaPlayerProfile setMediaPlayer:message target:eventMsg];
			[_self sendEvent:eventMsg];
		}
	}];
}

// onstatuschangeイベント解除リクエストを受け取った
- (BOOL)                      profile:(DConnectMediaPlayerProfile *)profile
didReceiveDeleteOnStatusChangeRequest:(DConnectRequestMessage *)request
                             response:(DConnectResponseMessage *)response
                             serviceId:(NSString *)serviceId
                           sessionKey:(NSString *)sessionkey
{
	// DConnectイベント削除
	[self handleEventRequest:request response:response isRemove:YES callback:^{
	}];
    return YES;
}
 

@end
