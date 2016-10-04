//
//  DConnectServerManager.m
//  DConnectSDK
//
//  Copyright (c) 2016 NTT DOCOMO,INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//

#import "DConnectServerManager.h"
#import "DConnectManager+Private.h"
#import "DConnectMessage+Private.h"
#import "DConnectHttpServer.h"
#import "DConnectHttpConnection.h"
#import "DConnectFilesProfile.h"
#import "DConnectFileManager.h"
#import "DConnectMultipartParser.h"
#import "DConnectURIBuilder.h"

/// 内部用タイプを定義する。
#define EXTRA_INNER_TYPE @"_type"

/// HTTPからの通信タイプを定義する。
#define EXTRA_TYPE_HTTP @"http"

/// JSONのマイムタイプ。
#define MIME_TYPE_JSON @"application/json; charset=UTF-8"

typedef NS_ENUM(NSInteger, RequestExceptionType) {
    HAVE_NO_API_EXCEPTION,
    HAVE_NO_PROFILE_EXCEPTION,
    NOT_SUPPORT_ACTION_EXCEPTION
};


@implementation DConnectServerManager {
    DConnectHttpServer *_httpServer;
}

- (BOOL) startServer
{
    _httpServer = [DConnectHttpServer new];
    
    [_httpServer setConnectionClass:[DConnectHttpConnection class]];
    [_httpServer setPort:self.settings.port];
    [_httpServer setDefaultHeader:@"Server" value:@"DeviceConnect/1.0"];
    [_httpServer setDefaultHeader:@"Access-Control-Allow-Origin" value:@"*"];
    [_httpServer get:@"/*" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self handleHttpRequest:request response:response];
    }];
    [_httpServer post:@"/*" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self handleHttpRequest:request response:response];
    }];
    [_httpServer put:@"/*" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self handleHttpRequest:request response:response];
    }];
    [_httpServer delete:@"/*" withBlock:^(RouteRequest *request, RouteResponse *response) {
        [self handleHttpRequest:request response:response];
    }];
    [_httpServer handleMethod:@"OPTIONS" withPath:@"/*" block:^(RouteRequest *request, RouteResponse *response) {
        [self handleHttpRequest:request response:response];
    }];
    
    NSError *error;
    if([_httpServer start:&error]) {
        return YES;
    } else {
        return NO;
    }
}

- (void)stopServer
{
    if ([_httpServer isRunning]) {
        [_httpServer stop];
    }
}

- (void) sendEvent:(NSString *)event forReceiverId:(NSString *)receiverId
{
    if (_httpServer) {
        [_httpServer sendEvent:event forReceiverId:receiverId];
    }
}

- (NSArray *) getWebSockets
{
    return [_httpServer getWebSockets];
}

+ (void) convertUriOfMessage:(DConnectMessage *) response
{
    NSArray *keys = [response allKeys];
    for (NSString *key in keys) {
        NSObject *obj = [response objectForKey:key];
        if ([key isEqualToString:@"uri"]) {
            NSString *uri = (NSString *)obj;
            
            // http, httpsで指定されているURLは直接アクセスできるのでFilesAPIを利用しない
            NSString *pattern = @"^https?://.+";
            NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                        options:0 error:nil];
            NSTextCheckingResult *result = [expression firstMatchInString:uri
                                                                  options:0
                                                                    range:NSMakeRange(0, uri.length)];
            if (!result || result.numberOfRanges < 1) {
                // http, https以外の場合はuriパラメータ値を
                // DeviceConnectManager Files API向けURLに置き換える。
                DConnectURIBuilder *builder = [DConnectURIBuilder new];
                [builder setProfile:DConnectFilesProfileName];
                [builder addParameter:uri forName:DConnectFilesProfileParamUri];
                [response setString:[[builder build] absoluteString] forKey:@"uri"];
            }
        } else if ([obj isKindOfClass:[DConnectMessage class]]) {
            [self convertUriOfMessage:(DConnectMessage *)obj];
        } else if ([obj isKindOfClass:[DConnectArray class]]) {
            DConnectArray *arr = (DConnectArray *) obj;
            for (int i = 0; i < arr.count; i++) {
                NSObject *message = [arr objectAtIndex:i];
                if ([message isKindOfClass:[DConnectMessage class]]) {
                    [self convertUriOfMessage:(DConnectMessage *) message];
                }
            }
        }
    }
}

#pragma mark - Private Method

