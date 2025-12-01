#import <Foundation/Foundation.h>
#include <sys/types.h>
FOUNDATION_EXTERN void TFUtilKillAll(NSString *processPath, BOOL softly);
FOUNDATION_EXTERN pid_t PidForName(NSString *procName);