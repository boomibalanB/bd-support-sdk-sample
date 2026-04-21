import Foundation
import Network

final class NetworkMonitor {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.syncfusion.BoldDeskChatSDK.network")

    private var onChange: ((Bool) -> Void)?

    func start(onChange: @escaping (Bool) -> Void) {
        // Ensure a fresh monitor each time start is called (after stop/cancel)
        monitor?.cancel()
        let newMonitor = NWPathMonitor()
        monitor = newMonitor

        self.onChange = onChange

        newMonitor.pathUpdateHandler = { path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async { onChange(isConnected) }
        }
        newMonitor.start(queue: queue)
    }

    func stop() {
        monitor?.cancel()
        monitor = nil

        onChange = nil
    }
}
