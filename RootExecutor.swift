import Foundation
import Darwin // Needed for posix_spawn and C types

struct RootExecutor {
    
    /// path to the embedded RootHelper binary
    private static var helperPath: String? {
        return Bundle.main.path(forResource: "RootHelper", ofType: nil)
    }

    /// Executes a command as root via the embedded helper
    /// - Parameters:
    ///   - binary: The full path to the system binary (e.g., "/bin/rm")
    ///   - arguments: An array of arguments for that binary
    /// - Returns: The exit code (0 = success, anything else = failure)
    @discardableResult
    static func run(binary: String, arguments: [String] = []) -> Int32 {
        guard let helper = helperPath else {
            print("[RootExecutor] Error: RootHelper binary not found in bundle.")
            return -1
        }
        
        // 1. Construct the full argument list
        // Layout: [HelperPath, TargetBinary, Arg1, Arg2, ...]
        let fullArgs = [helper, binary] + arguments
        
        // 2. Convert Swift Strings to C-String Pointers (strdup)
        // We must manually manage this memory.
        let argv: [UnsafeMutablePointer<CChar>?] = fullArgs.map { $0.withCString(strdup) }
        
        // 3. Ensure we free the memory when this scope exits
        defer {
            for case let arg? in argv {
                free(arg)
            }
        }
        
        // 4. Create the null-terminated array required by posix_spawn
        var cArgs = argv
        cArgs.append(nil) // null terminator
        
        // 5. Execute posix_spawn
        var pid: pid_t = 0
        let spawnStatus = posix_spawn(&pid, helper, nil, nil, cArgs, nil)
        
        if spawnStatus != 0 {
            print("[RootExecutor] Error: posix_spawn failed with error code \(spawnStatus)")
            return -1
        }
        
        // 6. Wait for the process to finish
        var waitStatus: Int32 = 0
        waitpid(pid, &waitStatus, 0)
        
        // 7. Extract the exit code
        // WEXITSTATUS macro equivalent in Swift
        let exitCode = (waitStatus >> 8) & 0xFF
        return exitCode
    }
}