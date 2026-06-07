import Darwin
import Safari

@main
struct ComputerAutomationApp {
    static func main() {
        do {
            let output = try SafariLaunchCommand().execute()
            print(output)
        } catch {
            fputs("Failed to launch Safari: \(error)\n", stderr)
            exit(1)
        }
    }
}