- (void) handleHttpRequest:(RouteRequest *)request response:(RouteResponse *)response
{
    if (!self.settings.useExternalIP && ![[[request url] host] isEqualToString:@"localhost"]) {
        [self settingErrorCode:DConnectMessageErrorCodeIllegalServerState
                  errorMessage:@"Not localhost."
                    toResponse:response
                   withRequest:request];
        return;
    }
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * HTTP_REQUEST_TIMEOUT);
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakSelf executeWithRequest:request response:response callback:^(DConnectResponseMessage *responseMessage) {
            dispatch_semaphore_signal(semaphore);
        }];
    });
    
    long result = dispatch_semaphore_wait(semaphore, timeout);
    if (result != 0) {
        [self settingErrorCode:DConnectMessageErrorCodeTimeout
                  errorMessage:@"Response timeout."
                    toResponse:response
                   withRequest:request];
    }
}

- (void) executeWithRequest:(RouteRequest *)request response:(RouteResponse *)response callback:(DConnectResponseBlocks)callback
{
    if ([[request method] isEqualToString:@"OPTIONS"]) {
        // CORS処理
        NSMutableDictionary *headerDict = [self generateHeadersWithRequest:request
                                                                  mimeType:@"text/plain"
                                                                      data:nil].mutableCopy;
        [headerDict setValue:@"POST, GET, PUT, DELETE" forKey:@"Access-Control-Allow-Methods"];
        [response setStatusCode:200];
        [self setHeaders:headerDict toResponse:response];
        callback(nil);
    } else {
        __weak typeof(self) weakSelf = self;
        
        NSError *error = nil;
        DConnectRequestMessage *requestMessage = [self requestMessageWithHTTPReqeust:request error:&error];
        if (error) {
            switch (error.code) {
                case HAVE_NO_API_EXCEPTION:
                    [response setStatusCode:404];
                    [response respondWithString:error.domain encoding:NSUTF8StringEncoding];
                    break;
                case HAVE_NO_PROFILE_EXCEPTION: {
                    DConnectResponseMessage *responseMessage = [DConnectResponseMessage new];
                    [responseMessage setResult:DConnectMessageResultTypeError];
                    [responseMessage setVersion:[DConnectManager sharedManager].versionName];
                    [responseMessage setProduct:[DConnectManager sharedManager].productName];
                    [responseMessage setErrorToNotSupportProfile];
                    [self convertDConnectResponse:responseMessage DConnectRequest:nil toResponse:response Request:request];
                }   break;
                case NOT_SUPPORT_ACTION_EXCEPTION: {
                    [response setStatusCode:501];
                    [response respondWithString:error.domain encoding:NSUTF8StringEncoding];
                }   break;
                default: {
                    DConnectResponseMessage *responseMessage = [DConnectResponseMessage new];
                    [responseMessage setResult:DConnectMessageResultTypeError];
                    [responseMessage setVersion:[DConnectManager sharedManager].versionName];
                    [responseMessage setProduct:[DConnectManager sharedManager].productName];
                    [responseMessage setErrorToUnknown];
                    [self convertDConnectResponse:responseMessage DConnectRequest:nil toResponse:response Request:request];
                }   break;
            }
            callback(nil);
            return;
        }
        [requestMessage setString:EXTRA_TYPE_HTTP forKey:EXTRA_INNER_TYPE];
        [[DConnectManager sharedManager] sendRequest:requestMessage
                                              isHttp:YES
                                            callback:^(DConnectResponseMessage *responseMessage) {
                                                [weakSelf convertDConnectResponse:responseMessage
                                                                  DConnectRequest:requestMessage
                                                                       toResponse:response
                                                                          Request:request];
                                                callback(nil);
                                            }];
    }
}

