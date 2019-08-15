//
//  TTYShellWrapper.h
//  ObjCCommandLine
//
//  Created by Whirlwind on 2019/8/7.
//  Copyright © 2019 dijkst. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ObjCShellWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTYShellWrapper : NSObject <ObjCShellWrapperProtocol>

@property (nonatomic, assign) BOOL finish;

@property (nonatomic, weak) id<ObjCShellWrapperDelegate> delegate;
@property (nonatomic, assign) int terminationStatus;

@end

NS_ASSUME_NONNULL_END
