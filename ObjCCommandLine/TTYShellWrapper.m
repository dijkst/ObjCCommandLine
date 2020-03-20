//
//  TTYShellWrapper.m
//  ObjCCommandLine
//
//  Created by Whirlwind on 2019/8/7.
//  Copyright © 2019 dijkst. All rights reserved.
//

#import "TTYShellWrapper.h"
#import "ObjCShell.h"
#import "NSFileHandle+isReadableAddon.h"

#include <unistd.h>
#include <util.h>
#include <termios.h>

@implementation TTYShellWrapper {
    NSTask       *task;
    void         *context;
    NSString     *workingDirectory;
    NSDictionary *environment;
    NSString     *launchPath;
    NSArray      *arguments;

    NSFileHandle *inputHandle;
    NSFileHandle *fileHandle;
    pid_t        childProcessID;

    BOOL         stdoutEmpty;
    BOOL         taskDidTerminate;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:inputHandle];
}

- (id)initWithLaunchPath:(NSString *)launch workingDirectory:(NSString *)directoryPath environment:(NSDictionary *)env arguments:(NSArray *)args context:(void *)pointer {
    if ((self = [super init])) {
        context            = pointer;
        launchPath         = launch;
        arguments          = args;
        environment        = env;
        workingDirectory   = directoryPath;
        _terminationStatus = -1;
    }
    return self;
}

- (void)startProcess {
    if (ObjCShell.isCMDEnvironment) {
        inputHandle = [NSFileHandle fileHandleWithStandardInput];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getInput:) name:NSFileHandleDataAvailableNotification object:inputHandle];
    }

    int amaster;
    pid_t pid = forkpty(&amaster, nil, nil, nil);
    if (pid > 0) {
        fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:amaster closeOnDealloc:YES];
        childProcessID = pid;
        dispatch_async(dispatch_queue_create("TTY Shell Reader Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
            while (!self->taskDidTerminate) {
                [self appendOutput:self->fileHandle.availableData];
            }
            self->stdoutEmpty = YES;
            [self cleanup];
        });
        dispatch_async(dispatch_queue_create("TTY Shell Wait Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
            int status = 0;
            waitpid(self->childProcessID, &status, 0);
            self.terminationStatus = WEXITSTATUS(status);
            self->taskDidTerminate = YES;
        });
    } else if (pid == 0) {
        setsid();
        [environment enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL * _Nonnull stop) {
            setenv([key UTF8String], [obj UTF8String], 1);
        }];
        if (workingDirectory) {
            chdir(workingDirectory.UTF8String);
        }

        NSUInteger count = [arguments count];
        char **cargs = (char **) malloc(sizeof(char *) * (count + 1));
        //cargs is a pointer to 4 pointers to char

        int i;
        for(i = 0; i < count; i++) {
            NSString *s = [arguments objectAtIndex:i];//get a NSString
            const char *cstr = [s cStringUsingEncoding:NSUTF8StringEncoding];//get cstring
            NSUInteger len = strlen(cstr);//get its length
            char *cstr_copy = (char *) malloc(sizeof(char) * (len + 1));//allocate memory, + 1 for ending '\0'
            strcpy(cstr_copy, cstr);//make a copy
            cargs[i] = cstr_copy;//put the point in cargs
        }
        cargs[i] = NULL;

        execvp(launchPath.UTF8String, cargs);
        // "Returning from `execute` means the command was failed. This is unrecoverable error in child process side, so just abort the execution."s
    } else {
        NSLog(@"error");
    }
}


// This method is called asynchronously when data is available from the task's file handle.
// We just pass the data along to the controller as an NSString.
- (void)getData:(NSNotification *)aNotification {
    id notificationObject = [aNotification object];
    NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];

    // If the length of the data is zero, then the task is basically over - there is nothing
    // more to get from the handle so we may as well shut down.
    if ([data length]) {
        [self appendOutput:data];
    }

    // we need to schedule the file handle go read more data in the background again.
    [notificationObject readInBackgroundAndNotify];
}

- (void)getInput:(NSNotification *)aNotification {
    NSFileHandle *inputHandle = aNotification.object;
    if (inputHandle.readable) {
        [self appendInput:inputHandle.availableData];
    }
    [inputHandle waitForDataInBackgroundAndNotify];
}

- (void)appendOutput:(NSData *)data {
    [self.delegate process:self appendOutput:data];
}

- (void)appendInput:(nonnull NSData *)input {
    if (self.finish) {
        return;
    }
    [fileHandle writeData:input];
}


- (void)stopProcess {
    kill(childProcessID, 1);
}

- (void)cleanup {
    [self.delegate processFinished:self withTerminationStatus:self.terminationStatus];
    self.finish = YES;
}

@end