- (DConnectRequestMessage *)requestMessageWithHTTPReqeust:(RouteRequest *)request error:(NSError **)error
{
    NSURL *url = request.url;
    
    DConnectRequestMessage *requestMessage = [DConnectRequestMessage message];
    
    // HTTPリクエストのURLのパスセグメントを取得
    NSMutableCharacterSet *whiteAndSlash = [NSMutableCharacterSet whitespaceCharacterSet];
    [whiteAndSlash formUnionWithCharacterSet:[NSMutableCharacterSet characterSetWithCharactersInString:@"/"]];
    NSString *trimmedPath = [url.path stringByTrimmingCharactersInSet:whiteAndSlash];
    NSArray *pathComponentArr = [trimmedPath componentsSeparatedByString:@"/"];
    
    // パラメータ「key=val」をパースし、パラメータ用NSDicitonaryに格納する。
    [self setURLParametersFromString:url.query
                    toRequestMessage:requestMessage
                     percentDecoding:YES];
    
    // URLのパスセグメントの数から、
    // プロファイル・属性・インターフェースが何なのかを判定する。
    NSString *api, *profile, *attr, *interface;
    api = profile = attr = interface = nil;
    
    if ([pathComponentArr count] == 1 &&
        [pathComponentArr[0] length] != 0)
    {
        api = pathComponentArr[0];
    } else if ([pathComponentArr count] == 2 &&
               [pathComponentArr[0] length] != 0 &&
               [pathComponentArr[1] length] != 0)
    {
        api = pathComponentArr[0];
        profile = pathComponentArr[1];
    } else if ([pathComponentArr count] == 3 &&
               [pathComponentArr[0] length] != 0 &&
               [pathComponentArr[1] length] != 0 &&
               [pathComponentArr[2] length] != 0)
    {
        api = pathComponentArr[0];
        profile = pathComponentArr[1];
        attr = pathComponentArr[2];
    } else if ([pathComponentArr count] == 4 &&
               [pathComponentArr[0] length] != 0 &&
               [pathComponentArr[1] length] != 0 &&
               [pathComponentArr[2] length] != 0 &&
               [pathComponentArr[3] length] != 0)
    {
        api = pathComponentArr[0];
        profile = pathComponentArr[1];
        interface = pathComponentArr[2];
        attr = pathComponentArr[3];
    }
    
    if (api == nil || ![api isEqualToString:DConnectMessageDefaultAPI]) {
        if (error) {
            *error = [NSError errorWithDomain:@"No valid api was detected in URL."
                                         code:HAVE_NO_API_EXCEPTION
                                     userInfo:nil];
        }
        return nil;
    }
    
    if (profile == nil) {
        if (error) {
            *error = [NSError errorWithDomain:@"No valid profile was detected in URL."
                                         code:HAVE_NO_PROFILE_EXCEPTION
                                     userInfo:nil];
        }
        return nil;
    }
    
    // リクエストメッセージにHTTPリクエストのメソッドに対応するアクション名を格納する
    int methodId = [self getDConnectMethod:request.method];
    if (methodId == -1) {
        if (error) {
            *error = [NSError errorWithDomain:@"Unknown method"
                                         code:NOT_SUPPORT_ACTION_EXCEPTION
                                     userInfo:nil];
        }
        return nil;
    }
    [requestMessage setAction:methodId];
    [requestMessage setApi:api];
    [requestMessage setProfile:profile];
    
    if (interface) {
        [requestMessage setInterface:interface];
    }
    
    if (attr) {
        [requestMessage setAttribute:attr];
    }
    
    // HTTPリクエストヘッダの解析
    [self setHeaderFromRequset:request toRequestMessage:requestMessage];
    
    // パラメータがHTTPボディに記述されているなら、解析しリクエストメッセージに追加する。
    if (request.body && request.body.length > 0) {
        [self setBodyFromRequest:request toRequestMessage:requestMessage];
    }
    
    return requestMessage;
}

- (int) getDConnectMethod:(NSString *)httpMethod
{
    if ([httpMethod isEqualToString:@"GET"]) {
        return DConnectMessageActionTypeGet;
    } else if ([httpMethod isEqualToString:@"POST"]) {
        return DConnectMessageActionTypePost;
    } else if ([httpMethod isEqualToString:@"PUT"]) {
        return DConnectMessageActionTypePut;
    } else if ([httpMethod isEqualToString:@"DELETE"]) {
        return DConnectMessageActionTypeDelete;
    }
    return -1;
}

- (void) setHeaderFromRequset:(RouteRequest *)request toRequestMessage:(DConnectRequestMessage *)requestMessage
{
    // オリジンの解析
    NSString *webOrigin = [request header:@"origin"];
    NSString *nativeOrigin = [request header:DConnectMessageHeaderGotAPIOrigin];
    if (nativeOrigin) {
        [requestMessage setString:nativeOrigin forKey:DConnectMessageOrigin];
    } else if (webOrigin) {
        [requestMessage setString:webOrigin forKey:DConnectMessageOrigin];
    } else {
        DCLogW(@"origin of request is not specified.");
    }
}

