import SwiftUI

struct ContentView: View {
    @State private var logs: String = "Ready."
    @State private var isBusy: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Web Inspector Enabler")
                .font(.headline)
                .padding(.top)

            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal)

            HStack(spacing: 20) {
                Button(action: { runAction(command: "inject") }) {
                    Text("Enable")
                        .bold().frame(maxWidth: .infinity).padding()
                        .background(isBusy ? Color.gray : Color.blue)
                        .foregroundColor(.white).cornerRadius(10)
                }
                .disabled(isBusy)

                Button(action: { runAction(command: "kill") }) {
                    Text("Disable")
                        .bold().frame(maxWidth: .infinity).padding()
                        .background(isBusy ? Color.gray : Color.red)
                        .foregroundColor(.white).cornerRadius(10)
                }
                .disabled(isBusy)
            }
            .padding()
        }
    }
    
    func appendLog(_ text: String) {
        DispatchQueue.main.async { self.logs += text }
    }

    func runAction(command: String) {
        guard !isBusy else { return }
        isBusy = true
        logs = "Running...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let helperPath = Bundle.main.path(forResource: "helper", ofType: nil) else {
                    self.appendLog("[-] Helper binary not found.\n")
                    DispatchQueue.main.async { self.isBusy = false }
                    return
                }
                
                var args = [command]
                if command == "inject" {
                    guard let agentPath = Bundle.main.path(forResource: "agent", ofType: "dylib") else {
                        self.appendLog("[-] Agent dylib not found.\n")
                        DispatchQueue.main.async { self.isBusy = false }
                        return
                    }
                    args.append(agentPath)
                }
                
                self.appendLog("[*] Spawning helper as root...\n")
                
                // Using the User-Provided Execute.swift Logic
                let receipt = try Execute.rootSpawnWithOutputs(binary: helperPath, arguments: args)
                
                self.appendLog(receipt.stdout)
                self.appendLog(receipt.stderr)
                
                if case .exit(let code) = receipt.terminationReason {
                    self.appendLog("\n[Done] Exit Code: \(code)\n")
                }
                
            } catch {
                self.appendLog("[-] Error: \(error.localizedDescription)\n")
            }
            
            DispatchQueue.main.async { self.isBusy = false }
        }
    }
}