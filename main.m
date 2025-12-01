#import <Foundation/Foundation.h>
#include <sys/spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdlib.h>

// Access to global environment variables
extern char **environ;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // 1. Elevate to root
        setuid(0);
        setgid(0);
        
        // 2. Validate Arguments
        NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
        if (args.count < 2) {
            NSLog(@"[RootHelper] Error: Missing executable path.");
            return 1;
        }

        NSString *binaryPath = args[1];
        const char *path = [binaryPath UTF8String];
        
        // 3. Create a Pipe to capture output
        // pipefd[0] = Read end (Parent uses this)
        // pipefd[1] = Write end (Child uses this)
        int pipefd[2];
        if (pipe(pipefd) == -1) {
            NSLog(@"[RootHelper] Error: Failed to create pipe.");
            return 1;
        }

        // 4. Configure File Actions for posix_spawn
        posix_spawn_file_actions_t file_actions;
        posix_spawn_file_actions_init(&file_actions);
        
        // Replace Child's STDOUT (1) with our pipe's Write end
        posix_spawn_file_actions_adddup2(&file_actions, pipefd[1], STDOUT_FILENO);
        
        // Replace Child's STDERR (2) with our pipe's Write end (merging output)
        posix_spawn_file_actions_adddup2(&file_actions, pipefd[1], STDERR_FILENO);
        
        // Close the Read end in the child (child doesn't need to read from itself)
        posix_spawn_file_actions_addclose(&file_actions, pipefd[0]);
        
        // Close the original Write end in the child (since it's now duplicated to 1 and 2)
        posix_spawn_file_actions_addclose(&file_actions, pipefd[1]);

        // 5. Prepare Arguments (argv)
        size_t argCount = args.count - 1;
        char **child_argv = malloc(sizeof(char *) * (argCount + 1));
        child_argv[0] = strdup(path);
        for (int i = 2; i < args.count; i++) {
            child_argv[i - 1] = strdup([args[i] UTF8String]);
        }
        child_argv[argCount] = NULL;

        // 6. Spawn the Process
        pid_t pid;
        int status = posix_spawn(&pid, path, &file_actions, NULL, child_argv, environ);
        
        // Clean up memory and file actions
        posix_spawn_file_actions_destroy(&file_actions);
        for (int i = 0; i < argCount; i++) free(child_argv[i]);
        free(child_argv);

        // 7. Important: Close the Write end in the Parent
        // If we don't do this, the read() loop below will never finish (EOF)
        // because the pipe remains open in the parent.
        close(pipefd[1]);

        if (status != 0) {
            NSLog(@"[RootHelper] posix_spawn failed: %s", strerror(status));
            close(pipefd[0]);
            return 1;
        }

        // 8. Read Output Loop
        // We read continuously until the child closes the pipe (process exits)
        NSMutableData *outputData = [NSMutableData data];
        char buffer[4096];
        ssize_t bytesRead = 0;
        
        while ((bytesRead = read(pipefd[0], buffer, sizeof(buffer))) > 0) {
            [outputData appendBytes:buffer length:bytesRead];
        }
        
        // Close the read end now that we are done
        close(pipefd[0]);

        // 9. Log the Output
        NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        if (outputString.length > 0) {
            NSLog(@"[RootHelper] Output:\n%@", outputString);
        } else {
            NSLog(@"[RootHelper] (No output)");
        }

        // 10. Wait for Exit Code
        int waitStatus;
        waitpid(pid, &waitStatus, 0);

        if (WIFEXITED(waitStatus)) {
            int exitCode = WEXITSTATUS(waitStatus);
            NSLog(@"[RootHelper] Process exited with code: %d", exitCode);
            return exitCode;
        } else {
            return 1;
        }
    }
}