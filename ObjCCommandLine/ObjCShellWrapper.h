//
//  ObjCShellWrapperProtocol.h
//  ObjCCommandLine
//
//  Created by Whirlwind on 2019/8/7.
//  Copyright © 2019 dijkst. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ObjCShellWrapperDelegate;
@protocol ObjCShellWrapperProtocol <NSObject>

@property (nonatomic, assign) BOOL finish;
@property (nonatomic, assign) int terminationStatus;
@property (nonatomic, weak) id<ObjCShellWrapperDelegate> delegate;

- (id)initWithLaunchPath:(NSString *)launch
        workingDirectory:(NSString * __nullable)directoryPath
             environment:(NSDictionary * __nullable)env
               arguments:(NSArray *)args
                 context:(void * __nullable)pointer;

- (void)startProcess;
// This method launches the process, setting up asynchronous feedback notifications.

- (void)stopProcess;
// This method stops the process, stoping asynchronous feedback notifications.

- (void)appendInput:(NSData *)input;

@end

@protocol ObjCShellWrapperDelegate <NSObject>
// implement this protocol to control your AMShellWrapper object:

- (void)process:(id<ObjCShellWrapperProtocol>)wrapper appendOutput:(NSData *)output;
// output from stdout

- (void)process:(id<ObjCShellWrapperProtocol>)wrapper appendError:(NSData *)error;
// output from stderr

- (void)processStarted:(id<ObjCShellWrapperProtocol>)wrapper;
// This method is a callback which your controller can use to do other initialization
// when a process is launched.

- (void)processFinished:(id<ObjCShellWrapperProtocol>)wrapper withTerminationStatus:(int)resultCode;
// This method is a callback which your controller can use to do other cleanup
// when a process is halted.

// AMShellWrapper posts a AMShellWrapperProcessFinishedNotification when a process finished.
// The userInfo of the notification contains the corresponding NSTask ((NSTask *), key @"task")
// and the result code ((NSNumber *), key @"resultCode")
// ! notification removed since it prevented the task from getting deallocated

@end

NS_ASSUME_NONNULL_END
