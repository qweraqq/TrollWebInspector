//
//  AuxiliaryExecute.swift
//  TrollFools
//
//  Created by Lakr Aream on 2021/11/27.
//

import Foundation

/// Execute command or shell with posix, shared with AuxiliaryExecute.local
public class AuxiliaryExecute {
    /// we do not recommend you to subclass this singleton
    public static let local = AuxiliaryExecute()

    // system path
    internal var currentPath: [String] = []
    // system binary table
    internal var binaryTable: [String: String] = [:]

    // for you to put your own search path
    internal var extraSearchPath: [String] = []
    // for you to set your own binary table and will be used firstly
    internal var overwriteTable: [String: String?] = [:]

    // this value is used when providing 0 or negative timeout paramete
    internal static let maxTimeoutValue: Double = 2147483647

    /// when reading from file pipe, must called from async queue
    internal static let pipeControlQueue = DispatchQueue(
        label: "wiki.qaq.AuxiliaryExecute.pipeRead",
        qos: .userInteractive,
        attributes: .concurrent
    )

    /// when killing process or monitoring events from process, must called from async queue
    internal static let processControlQueue = DispatchQueue(
        label: "wiki.qaq.AuxiliaryExecute.processControl",
        qos: .userInteractive,
        attributes: []
    )

    /// used for setting binary table, avoid crash
    internal let lock = NSLock()

    private init() {}

    /// Execution Error
    public enum ExecuteError: Error, LocalizedError, Codable {
        case commandNotFound
        case commandInvalid
        case openFilePipeFailed
        case posixSpawnFailed
        case waitPidFailed
        case timeout
    }

    public enum TerminationReason: Codable {
        case exit(Int32)
        case uncaughtSignal(Int32)
    }

    public struct PersonaOptions: Codable {
        let uid: uid_t
        let gid: gid_t
    }

    /// Execution Receipt
    public struct ExecuteReceipt: Codable {
        public let terminationReason: TerminationReason
        public let pid: Int
        public let wait: Int
        public let error: ExecuteError?
        public let stdout: String
        public let stderr: String

        internal init(
            terminationReason: TerminationReason,
            pid: Int,
            wait: Int,
            error: AuxiliaryExecute.ExecuteError?,
            stdout: String,
            stderr: String
        ) {
            self.terminationReason = terminationReason
            self.pid = pid
            self.wait = wait
            self.error = error
            self.stdout = stdout
            self.stderr = stderr
        }

        internal static func failure(
            terminationReason: TerminationReason = .uncaughtSignal(0),
            pid: Int = -1,
            wait: Int = -1,
            error: AuxiliaryExecute.ExecuteError?,
            stdout: String = "",
            stderr: String = ""
        ) -> ExecuteReceipt {
            .init(
                terminationReason: terminationReason,
                pid: pid,
                wait: wait,
                error: error,
                stdout: stdout,
                stderr: stderr
            )
        }
    }
}