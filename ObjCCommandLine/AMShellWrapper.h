//
//  AMShellWrapper.h
//  CommX
//
//  Created by Andreas on 2002-04-24.
//  Based on TaskWrapper from Apple
//
//  2002-06-17 Andreas Mayer
//  - used defines for keys in AMShellWrapperProcessFinishedNotification userInfo dictionary
//  2002-08-30 Andreas Mayer
//  - added setInputStringEncoding: and setOutputStringEncoding:
//  2009-09-07 Andreas Mayer
//  - renamed protocol to AMShellWrapperDelegate
//  - added process parameter to append... methods
//  - changed parameter type of processStarted: and processFinished: methods
//  - removed controller argument from initializer
//  - added context parameter to initializer
//  - added binaryOutput option; changed -process:appendOutput: accordingly
//  - appendInput now accepts input as NSData or NSString


#import <Foundation/Foundation.h>
#import "ObjCShellWrapper.h"

#define AMShellWrapperProcessFinishedNotification @"AMShellWrapperProcessFinishedNotification"
#define AMShellWrapperProcessFinishedNotificationTaskKey @"AMShellWrapperProcessFinishedNotificationTaskKey"
#define AMShellWrapperProcessFinishedNotificationTerminationStatusKey @"AMShellWrapperProcessFinishedNotificationTerminationStatusKey"

@interface AMShellWrapper : NSObject<ObjCShellWrapperProtocol> {
    NSTask       *task;
    void         *context;
    NSString     *workingDirectory;
    NSDictionary *environment;
    NSString     *launchPath;
    NSArray      *arguments;
    id           stdinPipe;
    id           stdoutPipe;
    id           stderrPipe;
    NSFileHandle *stdinHandle;
    NSFileHandle *stdoutHandle;
    NSFileHandle *stderrHandle;
    BOOL         stdoutEmpty;
    BOOL         stderrEmpty;
    BOOL         taskDidTerminate;
}

@property (nonatomic, assign) BOOL finish;

@property (nonatomic, weak) id<ObjCShellWrapperDelegate> delegate;
@property (nonatomic, assign) int terminationStatus;

- (void *)context;

// input to stdin
- (void)closeInput;

@end
