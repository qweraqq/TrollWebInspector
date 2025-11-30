import Foundation
import Darwin

// MARK: - Dummy Logger
struct DDLog { static let sharedInstance = DDLog() }
func DDLogInfo(_ msg: String, ddlog: DDLog = .sharedInstance) { print("[AuxExec][INFO] \(msg)") }
func DDLogError(_ msg: String, ddlog: DDLog = .sharedInstance) { print("[AuxExec][ERROR] \(msg)") }
func DDLogWarn(_ msg: String, ddlog: DDLog = .sharedInstance) { print("[AuxExec][WARN] \(msg)") }

// MARK: - C Bridges
@discardableResult
@_silgen_name("posix_spawn_file_actions_addchdir_np")
private func posix_spawn_file_actions_addchdir_np(_ attr: UnsafeMutablePointer<posix_spawn_file_actions_t?>, _ dir: UnsafePointer<Int8>) -> Int32

@discardableResult
@_silgen_name("posix_spawnattr_set_persona_np")
private func posix_spawnattr_set_persona_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ persona_id: uid_t, _ flags: UInt32) -> Int32

@discardableResult
@_silgen_name("posix_spawnattr_set_persona_uid_np")
private func posix_spawnattr_set_persona_uid_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ persona_id: uid_t) -> Int32

@discardableResult
@_silgen_name("posix_spawnattr_set_persona_gid_np")
private func posix_spawnattr_set_persona_gid_np(_ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ persona_id: gid_t) -> Int32

class AuxiliaryExecute {
    static let local = AuxiliaryExecute()
    internal static let maxTimeoutValue: Double = 2147483647
    
    internal static let pipeControlQueue = DispatchQueue(label: "wiki.qaq.AuxiliaryExecute.pipeRead", qos: .userInteractive, attributes: .concurrent)
    internal static let processControlQueue = DispatchQueue(label: "wiki.qaq.AuxiliaryExecute.processControl", qos: .userInteractive, attributes: [])
    
    private init() {}

    enum ExecuteError: Error, LocalizedError, Codable {
        case commandNotFound
        case commandInvalid
        case openFilePipeFailed
        case posixSpawnFailed(Int32, String) // FIX: Now carries the error code
        case waitPidFailed
        case timeout
    }

    enum TerminationReason: Codable {
        case exit(Int32)
        case uncaughtSignal(Int32)
    }

    struct PersonaOptions: Codable {
        let uid: uid_t
        let gid: gid_t
    }

    struct ExecuteReceipt: Codable {
        let terminationReason: TerminationReason
        let pid: Int
        let wait: Int
        let error: ExecuteError?
        let stdout: String
        let stderr: String

        internal static func failure(error: AuxiliaryExecute.ExecuteError?) -> ExecuteReceipt {
            .init(terminationReason: .uncaughtSignal(0), pid: -1, wait: -1, error: error, stdout: "", stderr: "")
        }
    }
}

// MARK: - Spawn Implementation
private func WIFEXITED(_ status: Int32) -> Bool { _WSTATUS(status) == 0 }
private func _WSTATUS(_ status: Int32) -> Int32 { status & 0x7F }
private func WIFSIGNALED(_ status: Int32) -> Bool { (_WSTATUS(status) != 0) && (_WSTATUS(status) != 0x7F) }
private func WEXITSTATUS(_ status: Int32) -> Int32 { (status >> 8) & 0xFF }
private func WTERMSIG(_ status: Int32) -> Int32 { status & 0x7F }
private let POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE = UInt32(1)

extension AuxiliaryExecute {
    static func spawn(
        command: String,
        args: [String] = [],
        environment: [String: String] = [:],
        workingDirectory: String? = nil,
        personaOptions: PersonaOptions? = nil,
        timeout: Double = 0,
        setPid: ((pid_t) -> Void)? = nil,
        output: ((String) -> Void)? = nil
    ) -> ExecuteReceipt {
        let outputLock = NSLock()
        return spawn(
            command: command,
            args: args,
            environment: environment,
            workingDirectory: workingDirectory,
            personaOptions: personaOptions,
            timeout: timeout,
            setPid: setPid,
            stdoutBlock: { str in outputLock.lock(); output?(str); outputLock.unlock() },
            stderrBlock: { str in outputLock.lock(); output?(str); outputLock.unlock() }
        )
    }

    static func spawn(
        command: String,
        args: [String] = [],
        environment: [String: String] = [:],
        workingDirectory: String? = nil,
        personaOptions: PersonaOptions? = nil,
        timeout: Double = 0,
        setPid: ((pid_t) -> Void)? = nil,
        stdoutBlock: ((String) -> Void)? = nil,
        stderrBlock: ((String) -> Void)? = nil,
        completionBlock: ((ExecuteReceipt) -> Void)? = nil
    ) -> ExecuteReceipt {
        let sema = DispatchSemaphore(value: 0)
        var receipt: ExecuteReceipt!
        spawnAsync(
            command: command,
            args: args,
            environment: environment,
            workingDirectory: workingDirectory,
            personaOptions: personaOptions,
            timeout: timeout,
            setPid: setPid,
            stdoutBlock: stdoutBlock,
            stderrBlock: stderrBlock
        ) {
            receipt = $0
            sema.signal()
        }
        sema.wait()
        return receipt
    }

