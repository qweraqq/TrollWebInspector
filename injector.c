#include <frida-core.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <string.h>
#include <unistd.h>

// Logic adapted from TrollFoolsStub.m (TFUtilEnumerateProcessesUsingBlock)
static int get_webinspectord_pid(char *out_error) {
    int mib[3] = {CTL_KERN, KERN_ARGMAX, 0};
    int argmax = 4096;
    size_t size = sizeof(argmax);
    if (sysctl(mib, 2, &argmax, &size, NULL, 0) == -1) {
        argmax = 4096;
    }

    int proc_mib[3] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL};
    size_t proc_len = 0;
    // Get size first
    if (sysctl(proc_mib, 3, NULL, &proc_len, NULL, 0) == -1) return -1;

    struct kinfo_proc *procs = malloc(proc_len);
    if (!procs) return -1;
    
    // Get list
    if (sysctl(proc_mib, 3, procs, &proc_len, NULL, 0) == -1) {
        free(procs);
        return -1;
    }

    int n_procs = proc_len / sizeof(struct kinfo_proc);
    char *arg_buf = malloc(argmax);
    int found_pid = -1;

    for (int i = 0; i < n_procs; i++) {
        pid_t pid = procs[i].kp_proc.p_pid;
        if (pid <= 1) continue;

        // Try to get full arguments (Path)
        int args_mib[3] = {CTL_KERN, KERN_PROCARGS2, pid};
        size_t args_size = argmax;
        
        // 1. Check Path via KERN_PROCARGS2 (Method from TrollFools)
        if (sysctl(args_mib, 3, arg_buf, &args_size, NULL, 0) == 0) {
            // [argc][exec_path]...
            char *exec_path = arg_buf + sizeof(int);
            
            // Check if path ends in /webinspectord
            // The daemon is usually /usr/libexec/webinspectord
            size_t path_len = strlen(exec_path);
            const char *target = "webinspectord";
            size_t target_len = strlen(target);
            snprintf(out_error, 512, "Process %s", exec_path);
            if (path_len >= target_len) {
                if (strcmp(exec_path + path_len - target_len, target) == 0) {
                    // Confirm it's preceded by / or is the start of string
                    if (path_len == target_len || exec_path[path_len - target_len - 1] == '/') {
                        found_pid = pid;
                        break;
                    }
                }
            }
        }
        
        // 2. Fallback: Check p_comm (Process Name) if PROCARGS2 fails
        // This handles cases where arguments are restricted but basic info isn't.
        if (strcmp(procs[i].kp_proc.p_comm, "webinspectord") == 0) {
            found_pid = pid;
            break;
        }
    }

    free(arg_buf);
    free(procs);
    return found_pid;
}

// Exported function for Swift
int perform_injection(const char *agent_path, char *out_error) {
    // 1. Find PID using the native method
    int pid = get_webinspectord_pid(out_error);

    if (pid <= 0) {
        snprintf(out_error, 512, "Process 'webinspectord' not found via sysctl.");
        return 2;
    }

    // 2. Initialize Frida
    frida_init();
    FridaInjector *injector = frida_injector_new();
    GError *error = NULL;
    
    // 3. Inject
    frida_injector_inject_library_file_sync(injector, pid, agent_path, "agent_main", "", NULL, &error);
    
    int result = 0;
    if (error != NULL) {
        snprintf(out_error, 512, "Frida Injection Failed (PID %d): %s", pid, error->message);
        g_error_free(error);
        result = 1;
    } else {
        snprintf(out_error, 512, "Success! Injected into webinspectord (PID %d)", pid);
        result = 0;
    }

    frida_injector_close_sync(injector, NULL, NULL);
    g_object_unref(injector);
    frida_deinit();
    
    return result;
}