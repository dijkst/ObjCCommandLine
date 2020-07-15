//
//  TerminalBase.m
//  ObjCCommandLine
//
//  Created by 詹迟晶 on 2020/7/12.
//  Copyright © 2020 dijkst. All rights reserved.
//

#import "TerminalBase.h"
#import "TerminalBase+Private.h"
#import "ObjCShell.h"
#import "NSFileHandle+isReadableAddon.h"

@implementation TerminalBase

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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:inputHandle];
}

- (void)startProcess {
    if (ObjCShell.isCMDEnvironment) {
        inputHandle = [NSFileHandle fileHandleWithStandardInput];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getInput:) name:NSFileHandleDataAvailableNotification object:inputHandle];
    }
}

- (void)runChildProcess {
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
    if (inputHandle.readable && !self.finish) {
        [self appendInput:inputHandle.availableData];
    }
    [inputHandle waitForDataInBackgroundAndNotify];
}

- (void)appendOutput:(NSData *)data {
    if (data.length > 0) {
        [self.delegate process:self appendOutput:data];
    }
}

- (void)appendError:(NSData *)data {
    if (data.length > 0) {
        [self.delegate process:self appendError:data];
    }
}

- (void)appendInput:(nonnull NSData *)input {
    [inputHandle writeData:input];
}

- (BOOL)handleReadable:(NSFileHandle *)handle {
    return !self->taskDidTerminate;
}

- (void)watchSTDOUT:(NSFileHandle *)handle {
    dispatch_async(dispatch_queue_create("STDOUT Reader Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
        while ([self handleReadable:handle]) {
            [self appendOutput:handle.availableData];
        }
        self->stdoutEmpty = YES;
        [self cleanup];
    });
}

- (void)watchSTDERR:(NSFileHandle *)handle {
    dispatch_async(dispatch_queue_create("STDERR Reader Thread", DISPATCH_QUEUE_CONCURRENT), ^(void) {
        while ([self handleReadable:handle]) {
            [self appendError:handle.availableData];
        }
        self->stderrEmpty = YES;
        [self cleanup];
    });
}

- (void)stopProcess {
    kill(childProcessID, 1);
}

- (void)cleanup {
    if (!stdoutEmpty || !stderrEmpty) { return; }
    [self.delegate processFinished:self withTerminationStatus:self.terminationStatus];
    self.finish = YES;
}

@end
