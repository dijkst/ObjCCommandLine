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

#define AMShellWrapperProcessFinishedNotification @"AMShellWrapperProcessFinishedNotification"
#define AMShellWrapperProcessFinishedNotificationTaskKey @"AMShellWrapperProcessFinishedNotificationTaskKey"
#define AMShellWrapperProcessFinishedNotificationTerminationStatusKey @"AMShellWrapperProcessFinishedNotificationTerminationStatusKey"


@class AMShellWrapper;


@protocol AMShellWrapperDelegate
// implement this protocol to control your AMShellWrapper object:

- (void)process:(AMShellWrapper *)wrapper appendOutput:(NSData *)output;
// output from stdout

- (void)process:(AMShellWrapper *)wrapper appendError:(NSData *)error;
// output from stderr

- (void)processStarted:(AMShellWrapper *)wrapper;
// This method is a callback which your controller can use to do other initialization
// when a process is launched.

- (void)processFinished:(AMShellWrapper *)wrapper withTerminationStatus:(int)resultCode;
// This method is a callback which your controller can use to do other cleanup
// when a process is halted.

// AMShellWrapper posts a AMShellWrapperProcessFinishedNotification when a process finished.
// The userInfo of the notification contains the corresponding NSTask ((NSTask *), key @"task")
// and the result code ((NSNumber *), key @"resultCode")
// ! notification removed since it prevented the task from getting deallocated

@end


@interface AMShellWrapper : NSObject {
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

@property (nonatomic, weak) id <AMShellWrapperDelegate>delegate;
@property (nonatomic, assign) int                      terminationStatus;

- (id)initWithLaunchPath:(NSString *)launch
        workingDirectory:(NSString *)directoryPath
             environment:(NSDictionary *)env
               arguments:(NSArray *)args
                 context:(void *)pointer;


- (void *)context;

- (void)startProcess;
// This method launches the process, setting up asynchronous feedback notifications.

- (void)stopProcess;
// This method stops the process, stoping asynchronous feedback notifications.

- (void)appendInput:(NSData *)input;
// input to stdin
- (void)closeInput;


@end
