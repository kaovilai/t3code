import UIKit
import UniformTypeIdentifiers

let logPath = "/tmp/dropprobe-17721.log"
func log(_ s: String) {
  let line = s + "\n"
  if let h = FileHandle(forWritingAtPath: logPath) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
  else { try? line.write(toFile: logPath, atomically: true, encoding: .utf8) }
}
func oldAccepts(_ p: NSItemProvider) -> Bool { p.canLoadObject(ofClass: UIImage.self) }
func newAccepts(_ p: NSItemProvider) -> Bool {
  p.canLoadObject(ofClass: UIImage.self) || p.hasItemConformingToTypeIdentifier(UTType.image.identifier)
}

final class Source: UIImageView, UIDragInteractionDelegate {
  let make: () -> NSItemProvider
  init(label: String, color: UIColor, make: @escaping () -> NSItemProvider) {
    self.make = make
    super.init(frame: .zero)
    isUserInteractionEnabled = true
    backgroundColor = color
    accessibilityLabel = label
    isAccessibilityElement = true
    let l = UILabel(); l.text = label; l.textAlignment = .center; l.translatesAutoresizingMaskIntoConstraints = false
    addSubview(l); l.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true; l.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    addInteraction(UIDragInteraction(delegate: self))
  }
  required init?(coder: NSCoder) { fatalError() }
  func dragInteraction(_ i: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
    log("dragstart \(accessibilityLabel ?? "?")")
    NotificationCenter.default.post(name: .init("dragstart"), object: accessibilityLabel)
    return [UIDragItem(itemProvider: make())]
  }
}

final class VC: UIViewController, UITextDropDelegate, UIDropInteractionDelegate {
  let tv = UITextView()
  let status = UILabel()
  var modeLine = ""
  func png(_ c: UIColor) -> Data {
    UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).pngData { ctx in c.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120)) }
  }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    let img = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { c in UIColor.systemOrange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 120, height: 120)) }
    let pngData = png(.systemPurple)
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("drag-file.png")
    try? png(.systemGreen).write(to: fileURL)
    let sources = [
      Source(label: "src-uiimage", color: .systemOrange) { NSItemProvider(object: img) },
      Source(label: "src-pngdata", color: .systemPurple) {
        let p = NSItemProvider()
        p.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { $0(pngData, nil); return nil }
        return p
      },
      Source(label: "src-file", color: .systemGreen) { NSItemProvider(contentsOf: fileURL)! },
    ]
    let stack = UIStackView(arrangedSubviews: sources)
    stack.distribution = .fillEqually; stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    tv.translatesAutoresizingMaskIntoConstraints = false
    tv.font = .systemFont(ofSize: 20); tv.layer.borderWidth = 1
    tv.accessibilityLabel = "dest"
    tv.textDropDelegate = self
    if CommandLine.arguments.contains("--interaction") { tv.addInteraction(UIDropInteraction(delegate: self)) }   // same wiring as ComposerTextView; allowsEditingTextAttributes left default
    status.translatesAutoresizingMaskIntoConstraints = false; status.numberOfLines = 0; status.font = .systemFont(ofSize: 22, weight: .semibold)
    let mode = CommandLine.arguments.contains("--interaction") ? "AFTER (UIDropInteraction added)" : "BEFORE (textDropDelegate only)"
    status.text = "Mode: \(mode)\nDrag a swatch onto the text box."
    modeLine = status.text!
    NotificationCenter.default.addObserver(forName: .init("dragstart"), object: nil, queue: .main) { [weak self] n in self?.status.text = "\(self!.modeLine)\nDragging \(n.object as? String ?? "?")... no drop event yet" }
    view.addSubview(stack); view.addSubview(tv); view.addSubview(status)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      stack.heightAnchor.constraint(equalToConstant: 160),
      tv.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 30),
      tv.leadingAnchor.constraint(equalTo: stack.leadingAnchor), tv.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
      tv.heightAnchor.constraint(equalToConstant: 200),
      status.topAnchor.constraint(equalTo: tv.bottomAnchor, constant: 20),
      status.leadingAnchor.constraint(equalTo: stack.leadingAnchor), status.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
    ])
  }
  func dropInteraction(_ i: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
    let ps = session.items.map(\.itemProvider)
    let ok = ps.allSatisfy(newAccepts)
    log("UIDropInteraction.canHandle -> \(ok) types=[\(ps.flatMap(\.registeredTypeIdentifiers).joined(separator: ","))]")
    return ok
  }
  func dropInteraction(_ i: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
    log("UIDropInteraction.sessionDidUpdate")
    return UIDropProposal(operation: .copy)
  }
  func dropInteraction(_ i: UIDropInteraction, performDrop session: UIDropSession) {
    log("UIDropInteraction.performDrop")
    status.text = "\(modeLine)\nRESULT: UIDropInteraction.performDrop - drop accepted"
    for p in session.items.map(\.itemProvider) {
      p.loadObject(ofClass: UIImage.self) { o, e in log("  loaded image: \(o is UIImage) \(e?.localizedDescription ?? "")") }
    }
  }
  func providers(_ d: UITextDropRequest) -> [NSItemProvider] { d.dropSession.items.map(\.itemProvider) }
  func textDroppableView(_ v: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal {
    let ps = providers(drop)
    let types = ps.flatMap(\.registeredTypeIdentifiers).joined(separator: ",")
    let msg = "proposalForDrop CALLED types=[\(types)] old=\(ps.allSatisfy(oldAccepts)) new=\(ps.allSatisfy(newAccepts))"
    log(msg); status.text = "\(modeLine)\nRESULT: textDropDelegate proposalForDrop called"
    guard ps.allSatisfy(newAccepts) else { return drop.suggestedProposal }
    let p = UITextDropProposal(operation: .copy); p.dropAction = .insert; p.dropPerformer = .delegate
    return p
  }
  func textDroppableView(_ v: UIView & UITextDroppable, willPerformDrop drop: UITextDropRequest) {
    log("willPerformDrop CALLED")
    status.text = "\(modeLine)\nRESULT: textDropDelegate willPerformDrop - drop accepted"
  }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  func application(_ a: UIApplication, didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    try? FileManager.default.removeItem(atPath: logPath)
    window = UIWindow(frame: UIScreen.main.bounds); window?.rootViewController = VC(); window?.makeKeyAndVisible()
    return true
  }
}
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
