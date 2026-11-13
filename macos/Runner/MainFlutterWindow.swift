import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Open wide enough (>= 1000 logical px) for the demo's side-by-side
    // layout: Phone A | Tablet B | Mock server. Clamped to the screen.
    let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let width = min(1240, visible.width - 40)
    let height = min(750, visible.height - 40)
    let frame = NSRect(
      x: visible.minX + 20,
      y: visible.minY + (visible.height - height) / 2,
      width: width,
      height: height
    )
    self.setFrame(frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // macOS may restore the previous window frame after this point; apply the
    // demo frame again once launch has finished, and don't save/restore it.
    self.isRestorable = false
    DispatchQueue.main.async { [weak self] in
      self?.setFrame(frame, display: true)
    }
  }
}
