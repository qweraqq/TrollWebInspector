#include <frida-core.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <signal.h>
#include <unistd.h>
#include <stdbool.h>

// ============================================================================
// MARK: - Process Finding Logic (From TrollFools)
// ============================================================================

typedef void (*ProcessEnumeratorCallback)(pid_t pid, const char *executablePath, void *context, bool *stop);

static void TFUtilEnumerateProcesses(ProcessEnumeratorCallback callback, void *context) {
    static int kMaximumArgumentSize = 0;
    if (kMaximumArgumentSize == 0) {
        size_t valSize = sizeof(kMaximumArgumentSize);
        int mib[2] = {CTL_KERN, KERN_ARGMAX};
        if (sysctl(mib, 2, &kMaximumArgumentSize, &valSize, NULL, 0) < 0) kMaximumArgumentSize = 4096;
    }

    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t procInfoLength = 0;
    if (sysctl(mib, 3, NULL, &procInfoLength, NULL, 0) < 0) return;

    struct kinfo_proc *procInfo = malloc(procInfoLength);
    if (!procInfo) return;
    if (sysctl(mib, 3, procInfo, &procInfoLength, NULL, 0) < 0) { free(procInfo); return; }

    int procInfoCnt = (int)(procInfoLength / sizeof(struct kinfo_proc));
    static char *argBuffer = NULL;

    for (int i = 0; i < procInfoCnt; i++) {
        pid_t pid = procInfo[i].kp_proc.p_pid;
        if (pid <= 1) continue;

        size_t argSize = kMaximumArgumentSize;
        int argsMib[3] = {CTL_KERN, KERN_PROCARGS2, pid};
        if (sysctl(argsMib, 3, NULL, &argSize, NULL, 0) < 0) continue;

        argBuffer = (char *)realloc(argBuffer, argSize + 1);
        if (sysctl(argsMib, 3, argBuffer, &argSize, NULL, 0) < 0) continue;

        char *executablePath = argBuffer + sizeof(int);
        bool stop = false;
        if (callback) callback(pid, executablePath, context, &stop);
        if (stop) break;
    }
    free(procInfo);
    // Note: argBuffer is static and reused, leaking one buffer is acceptable for a CLI tool
}

typedef struct { const char *name; pid_t pid; } SearchCtx;

static void FindPidCallback(pid_t pid, const char *path, void *ctx, bool *stop) {
    SearchCtx *c = (SearchCtx *)ctx;
    if (strstr(path, c->name)) { c->pid = pid; }
}

pid_t find_pid(const char *name) {
    SearchCtx ctx = {name, 0};
    TFUtilEnumerateProcesses(FindPidCallback, &ctx);
    return ctx.pid;
}

// ============================================================================
// MARK: - Main Logic
// ============================================================================

int cmd_inject(const char *dylib_path) {
    printf("[*] Searching for webinspectord...\n");
    pid_t pid = find_pid("webinspectord");
    
    if (pid <= 0) {
        printf("[-] webinspectord not found. Please enable Web Inspector in Safari Settings.\n");
        return 1;
    }
    
    printf("[+] Found webinspectord at PID %d\n", pid);
    printf("[*] Injecting %s...\n", dylib_path);

    frida_init();
    FridaInjector *injector = frida_injector_new_inprocess ();
    GError *error = NULL;
    
    frida_injector_inject_library_file_sync(injector, pid, dylib_path, "agent_main", "", NULL, &error);
    
    if (error) {
        printf("[-] Injection Failed: %s\n", error->message);
        g_error_free(error);
        return 1;
    }
    
    printf("[+] Injection Successful!\n");
    frida_injector_close_sync(injector, NULL, NULL);
    g_object_unref(injector);
    frida_deinit();
    return 0;
}

int cmd_kill(void) {
    printf("[*] Searching for webinspectord...\n");
    pid_t pid = find_pid("webinspectord");
    if (pid > 0) {
        printf("[*] Killing PID %d...\n", pid);
        kill(pid, SIGKILL);
        printf("[+] Killed.\n");
    } else {
        printf("[-] Process not found.\n");
    }
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    
    // Check for root (Execute.swift should handle this, but good to verify)
    if (geteuid() != 0) {
        printf("[!] Warning: Not running as root. sysctl might fail.\n");
        // Try to setuid just in case
        setuid(0);
    }

    if (strcmp(argv[1], "inject") == 0 && argc == 3) {
        return cmd_inject(argv[2]);
    } else if (strcmp(argv[1], "kill") == 0) {
        return cmd_kill();
    }
    
    return 1;
}