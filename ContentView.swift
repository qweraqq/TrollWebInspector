import SwiftUI
import Foundation

// Bridge to the C function in injection.c
@_silgen_name("perform_injection")
func perform_injection(_ path: UnsafePointer<CChar>, _ errorMsg: UnsafeMutablePointer<CChar>) -> Int32

struct ContentView: View {
    @State private var logs: String = "Ready to inject."
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
                Button(action: { runInjection() }) {
                    Text("Enable")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isBusy ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isBusy)

                Button(action: { runKill() }) {
                    Text("Disable")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isBusy ? Color.gray : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
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
        logs = "Locating agent.dylib...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let bundlePath = Bundle.main.path(forResource: "agent", ofType: "dylib") else {
                self.appendLog("[Error] agent.dylib not found in bundle.\n")
                DispatchQueue.main.async { self.isBusy = false }
                return
            }
            
            self.appendLog("Scanning processes...\n")
            
            // Prepare buffer for error messages
            var errorBuffer = [CChar](repeating: 0, count: 512)
            
            let result = perform_injection(bundlePath, &errorBuffer)
            let message = String(cString: errorBuffer)
            
            self.appendLog("\n[Result Code: \(result)]\n\(message)\n")
            
            DispatchQueue.main.async { self.isBusy = false }
        }
    }

    func runKill() {
        guard !isBusy else { return }
        isBusy = true
        logs = "Restarting webinspectord...\n"
        
        // killall is simple enough to keep spawning, or we could bind kill() but this usually works fine
        let receipt = AuxiliaryExecute.spawn(
            command: "/usr/bin/killall",
            args: ["webinspectord"],
            timeout: 5
        )
        
        if case .exit(let code) = receipt.terminationReason, code == 0 {
            appendLog("[Success] Daemon killed.\n")
        } else {
            appendLog("[Failed] \(receipt.stderr)\n")
        }
        isBusy = false
    }
}