//
//  AMShellWrapper.m
//  CommX
//
//  Created by Andreas on 2002-04-24.
//  Based on TaskWrapper from Apple
//
//  2002-06-17 Andreas Mayer
//  - used defines for keys in AMShellWrapperProcessFinishedNotification userInfo dictionary
//  2002-08-30 Andreas Mayer
//  - removed bug in getData that sent all output to appendError:
//  - added setInputStringEncoding: and setOutputStringEncoding:
//  - reactivated code to clear output pipes when the task is finished
//  2004-06-15 Andreas Mayer
//  - renamed stopProcess to cleanup since that is what it does; stopProcess
//    is meant to just terminate the task so it's issuing a [task terminate] only now
//  - appendOutput: and appendError: do some error handling now
//  2004-08-11 Andreas Mayer
//  - removed AMShellWrapperProcessFinishedNotification notification since
//	it prevented the task from getting deallocated
//  - don't retain stdin/out/errHandle
//
//  I had some trouble to decide when the task had really stopped. The Apple example
//  did only examine the output pipe and exited when it was empty - which I found unreliable.
//
//  This, finally, seems to work: Wait until the output pipe is empty *and* we received
//  the NSTaskDidTerminateNotification. Seems obvious now ...  :)


#import "AMShellWrapper.h"
#import "ObjCShell.h"

@implementation AMShellWrapper

// Do basic initialization

- (id)initWithLaunchPath:(NSString *)launch workingDirectory:(NSString *)directoryPath environment:(NSDictionary *)env arguments:(NSArray *)args context:(void *)pointer {
    if ((self = [super init])) {
        context            = pointer;
        launchPath         = launch;
        arguments          = args;
        environment        = env;
        workingDirectory   = directoryPath;
        _terminationStatus = -1;
        task = [[NSTask alloc] init];
    }
    return self;
}

- (void *)context {
    return context;
}

// must be called in main thread
// readInBackgroundAndNotifyForModes need a active run loop
- (void)startProcess {
    BOOL error = NO;
    // We first let the controller know that we are starting
    [self.delegate processStarted:self];
    // The output of stdout and stderr is sent to a pipe so that we can catch it later
    // and send it along to the controller; we redirect stdin too, so that it accepts
    // input from us instead of the console
    if (stdinPipe == nil) {
        NSPipe *newPipe = [[NSPipe alloc] init];
        if (newPipe) {
            [task setStandardInput:newPipe];
            stdinHandle = [[task standardInput] fileHandleForWriting];
            // we do NOT retain stdinHandle here since it is retained (and released)
            // by the task standardInput pipe (or so I hope ...)
        } else {
            perror("AMShellWrapper - failed to create pipe for stdIn");
            error = YES;
        }
    } else {
        [task setStandardInput:stdinPipe];
        if ([stdinPipe isKindOfClass:[NSPipe class]])
            stdinHandle = [stdinPipe fileHandleForWriting];
        else
            stdinHandle = stdinPipe;
    }

    if (stdoutPipe == nil) {
        NSPipe *newPipe = [[NSPipe alloc] init];
        if (newPipe) {
            [task setStandardOutput:newPipe];
            stdoutHandle = [[task standardOutput] fileHandleForReading];
        } else {
            perror("AMShellWrapper - failed to create pipe for stdOut");
            error = YES;
        }
    } else {
        [task setStandardOutput:stdoutPipe];
        stdoutHandle = stdoutPipe;
    }

    if (stderrPipe == nil) {
        NSPipe *newPipe = [[NSPipe alloc] init];
        if (newPipe) {
            [task setStandardError:newPipe];
            stderrHandle = [[task standardError] fileHandleForReading];
        } else {
            perror("AMShellWrapper - failed to create pipe for stdErr");
            error = YES;
        }
    } else {
        [task setStandardError:stderrPipe];
        stderrHandle = stderrPipe;
    }

    if (!error) {
        // setting the current working directory
        if (workingDirectory != nil)
            [task setCurrentDirectoryPath:workingDirectory];

        // Setting the environment if available
        if (environment != nil)
            [task setEnvironment:environment];

        [task setLaunchPath:launchPath];

        [task setArguments:arguments];

        // Here we register as an observer of the NSFileHandleReadCompletionNotification,
        // which lets us know when there is data waiting for us to grab it in the task's file
        // handle (the pipe to which we connected stdout and stderr above).
        // -getData: will be called when there is data waiting. The reason we need to do this
        // is because if the file handle gets filled up, the task will block waiting to send
        // data and we'll never get anywhere. So we have to keep reading data from the file
        // handle as we go.
        if (stdoutPipe == nil)         // we have to handle this ourselves:
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getData:) name:NSFileHandleReadCompletionNotification object:stdoutHandle];

        if (stderrPipe == nil)         // we have to handle this ourselves:
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getData:) name:NSFileHandleReadCompletionNotification object:stderrHandle];

        if (ObjCShell.isCMDEnvironment) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(waitData:) name:NSFileHandleDataAvailableNotification object:[NSFileHandle fileHandleWithStandardInput]];
        }

        // We tell the file handle to go ahead and read in the background asynchronously,
        // and notify us via the callback registered above when we signed up as an observer.
        // The file handle will send a NSFileHandleReadCompletionNotification when it has
        // data that is available.
        [stdoutHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];
        [stderrHandle readInBackgroundAndNotifyForModes:@[NSRunLoopCommonModes]];

        // since waiting for the output pipes to run dry seems unreliable in terms of
        // deciding wether the task has died, we go the 'clean' route and wait for a notification
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskStopped:) name:NSTaskDidTerminateNotification object:task];

        // we will wait for data in stdout; there may be nothing to receive from stderr
        stdoutEmpty = NO;
        stderrEmpty = YES;

        // launch the task asynchronously
        [task launch];

        // since the notification center does not retain the observer, make sure
        // we don't get deallocated early
    } else {
        [self performSelector:@selector(cleanup) withObject:nil afterDelay:0];
    }
}

