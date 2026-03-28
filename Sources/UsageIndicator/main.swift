import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    let dataProvider = UsageDataProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(dataProvider: dataProvider)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
