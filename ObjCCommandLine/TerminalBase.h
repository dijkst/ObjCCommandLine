//
//  TerminalBase.h
//  ObjCCommandLine
//
//  Created by 詹迟晶 on 2020/7/12.
//  Copyright © 2020 dijkst. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TerminalBase;
@protocol TerminalDelegate <NSObject>

- (void)process:(TerminalBase *)wrapper appendOutput:(NSData *)output;

- (void)process:(TerminalBase *)wrapper appendError:(NSData *)error;

- (void)processStarted:(TerminalBase *)wrapper;

- (void)processFinished:(TerminalBase *)wrapper
  withTerminationStatus:(int)resultCode;

@end

@interface TerminalBase : NSObject

@property (nonatomic, assign) BOOL finish;

@property (nonatomic, weak) id<TerminalDelegate> delegate;
@property (nonatomic, assign) int terminationStatus;

- (id)initWithLaunchPath:(NSString *)launch
        workingDirectory:(NSString * __nullable)directoryPath
             environment:(NSDictionary * __nullable)env
               arguments:(NSArray *)args
                 context:(void * __nullable)pointer;

- (void)startProcess;

- (void)stopProcess;

- (void)appendInput:(NSData *)input;

@end

NS_ASSUME_NONNULL_END