- (void) setBodyFromRequest:(RouteRequest *)request toRequestMessage:(DConnectRequestMessage *)requestMessage
{
    NSString *contentType = [request header:@"content-type"];
    if (contentType && [contentType rangeOfString:@"multipart/form-data"
                                          options:NSCaseInsensitiveSearch].location != NSNotFound) {
        [self setMultipartFromRequest:request toRequestMessage:requestMessage];
    } else if (request.body && request.body.length > 0) {
        NSString *urlParameter = [[NSString alloc] initWithData:request.body encoding:NSUTF8StringEncoding];
        BOOL doDecode = [contentType isEqualToString:@"application/x-www-form-urlencoded"];
        [self setURLParametersFromString:urlParameter
                        toRequestMessage:requestMessage
                         percentDecoding:doDecode];
    }
}

- (void) setMultipartFromRequest:(RouteRequest *)request toRequestMessage:(DConnectRequestMessage *)requestMessage
{
    UserData *userData = [UserData userDataWithRequest:requestMessage];
    DConnectMultipartParser *multiParser = [DConnectMultipartParser multipartParserWithURL:request.url
                                                                                  boundary:[self boundary:request]
                                                                                  userData:userData];
    [multiParser parse:request.body];
}

- (NSString *)boundary:(RouteRequest *)request
{
    NSString *contentType = [request header:@"content-type"];
    
    // Multipart Content-Typeのboundaryパラメータをキャプチャする準備
    // 参照： http://www.w3.org/Protocols/rfc1341/7_2_Multipart.html
    NSString *bcharsnospaceRegex = @"[\\d\\w'\\(\\)\\+_,-\\./:=\\?]";
    NSMutableString *bcharsRegex = @"[".mutableCopy;
    [bcharsRegex appendString:bcharsnospaceRegex];
    [bcharsRegex appendString:@"| ]"];
    NSMutableString *boundaryRegex = bcharsRegex.mutableCopy;
    [boundaryRegex appendString:@"{0,69}"];
    [boundaryRegex appendString:bcharsnospaceRegex];
    // パラメータboundaryの値を正規表現でキャプチャ
    NSMutableString *boundaryParamRegex = @"boundary=((?:\"".mutableCopy;
    [boundaryParamRegex appendString:boundaryRegex];
    [boundaryParamRegex appendString:@"\")|(?:"];
    [boundaryParamRegex appendString:boundaryRegex];
    [boundaryParamRegex appendString:@"))"];
    
    NSError *error = nil;
    NSRegularExpression *regex =
    [NSRegularExpression regularExpressionWithPattern:boundaryParamRegex
                                              options:0
                                                error:&error];
    if (error) {
        return nil;
    }

    NSTextCheckingResult *result =
    [regex firstMatchInString:contentType
                      options:NSMatchingReportProgress
                        range:NSMakeRange(0, contentType.length)];
    
    
    if (result.numberOfRanges < 2) {
        return nil;
    }
    
    return [contentType substringWithRange:[result rangeAtIndex:1]];
}

- (void) settingErrorCode:(DConnectMessageErrorCodeType)errorCode
             errorMessage:(NSString *)errorMessage
               toResponse:(RouteResponse *)response
              withRequest:(RouteRequest *)request
{
    NSString *dataStr = [NSString stringWithFormat:@"{\"%@\":%@,\"%@\":%@,\"%@\":\"%@\"}",
                         DConnectMessageResult, @(DConnectMessageResultTypeError),
                         DConnectMessageErrorCode, @(errorCode),
                         DConnectMessageErrorMessage, errorMessage];
    [response respondWithString:dataStr];
    
    NSDictionary *headerDict = [self generateHeadersWithRequest:request
                                                       mimeType:MIME_TYPE_JSON
                                                  contentLength:response.response.contentLength];
    [self setHeaders:headerDict toResponse:response];
}

- (void) convertDConnectResponse:(DConnectResponseMessage *)responseMessage
                 DConnectRequest:(DConnectRequestMessage *)requestMessage
                      toResponse:(RouteResponse *)response
                         Request:(RouteRequest *)request
{
    NSString *mimeType;
    
    if (requestMessage && [requestMessage.profile isEqualToString:DConnectFilesProfileName]) {
        if ([responseMessage result] == DConnectMessageResultTypeOk) {
            mimeType = [responseMessage stringForKey:DConnectFilesProfileParamMimeType];
            [response setStatusCode:200];
            [response respondWithData:[responseMessage dataForKey:DConnectFilesProfileParamData]];
        } else if ([responseMessage result] == DConnectMessageResultTypeError) {
            mimeType = @"text/plain";
            [response setStatusCode:404];
            [response respondWithString:@"Not found."];
        } else {
            mimeType = @"text/plain";
            [response setStatusCode:500];
            [response respondWithString:@"unkknown result type."];
        }
    } else {
        [DConnectServerManager convertUriOfMessage:responseMessage];
        
        NSString *json = [responseMessage convertToJSONString];
        if (!json) {
            [self settingErrorCode:DConnectMessageErrorCodeUnknown
                      errorMessage:@"Failed to generate a JSON body."
                        toResponse:response
                       withRequest:request];
        } else {
            [response setStatusCode:200];
            [response respondWithString:json encoding:NSUTF8StringEncoding];
            [response setHeader:@"Content-Type" value:MIME_TYPE_JSON];
        }
        mimeType = MIME_TYPE_JSON;
    }
    
    NSDictionary *headerDict = [self generateHeadersWithRequest:request
                                                       mimeType:mimeType
                                                  contentLength:response.response.contentLength];
    [self setHeaders:headerDict toResponse:response];
}

