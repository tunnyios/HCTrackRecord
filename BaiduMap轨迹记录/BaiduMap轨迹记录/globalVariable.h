//
//  globalVariable.h
//  BaiduMap轨迹记录
//
//  Created by tunny on 15/7/9.
//  Copyright (c) 2015年 tunny. All rights reserved.
//

#ifndef BaiduMap_____globalVariable_h
#define BaiduMap_____globalVariable_h


#ifdef  DEBUG
#define DLog( s, ... ) NSLog( @"<%p %@:(%d) %s> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, __func__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DLog( s, ... )
#endif


#endif
