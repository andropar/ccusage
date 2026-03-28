import Foundation
import ServiceManagement
import Combine

class AppSettings: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }
    @Published var refreshInterval: TimeInterval {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    init() {
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        let stored = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = stored > 0 ? stored : 60
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Re-sync state if registration fails (e.g. app not in /Applications)
            DispatchQueue.main.async {
                self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
        }
    }
}
