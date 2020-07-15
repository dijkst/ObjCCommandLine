//
//  TerminalBase+Private.h
//  ObjCCommandLine
//
//  Created by 詹迟晶 on 2020/7/12.
//  Copyright © 2020 dijkst. All rights reserved.
//

#import "TerminalBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface TerminalBase () {
    @public
    NSTask       *task;
    void         *context;
    NSString     *workingDirectory;
    NSDictionary *environment;
    NSString     *launchPath;
    NSArray      *arguments;

    NSFileHandle *inputHandle;
    NSFileHandle *outHandle;
    NSFileHandle *errorHandle;
    pid_t        childProcessID;

    BOOL         stdoutEmpty;
    BOOL         stderrEmpty;
    BOOL         taskDidTerminate;

}

- (void)runChildProcess;

- (void)appendOutput:(NSData *)data;
- (void)appendError:(NSData *)data;
- (void)appendInput:(nonnull NSData *)input;

- (void)stopProcess;

- (BOOL)handleReadable:(NSFileHandle *)handle;
- (void)watchSTDOUT:(NSFileHandle *)handle;
- (void)watchSTDERR:(NSFileHandle *)handle;

- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
