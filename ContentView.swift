import SwiftUI

struct ContentView: View {
    @State private var logs: String = "Ready."
    @State private var isBusy: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Troll Web Inspector")
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
                Button(action: { runInjection() }) {
                    Text("Enable")
                        .bold().frame(maxWidth: .infinity).padding()
                        .background(isBusy ? Color.gray : Color.blue)
                        .foregroundColor(.white).cornerRadius(10)
                }
                .disabled(isBusy)

                Button(action: { runKill() }) {
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

    func runInjection() {
        guard !isBusy else { return }
        isBusy = true
        logs = "Starting...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. Locate Binaries
                guard let injectorPath = Bundle.main.path(forResource: "injector", ofType: nil),
                      let agentPath = Bundle.main.path(forResource: "agent", ofType: "dylib") else {
                    self.appendLog("[-] Error: 'injector' or 'agent.dylib' not found in Bundle.\n")
                    DispatchQueue.main.async { self.isBusy = false }
                    return
                }
                
                // 2. Find PID (using our C utility)
                self.appendLog("[*] Searching for webinspectord...\n")
                let pid = PidForName("webinspectord")
                
                if pid <= 0 {
                    self.appendLog("[-] webinspectord not found. Please enable Web Inspector in Safari Settings and try again.\n")
                    DispatchQueue.main.async { self.isBusy = false }
                    return
                }
                self.appendLog("[+] Found webinspectord at PID \(pid)\n")
                
                // 3. Construct Command
                // injector -p <pid> -f agent.dylib -e entry_main
                let args = [
                    "-p", "\(pid)",
                    "-f", agentPath,
                    "-e", "entry_main"
                ]
                
                self.appendLog("[*] Running: injector \(args.joined(separator: " "))\n")
                
                // 4. Execute as Root
                let receipt = try Execute.rootSpawnWithOutputs(binary: injectorPath, arguments: args)
                
                self.appendLog(receipt.stdout)
                if !receipt.stderr.isEmpty {
                    self.appendLog("[stderr] \(receipt.stderr)\n")
                }
                
                if case .exit(let code) = receipt.terminationReason {
                    if code == 0 {
                        self.appendLog("[+] Injection Successful!\n")
                    } else {
                        self.appendLog("[-] Injector exited with code \(code).\n")
                    }
                }
                
            } catch {
                self.appendLog("[-] Exception: \(error.localizedDescription)\n")
            }
            
            DispatchQueue.main.async { self.isBusy = false }
        }
    }

    func runKill() {
        guard !isBusy else { return }
        isBusy = true
        logs = "Killing webinspectord...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let pid = PidForName("webinspectord")
            if pid > 0 {
                // kill -9 <pid>
                let _ = try? Execute.rootSpawnWithOutputs(binary: "/bin/kill", arguments: ["-9", "\(pid)"])
                self.appendLog("[+] Process killed. It should restart automatically.\n")
            } else {
                self.appendLog("[-] Process not found.\n")
            }
            DispatchQueue.main.async { self.isBusy = false }
        }
    }
}