// terminate the task
- (void)stopProcess {
    [task terminate];
}

// If the task ends, there is no more data coming through the file handle even when
// the notification is sent, or the process object is released, then this method is called.
- (void)cleanup {
    NSData *data;

    if (taskDidTerminate) {
        // It is important to clean up after ourselves so that we don't leave potentially
        // deallocated objects as observers in the notification center; this can lead to
        // crashes.
        [[NSNotificationCenter defaultCenter] removeObserver:self];

        // Make sure the task has actually stopped!
        //[task terminate];

        // NSFileHandle availableData is a blocking read - what were they thinking? :-/
        // Umm - OK. It comes back when the file is closed. So here we go ...

        // clear stdout
        while ((data = [stdoutHandle availableData]) && [data length]) {
            [self appendOutput:data];
        }

        // clear stderr
        while ((data = [stderrHandle availableData]) && [data length]) {
            [self appendError:data];
        }
        self.terminationStatus = [task terminationStatus];
    }

    // we tell the controller that we finished, via the callback, and then blow away
    // our connection to the controller.  NSTasks are one-shot (not for reuse), so we
    // might as well be too.
    self.finish = YES;
    [self.delegate processFinished:self withTerminationStatus:self.terminationStatus];

    /*
     NSDictionary *userInfo = nil;
     // task has to go so we can't put it in a dictionary ...
     if (task) {
     userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[[task retain] autorelease], AMShellWrapperProcessFinishedNotificationTaskKey, [NSNumber numberWithInt:terminationStatus], AMShellWrapperProcessFinishedNotificationTerminationStatusKey, nil];
     } else {
     userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNull null], AMShellWrapperProcessFinishedNotificationTaskKey, [NSNumber numberWithInt:terminationStatus], AMShellWrapperProcessFinishedNotificationTerminationStatusKey, nil];
     }

     [[NSNotificationCenter defaultCenter] postNotificationName:AMShellWrapperProcessFinishedNotification object:self userInfo:userInfo];
     */


    // we are done; go ahead and kill us if you like ...
}

// input to stdin
- (void)appendInput:(NSData *)input {
    [stdinHandle writeData:input];
}

- (void)closeInput {
    [stdinHandle closeFile];
}

- (void)appendOutput:(NSData *)data {
    [self.delegate process:self appendOutput:data];
}

- (void)appendError:(NSData *)data {
    [self.delegate process:self appendError:data];
}

- (void)waitData:(NSNotification *)aNotification {
    NSFileHandle *handle = aNotification.object;
    NSData *data = [handle availableData];
    if (data.length > 0) {
        [self appendInput:data];
    }
    [handle waitForDataInBackgroundAndNotify];
}

// This method is called asynchronously when data is available from the task's file handle.
// We just pass the data along to the controller as an NSString.
- (void)getData:(NSNotification *)aNotification {
    NSData *data;
    id     notificationObject;

    notificationObject = [aNotification object];
    data               = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];

    // If the length of the data is zero, then the task is basically over - there is nothing
    // more to get from the handle so we may as well shut down.
    if ([data length]) {
        // Send the data on to the controller; we can't just use +stringWithUTF8String: here
        // because -[data bytes] is not necessarily a properly terminated string.
        // -initWithData:encoding: on the other hand checks -[data length]
        if ([notificationObject isEqualTo:stdoutHandle]) {
            [self appendOutput:data];
            stdoutEmpty = NO;
        } else if ([notificationObject isEqualTo:stderrHandle]) {
            [self appendError:data];
            stderrEmpty = NO;
        } else {
            // this should really not happen ...
        }

        // we need to schedule the file handle go read more data in the background again.
        [notificationObject readInBackgroundAndNotify];
    } else {
        if ([notificationObject isEqualTo:stdoutHandle]) {
            stdoutEmpty = YES;
        } else if ([notificationObject isEqualTo:stderrHandle]) {
            stderrEmpty = YES;
        } else {
            // this should really not happen ...
        }
        // if there is no more data in the pipe AND the task did terminate, we are done
        if (stdoutEmpty && stderrEmpty && taskDidTerminate) {
            [self cleanup];
        }
    }

    // we need to schedule the file handle go read more data in the background again.
    //[notificationObject readInBackgroundAndNotify];
}

- (void)taskStopped:(NSNotification *)aNotification {
    if (!taskDidTerminate) {
        taskDidTerminate = YES;
        // did we receive all data?
        if (stdoutEmpty && stderrEmpty) {
            // no data left - do the clean up
            [self cleanup];
        }
    }
}

@end
