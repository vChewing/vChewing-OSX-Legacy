// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public class Notifier: NSWindowController {
  public static func notify(message: String) {
    DispatchQueue.main.async { Self.message = message }
  }

  static var message: String = "" {
    didSet {
      if !Self.message.isEmpty {
        Self.message = Notifier(message).blankValue
      }
    }
  }

  private var currentMessage: String // 承載該副本在初期化時被傳入的訊息內容。
  private var isNew = true // 新通知標記。

  // MARK: - Private Declarations

  private static var instanceSet: NSMutableOrderedSet = .init()
  private let blankValue = ""

  @discardableResult private init(_ message: String) {
    currentMessage = message
    let rawMessage = message.replacingOccurrences(of: "\n", with: "")
    let isDuplicated: Bool = {
      if let firstInstanceExisted = Self.instanceSet.firstNotifier {
        return message == firstInstanceExisted.currentMessage && firstInstanceExisted.isNew
      }
      return false
    }()
    guard let screenRect = NSScreen.main?.visibleFrame, !rawMessage.isEmpty, !isDuplicated else {
      super.init(window: nil)
      return
    }
    // 剔除溢出的副本，讓 Swift 自動回收之。
    while Self.instanceSet.count > 3 {
      if let instanceToRemove = Self.instanceSet.lastNotifier {
        instanceToRemove.close()
        Self.instanceSet.remove(instanceToRemove)
      }
    }
    // 正式進入處理環節。
    defer {
      // 先讓新通知標記自此開始過 0.3 秒自動變為 false。
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.isNew = false
      }
    }
    let kLargeFontSize: Double = 17
    let kSmallFontSize: Double = 15
    let messageArray = message.components(separatedBy: "\n")

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .center
    let attrTitle: [NSAttributedString.Key: AnyObject] = [
      .foregroundColor: NSColor.controlTextColor,
      .font: NSFont.boldSystemFont(ofSize: kLargeFontSize),
      .paragraphStyle: paraStyle,
    ]
    let attrString = NSMutableAttributedString(string: messageArray[0], attributes: attrTitle)
    let attrAlt: [NSAttributedString.Key: AnyObject] = [
      .foregroundColor: NSColor.controlTextColor,
      .font: NSFont.systemFont(ofSize: kSmallFontSize),
      .paragraphStyle: paraStyle,
    ]
    let additionalString = messageArray.count > 1 ? "\n\(messageArray[1])" : ""
    let attrStringAlt = NSMutableAttributedString(string: additionalString, attributes: attrAlt)
    attrString.insert(attrStringAlt, at: attrString.length)

    let textWH = attrString.boundingDimension
    let windowWidth = Double(4) * kLargeFontSize + textWH.width
    let contentRect = NSRect(x: 0, y: 0, width: windowWidth, height: 60.0)
    var windowRect = contentRect
    windowRect.origin.x = screenRect.maxX - windowRect.width - 10
    windowRect.origin.y = screenRect.maxY - windowRect.height - 10
    let styleMask: NSWindow.StyleMask = [.borderless]

    let transparentVisualEffect = NSView()

    let theWindow = NSWindow(
      contentRect: windowRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    theWindow.contentView = transparentVisualEffect
    theWindow.isMovableByWindowBackground = true
    theWindow.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)))
    theWindow.hasShadow = true
    theWindow.backgroundColor = .textBackgroundColor
    theWindow.title = ""
    theWindow.showsToolbarButton = false
    theWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.miniaturizeButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.closeButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
    theWindow.isReleasedWhenClosed = true
    theWindow.isMovable = false

    let lblMessage = NSTextField()
    lblMessage.attributedStringValue = attrString
    lblMessage.drawsBackground = false
    lblMessage.font = .boldSystemFont(ofSize: NSFont.systemFontSize(for: .regular))
    lblMessage.frame = contentRect
    lblMessage.isBezeled = false
    lblMessage.isEditable = false
    lblMessage.isSelectable = false
    lblMessage.textColor = .controlTextColor
    theWindow.contentView?.addSubview(lblMessage)

    let x = lblMessage.frame.origin.x
    let y = ((theWindow.frame.height) - textWH.height) / 1.9
    let newFrame = NSRect(x: x, y: y, width: theWindow.frame.width, height: textWH.height)
    lblMessage.frame = newFrame

    super.init(window: theWindow)
    display()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func close() {
    super.close()
  }
}

// MARK: - Private Functions

extension Notifier {
  private func shiftExistingWindowPositions() {
    guard let window = window else { return }
    Self.instanceSet.arrayOfWindows.forEach { theInstanceWindow in
      var theOrigin = theInstanceWindow.frame
      theOrigin.origin.y -= (10 + window.frame.height)
      theInstanceWindow.setFrame(theOrigin, display: true)
    }
  }

  private func performDisplayLifetime() {
    guard let window = window else { return }
    Self.instanceSet.insert(self, at: 0)
    var afterRect = window.frame
    var beforeRect = afterRect
    beforeRect.origin.x -= 20
    window.setFrame(beforeRect, display: true)
    window.orderFront(self)
    window.setFrame(afterRect, display: true, animate: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
      beforeRect = window.frame
      afterRect = window.frame
      afterRect.origin.x += 20
      window.setFrame(afterRect, display: true, animate: true)
      self.close()
      Self.instanceSet.remove(self)
    }
  }

  private func display() {
    Self.instanceSet.arrayOfWindows.enumerated().forEach { id, theInstance in
      theInstance.alphaValue *= Double(pow(0.4, Double(id + 1)))
      theInstance.contentView?.subviews.forEach {
        $0.alphaValue *= Double(pow(0.6, Double(id + 1)))
      }
    }
    shiftExistingWindowPositions()
    DispatchQueue.main.async {
      self.performDisplayLifetime()
    }
  }
}

private extension NSMutableOrderedSet {
  var arrayOfWindows: [NSWindow] { compactMap { ($0 as? Notifier)?.window } }

  var firstNotifier: Notifier? {
    for neta in self { if let result = neta as? Notifier { return result } }
    return nil
  }

  var lastNotifier: Notifier? {
    for neta in reversed { if let result = neta as? Notifier { return result } }
    return nil
  }
}