    static func spawnAsync(
        command: String,
        args: [String] = [],
        environment: [String: String] = [:],
        workingDirectory: String? = nil,
        personaOptions: PersonaOptions? = nil,
        timeout: Double = 0,
        ddlog: DDLog = .sharedInstance,
        setPid: ((pid_t) -> Void)? = nil,
        stdoutBlock: ((String) -> Void)? = nil,
        stderrBlock: ((String) -> Void)? = nil,
        completionBlock: ((ExecuteReceipt) -> Void)? = nil
    ) {
        var attrs: posix_spawnattr_t?
        posix_spawnattr_init(&attrs)
        defer { posix_spawnattr_destroy(&attrs) }

        if let personaOptions = personaOptions {
            posix_spawnattr_set_persona_np(&attrs, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE)
            posix_spawnattr_set_persona_uid_np(&attrs, personaOptions.uid)
            posix_spawnattr_set_persona_gid_np(&attrs, personaOptions.gid)
        }

        var pipestdout: [Int32] = [0, 0]
        var pipestderr: [Int32] = [0, 0]
        let bufsiz = Int(exactly: BUFSIZ) ?? 65535

        pipe(&pipestdout)
        pipe(&pipestderr)
        _ = fcntl(pipestdout[0], F_SETFL, O_NONBLOCK)
        _ = fcntl(pipestderr[0], F_SETFL, O_NONBLOCK)

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_addclose(&fileActions, pipestdout[0])
        posix_spawn_file_actions_addclose(&fileActions, pipestderr[0])
        posix_spawn_file_actions_adddup2(&fileActions, pipestdout[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, pipestderr[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, pipestdout[1])
        posix_spawn_file_actions_addclose(&fileActions, pipestderr[1])

        if let workingDirectory = workingDirectory {
            posix_spawn_file_actions_addchdir_np(&fileActions, workingDirectory)
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        var realEnvironmentBuilder: [String] = []
        var envBuilder = [String: String]()
        var currentEnv = environ
        while let rawStr = currentEnv.pointee {
            defer { currentEnv += 1 }
            let str = String(cString: rawStr)
            guard let key = str.components(separatedBy: "=").first else { continue }
            let value = String(str.dropFirst("\(key)=".count))
            envBuilder[key] = value
        }
        for (key, value) in environment { envBuilder[key] = value }
        for (key, value) in envBuilder { realEnvironmentBuilder.append("\(key)=\(value)") }
        
        let realEnv: [UnsafeMutablePointer<CChar>?] = realEnvironmentBuilder.map { $0.withCString(strdup) }
        defer { for case let env? in realEnv { free(env) } }

        let args = [command] + args
        let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
        defer { for case let arg? in argv { free(arg) } }

        var pid: pid_t = 0
        let spawnStatus = posix_spawn(&pid, command, &fileActions, &attrs, argv + [nil], realEnv + [nil])
        
        // FIX: Capture and report the error code
        if spawnStatus != 0 {
            let errorMsg = String(cString: strerror(spawnStatus))
            DDLogError("posix_spawn failed with error \(spawnStatus): \(errorMsg)")
            completionBlock?(ExecuteReceipt.failure(error: .posixSpawnFailed(spawnStatus, errorMsg)))
            return
        }

        DDLogInfo("Spawned process \(pid) command \(args.joined(separator: " "))")
        setPid?(pid)
        close(pipestdout[1])
        close(pipestderr[1])

        var stdoutStr = ""
        var stderrStr = ""

        let stdoutSource = DispatchSource.makeReadSource(fileDescriptor: pipestdout[0], queue: pipeControlQueue)
        let stderrSource = DispatchSource.makeReadSource(fileDescriptor: pipestderr[0], queue: pipeControlQueue)
        let stdoutSem = DispatchSemaphore(value: 0)
        let stderrSem = DispatchSemaphore(value: 0)

        stdoutSource.setCancelHandler { close(pipestdout[0]); stdoutSem.signal() }
        stderrSource.setCancelHandler { close(pipestderr[0]); stderrSem.signal() }

        stdoutSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }
            let bytesRead = read(pipestdout[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1, errno == EAGAIN { return }
                stdoutSource.cancel()
                return
            }
            let data = Data(bytes: buffer, count: bytesRead)
            if let str = String(data: data, encoding: .utf8) {
                stdoutStr += str
                stdoutBlock?(str)
            }
        }
        
        stderrSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }
            let bytesRead = read(pipestderr[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1, errno == EAGAIN { return }
                stderrSource.cancel()
                return
            }
            let data = Data(bytes: buffer, count: bytesRead)
            if let str = String(data: data, encoding: .utf8) {
                stderrStr += str
                stderrBlock?(str)
            }
        }

        stdoutSource.resume()
        stderrSource.resume()

        let realTimeout = timeout > 0 ? timeout : maxTimeoutValue
        let wallTimeout = DispatchTime.now() + (TimeInterval(exactly: realTimeout) ?? maxTimeoutValue)

        var status: Int32 = 0
        var waitResult: Int32 = 0
        var isTimeout = false

        let timerSource = DispatchSource.makeTimerSource(flags: [], queue: processControlQueue)
        timerSource.setEventHandler {
            isTimeout = true
            kill(pid, SIGKILL)
        }

        let processSource = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: processControlQueue)
        processSource.setEventHandler {
            repeat { waitResult = waitpid(pid, &status, 0) } while waitResult == -1 && errno == EINTR
            processSource.cancel()
            timerSource.cancel()
            stdoutSem.wait()
            stderrSem.wait()

            let terminationReason: TerminationReason
            if WIFSIGNALED(status) {
                terminationReason = .uncaughtSignal(WTERMSIG(status))
            } else {
                terminationReason = .exit(WEXITSTATUS(status))
            }

            let receipt = ExecuteReceipt(
                terminationReason: terminationReason,
                pid: Int(pid),
                wait: Int(waitResult),
                error: isTimeout ? .timeout : nil,
                stdout: stdoutStr,
                stderr: stderrStr
            )
            completionBlock?(receipt)
        }
        processSource.resume()
        timerSource.schedule(deadline: wallTimeout)
        timerSource.resume()
    }
}