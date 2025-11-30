#include <frida-gum.h>
#include <CoreFoundation/CoreFoundation.h>
#include <string.h>

// Prototype for the original function
typedef CFTypeRef (*SecTaskCopyValueForEntitlementFunc)(void *task, CFStringRef entitlement, CFErrorRef *error);
static SecTaskCopyValueForEntitlementFunc original_SecTaskCopyValueForEntitlement = NULL;

// The entitlements we want to enable
static const char *kTargetEntitlements[] = {
    "com.apple.security.get-task-allow",
    "com.apple.webinspector.allow",
    "com.apple.private.webinspector.allow-remote-inspection",
    "com.apple.private.webinspector.allow-carrier-remote-inspection",
    NULL
};

// Replacement function
CFTypeRef replacement_SecTaskCopyValueForEntitlement(void *task, CFStringRef entitlement, CFErrorRef *error) {
    if (entitlement) {
        char buffer[256];
        if (CFStringGetCString(entitlement, buffer, sizeof(buffer), kCFStringEncodingUTF8)) {
            for (int i = 0; kTargetEntitlements[i] != NULL; i++) {
                if (strcmp(buffer, kTargetEntitlements[i]) == 0) {
                    // Call original to maintain internal state if necessary, then discard result
                    CFTypeRef originalResult = original_SecTaskCopyValueForEntitlement(task, entitlement, error);
                    if (originalResult) {
                        CFRelease(originalResult);
                    }
                    // Return kCFBooleanTrue (Web Inspector expects a boolean true for these)
                    return kCFBooleanTrue; 
                }
            }
        }
    }
    return original_SecTaskCopyValueForEntitlement(task, entitlement, error);
}

// Entry point called by Frida upon injection
void agent_main(const gchar *data, gboolean *stay_resident) {
    // FIX 1: Use 1 instead of TRUE to avoid macro conflict between CoreFoundation and Frida
    *stay_resident = 1;

    gum_init_embedded();

    GumInterceptor *interceptor = gum_interceptor_obtain();
    gum_interceptor_begin_transaction(interceptor);

    // FIX 2: Explicitly cast GumAddress (uint64) to void pointer
    void *symbol = (void *)gum_module_find_export_by_name(NULL, "SecTaskCopyValueForEntitlement");
    
    if (symbol) {
        // FIX 3: Add the missing 4th argument (user_data) which is NULL
        gum_interceptor_replace(interceptor, 
                                symbol, 
                                (void *)replacement_SecTaskCopyValueForEntitlement,
                                NULL, // <--- Added missing 'data' argument
                                (void **)&original_SecTaskCopyValueForEntitlement);
    }

    gum_interceptor_end_transaction(interceptor);
}