//
//  NSFileHandle+isReadableAddon.h
//  ObjCCommandLine
//
//  Created by 詹迟晶 on 2020/2/4.
//  Copyright © 2020 dijkst. All rights reserved.
//

#import <AppKit/AppKit.h>


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFileHandle (isReadableAddon)

@property (nonatomic, readonly) BOOL readable;

@end

NS_ASSUME_NONNULL_END
