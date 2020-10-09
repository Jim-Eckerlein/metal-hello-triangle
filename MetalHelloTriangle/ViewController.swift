import Cocoa
import MetalKit

// Our macOS specific view controller
class ViewController: NSViewController {

    var renderer: Renderer!
    var mtkView: MTKView!

    override func loadView() {
        mtkView = MTKView(frame: NSRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 100, height: NSScreen.main?.frame.height ?? 100))
        
        self.view = mtkView
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice

        guard let renderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        self.renderer = renderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }
    
    override func keyDown(with event: NSEvent) {
        if event.type != .keyDown {
            return
        }
        
        if event.characters == "q" && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            NSApplication.shared.terminate(self)
        }
    }
}
