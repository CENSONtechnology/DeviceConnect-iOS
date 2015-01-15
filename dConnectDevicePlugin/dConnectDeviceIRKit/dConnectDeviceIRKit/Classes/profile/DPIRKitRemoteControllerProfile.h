//
//  DPIRKitRemoteControllerProfile.h
//  DConnectSDK
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

/*! @file
 @brief RemoteControllerプロファイルを実装するための機能を提供する。
 @author NTT DOCOMO
 @date 作成日(2014.8.20)
 */
#import <DConnectSDK/DConnectSDK.h>

@class DPIRKitDevicePlugin;

/*!
 @class DPIRKitRemoteControllerProfile
 @brief Remote Controllerプロファイル。
 
 Remote Controller Profileの各APIへのリクエストを受信する。
 */
@interface DPIRKitRemoteControllerProfile : DConnectProfile

/*!
 @brief DPIRKitDevicePluginを指定してインスタンスを生成する。
 
 @param[in] plugin DPIRKitDevicePluginのインスタンス
 @retval DPIRKitRemoteControllerProfileのインスタンス
 */
- (id) initWithDevicePlugin:(DPIRKitDevicePlugin *)plugin;

@end
