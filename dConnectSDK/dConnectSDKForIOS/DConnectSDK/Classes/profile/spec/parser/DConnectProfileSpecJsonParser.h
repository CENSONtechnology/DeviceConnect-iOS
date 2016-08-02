//
//  DConnectProfileSpecJsonParser.h
//  DConnectSDK
//
//  Created by Mitsuhiro Suzuki on 2016/07/29.
//  Copyright © 2016年 NTT DOCOMO, INC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DConnectProfileSpec.h"

@interface DConnectProfileSpecJsonParser : NSObject

- (DConnectProfileSpec *) parseJson: (NSString *) jsonFilename;

@end
