import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    let settings = AppSettings()
    lazy var dataProvider = UsageDataProvider(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(dataProvider: dataProvider, settings: settings)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
