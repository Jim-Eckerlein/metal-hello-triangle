import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSMakeRect(0, 0, NSScreen.main?.frame.width ?? 100, NSScreen.main?.frame.height ?? 100),
                          styleMask: [.miniaturizable, .closable, .resizable, .titled],
                          backing: .buffered,
                          defer: false)
        window?.title = "Metal Hello Triangle"
        window?.makeKeyAndOrderFront(nil)
        
        let viewController = ViewController()
        window?.contentViewController = viewController
        window?.makeFirstResponder(viewController)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}
