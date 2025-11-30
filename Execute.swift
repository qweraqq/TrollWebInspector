//
//  Execute.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import Foundation

enum Execute {
    @discardableResult
    static func rootSpawn(
        binary: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) throws -> AuxiliaryExecute.TerminationReason {
        let receipt = AuxiliaryExecute.spawn(
            command: binary,
            args: arguments,
            environment: environment.merging([
                "DISABLE_TWEAKS": "1",
            ], uniquingKeysWith: { $1 }),
            personaOptions: .init(uid: 0, gid: 0)
        )
        if !receipt.stdout.isEmpty {
            print("[Execute] Process \(receipt.pid) output: \(receipt.stdout)")
        }
        if !receipt.stderr.isEmpty {
            print("[Execute] Process \(receipt.pid) error: \(receipt.stderr)")
        }
        return receipt.terminationReason
    }

    static func rootSpawnWithOutputs(
        binary: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) throws -> AuxiliaryExecute.ExecuteReceipt {
        let receipt = AuxiliaryExecute.spawn(
            command: binary,
            args: arguments,
            environment: environment.merging([
                "DISABLE_TWEAKS": "1",
            ], uniquingKeysWith: { $1 }),
            personaOptions: .init(uid: 0, gid: 0)
        )
        if !receipt.stdout.isEmpty {
            print("[Execute] Process \(receipt.pid) output: \(receipt.stdout)")
        }
        if !receipt.stderr.isEmpty {
            print("[Execute] Process \(receipt.pid) error: \(receipt.stderr)")
        }
        return receipt
    }
}