- (void) setHeaders:(NSDictionary *)headers toResponse:(RouteResponse *)response
{
    for (id key in [headers keyEnumerator]) {
        [response setHeader:key value:[headers valueForKey:key]];
    }
}

- (NSDictionary *)generateHeadersWithRequest:(RouteRequest *)request
                                    mimeType:(NSString *)mimeType
                                        data:(NSData *)data
{
    return [self generateHeadersWithRequest:request
                                   mimeType:mimeType
                              contentLength:data ? data.length : 0];
}

- (NSDictionary *)generateHeadersWithRequest:(RouteRequest *)request
                                    mimeType:(NSString *)mimeType
                               contentLength:(NSUInteger)contentLength
{
    NSString *allowHeaders = [request header:@"Access-Control-Request-Headers"];
    return [self generateHeadersWithAllowHeaders:allowHeaders
                                        mimeType:mimeType
                                   contentLength:contentLength];
}

- (NSDictionary *)generateHeadersWithAllowHeaders:(NSString *)allowHeader
                                         mimeType:(NSString *)mimeType
                                    contentLength:(NSUInteger)contentLength
{
    NSMutableString *allowHeaders = @"XMLHttpRequest".mutableCopy;
    if (allowHeader) {
        [allowHeaders appendString:[NSString stringWithFormat:@", %@", allowHeader]];
    }
    
    return @{@"Content-Type" : mimeType,
             @"Content-Length" : [NSString stringWithFormat:@"%@", @(contentLength)],
             @"Date": [[NSDate date] descriptionWithLocale:nil],
             @"Access-Control-Allow-Origin" : @"*",
             @"Access-Control-Allow-Headers" : allowHeaders,
             @"Connection": @"close",
             @"Server" : @"dConnectServer",
             @"Last-Modified" : @"Fri, 26 May 2014 00:00:00 +0900",
             @"Cache-Control" : @"private, max-age=0, no-cache"
             };
}

- (void)setURLParametersFromString:(NSString *)urlParameterStr
                  toRequestMessage:(DConnectRequestMessage *)requestMessage
                   percentDecoding:(BOOL)doDecode
{
    if (!urlParameterStr) {
        return;
    }
    NSArray *paramArr = [urlParameterStr componentsSeparatedByString:@"&"];
    [paramArr enumerateObjectsWithOptions:NSEnumerationConcurrent
                               usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
     {
         NSArray *keyValArr = [(NSString *)obj componentsSeparatedByString:@"="];
         NSString *key;
         NSString *val;
         
#ifdef DEBUG_LEVEL
#if DEBUG_LEVEL > 3
         // valが無くkeyのみのパラメータ
         if ([keyValArr count] == 1) {
             key = doDecode ?
             [DConnectURLProtocol stringByURLDecodingWithString:(NSString *)keyValArr[0]]
             : keyValArr[0];
             DCLogD(@"Key-only URL query parameter \"%@\" will be ignored.", key);
         }
#endif
#endif
         // key&valのパラメータ
         if ([keyValArr count] == 2) {
             
             if (doDecode) {
                 key = [self stringByURLDecodingWithString:(NSString *)keyValArr[0]];
                 val = [self stringByURLDecodingWithString:(NSString *)keyValArr[1]];
             } else {
                 key = keyValArr[0];
                 val = keyValArr[1];
             }
             
             if (key && val) {
                 @synchronized (requestMessage) {
                     [requestMessage setString:val forKey:key];
                 }
             }
         }
     }];
}

- (NSString *) stringByURLDecodingWithString:(NSString *)string {
    NSString *url = [string stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    url = [url stringByRemovingPercentEncoding];
    return url;
}
@end
