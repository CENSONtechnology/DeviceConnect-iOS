//
//  DConnectProfile.h
//  dConnectManager
//
//  Copyright (c) 2014 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

/*! 
 @file
 @brief プロファイルの基礎機能を提供する。
 @author NTT DOCOMO
 */
#import <Foundation/Foundation.h>
#import <DConnectSDK/DConnectRequestMessage.h>
#import <DConnectSDK/DConnectResponseMessage.h>
#import <DConnectSDK/DConnectProfileProvider.h>
//#import "DConnectService.h"
#import "DConnectApi.h"

/*!
 @class DConnectProfile
 @brief プロファイルのベースクラス。
 
 このサンプルコードでは、以下のようなURLに対応する。<br>
 GET http://{dConnectドメイン}/gotapi/example/test?serviceId=xxxx
 
 */
@interface DConnectProfile : NSObject

/*!
 @brief プロファイルプロバイダ。
 */
@property (nonatomic, weak) id<DConnectProfileProvider> provider;


/*!
 @brief サポートするAPI(key: ApiIdentifier, value: DConnectApi).
 */
@property (nonatomic, weak) NSMutableDictionary *mApis;




/*!
 @brief プロファイルに設定されているDevice Connect API実装のリストを返す.
 @retval API実装のリスト(DConnectApiの配列)
 */
- (NSArray *) apis;


/*!
 @brief 指定されたリクエストに対応するDevice Connect API実装を返す.
 @param[in] path リクエストされたAPIのパス
 @param[in] method リクエストされたAPIのメソッド
 @retval 指定されたリクエストに対応するAPI実装を返す. 存在しない場合は<code>null</code>
 */
- (DConnectApi *) findApiWithPath: (NSString *) path method: (DConnectApiSpecMethod) method;

/*!
 @brief Device Connect API実装を追加する.
 @param[in] api API 追加するAPI実装
 */
- (void) addApi: (DConnectApi *) api;

/*!
 @brief Device Connect API実装を削除する.
 @param[in] api 削除するAPI実装
 */
- (void) removeApi: (DConnectApi *) api;

/*!
 @brief 指定されたDevice Connect APIへのパスを返す.
 @param[in] api API実装
 @retval パス
 */
- (NSString *) apiPath: (DConnectApi *) api;

/*!
 @brief プロファイル名、インターフェース名、アトリビュート名からパスを作成する.
 @param[in] profileName プロファイル名
 @param[in] interfaceName インターフェース名
 @param[in] attributeName アトリビュート名
 @retval パス
 */
- (NSString *) apiPathWithProfileInterfaceAttribute : (NSString *) profileName interfaceName: (NSString *) interfaceName attributeName:(NSString *) attributeName;

/*!
 @brief 本プロファイル実装を提供するサービスを設定する.
 
 @param[in] service サービス
 */
//- (void) setService: (DConnectService *) service;

/*!
 @brief 本プロファイル実装を提供するサービスを取得する.
 
 @retval サービス
 */
//- (DConnectService *) service;

/*!
 @brief プロファイル名を取得する。
 
 実装されていない場合には、nilを返却する。
 
 @return プロファイル名
 */
- (NSString *) profileName;

/*!
 @brief プロファイルの表示名を取得する。
 
 実装されていない場合には、nilを返却する。
 @return プロファイルの表示名
 */
- (NSString *) displayName;

/*!
 
 @brief プロファイルの説明文を取得する。
 実装されていない場合には、nilを返却する。
 
 @return プロファイルの説明文
 */
- (NSString *) detail;

/*!
 
 @brief プロファイルの有効期間(分)を取得する。
 実装されていない場合には、180日とする。
 
 @return 有効期間(分)
 */
- (long long) expirePeriod;

/*!
 @brief リクエストを受領し、各メソッドにリクエストを配送する。
 @param[in] request リクエスト
 @param[in,out] response レスポンス
 @return responseが処理済みならYES、そうでなければNO。responseの非同期更新がまだ完了していないなどの理由でresponseを返却すべきでない状況ならばNOを返すべき。
 */
- (BOOL) didReceiveRequest:(DConnectRequestMessage *) request response:(DConnectResponseMessage *) response;

/*!
 
 @brief GETメソッドリクエスト受信時に呼び出される。
 
 この関数でRESTfulのGETメソッドに対応する処理を記述する。
 @param[in] request リクエスト
 @param[in,out] response レスポンス
 @return responseが処理済みならYES、そうでなければNO。responseの非同期更新がまだ完了していないなどの理由でresponseを返却すべきでない状況ならばNOを返すべき。
 */
- (BOOL) didReceiveGetRequest:(DConnectRequestMessage *) request response:(DConnectResponseMessage *) response;

/*!
 @brief POSTメソッドリクエスト受信時に呼び出される。
 
 この関数でRESTfulのPOSTメソッドに対応する処理を記述する。
 
 @param[in] request リクエスト
 @param[in,out] response レスポンス
 @return responseが処理済みならYES、そうでなければNO。responseの非同期更新がまだ完了していないなどの理由でresponseを返却すべきでない状況ならばNOを返すべき。
 */
- (BOOL) didReceivePostRequest:(DConnectRequestMessage *) request response:(DConnectResponseMessage *) response;

/*!
 
 @brief PUTメソッドリクエスト受信時に呼び出される。
 この関数でRESTfulのPUTメソッドに対応する処理を記述する。
 
 @param[in] request リクエスト
 @param[in,out] response レスポンス
 @return responseが処理済みならYES、そうでなければNO。responseの非同期更新がまだ完了していないなどの理由でresponseを返却すべきでない状況ならばNOを返すべき。
 */
- (BOOL) didReceivePutRequest:(DConnectRequestMessage *) request response:(DConnectResponseMessage *) response;

/*!
 @brief DELETEメソッドリクエスト受信時に呼び出される。
 この関数でRESTfulのDELETEメソッドに対応する処理を記述する。
 
 @param[in] request リクエスト
 @param[in,out] response レスポンス
 @return responseが処理済みならYES、そうでなければNO。responseの非同期更新がまだ完了していないなどの理由でresponseを返却すべきでない状況ならばNOを返すべき。
 */
- (BOOL) didReceiveDeleteRequest:(DConnectRequestMessage *) request response:(DConnectResponseMessage *) response;


@end
