// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public class TooltipUI: NSWindowController {
  private var messageText: NSTextField
  private var tooltip: String = "" {
    didSet {
      var text = tooltip
      if direction == .vertical {
        text = text.replacingOccurrences(of: "˙", with: "･")
        text = text.replacingOccurrences(of: "\u{A0}", with: "　")
        text = text.replacingOccurrences(of: "+", with: "")
        text = text.replacingOccurrences(of: "Shift", with: "⇧")
        text = text.replacingOccurrences(of: "Control", with: "⌃")
        text = text.replacingOccurrences(of: "Enter", with: "⏎")
        text = text.replacingOccurrences(of: "Command", with: "⌘")
        text = text.replacingOccurrences(of: "Delete", with: "⌦")
        text = text.replacingOccurrences(of: "BackSpace", with: "⌫")
        text = text.replacingOccurrences(of: "Space", with: "␣")
        text = text.replacingOccurrences(of: "SHIFT", with: "⇧")
        text = text.replacingOccurrences(of: "CONTROL", with: "⌃")
        text = text.replacingOccurrences(of: "ENTER", with: "⏎")
        text = text.replacingOccurrences(of: "COMMAND", with: "⌘")
        text = text.replacingOccurrences(of: "DELETE", with: "⌦")
        text = text.replacingOccurrences(of: "BACKSPACE", with: "⌫")
        text = text.replacingOccurrences(of: "SPACE", with: "␣")
      }

      let attrString: NSMutableAttributedString = .init(string: text)
      let verticalAttributes: [NSAttributedString.Key: Any] = [
        .verticalGlyphForm: true,
        .paragraphStyle: {
          let newStyle = NSMutableParagraphStyle()
          let fontSize = messageText.font?.pointSize ?? NSFont.systemFontSize
          newStyle.lineSpacing = 1
          newStyle.maximumLineHeight = fontSize
          newStyle.minimumLineHeight = fontSize
          return newStyle
        }(),
      ]

      if direction == .vertical {
        attrString.setAttributes(
          verticalAttributes, range: NSRange(location: 0, length: attrString.length)
        )
      }

      messageText.attributedStringValue = attrString
      adjustSize()
    }
  }

  public var direction: NSUserInterfaceLayoutOrientation = .horizontal {
    didSet {
      if #unavailable(macOS 10.14) {
        direction = .horizontal
      }
    }
  }

  public init() {
    let contentRect = NSRect(x: 128.0, y: 128.0, width: 300.0, height: 20.0)
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 2)
    panel.hasShadow = true
    panel.backgroundColor = NSColor.controlBackgroundColor
    panel.isMovable = false
    messageText = NSTextField()
    messageText.isEditable = false
    messageText.isSelectable = false
    messageText.isBezeled = false
    messageText.textColor = NSColor.textColor
    messageText.drawsBackground = true
    messageText.backgroundColor = NSColor.clear
    messageText.textColor = NSColor.textColor
    messageText.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    messageText.needsDisplay = true
    panel.contentView?.addSubview(messageText)
    super.init(window: panel)
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func show(
    tooltip: String = "", at point: NSPoint,
    bottomOutOfScreenAdjustmentHeight heightDelta: Double,
    direction: NSUserInterfaceLayoutOrientation = .horizontal, duration: Double = 0
  ) {
    self.direction = direction
    self.tooltip = tooltip
    window?.setIsVisible(false)
    window?.orderFront(nil)
    set(windowTopLeftPoint: point, bottomOutOfScreenAdjustmentHeight: heightDelta, useGCD: false)
    window?.setIsVisible(true)
    if duration > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
        self.window?.orderOut(nil)
      }
    }
  }

  public func setColor(state: TooltipColorState) {
    var backgroundColor = NSColor(
      red: 0.12, green: 0.12, blue: 0.12, alpha: 1.00
    )
    var textColor = NSColor(
      red: 0.9, green: 0.9, blue: 0.9, alpha: 1.00
    )
    switch state {
    case .normal:
      backgroundColor = NSColor(
        red: 0.12, green: 0.12, blue: 0.12, alpha: 1.00
      )
      textColor = NSColor(
        red: 0.9, green: 0.9, blue: 0.9, alpha: 1.00
      )
    case .redAlert:
      backgroundColor = NSColor(
        red: 0.55, green: 0.00, blue: 0.00, alpha: 1.00
      )
      textColor = NSColor.white
    case .warning:
      backgroundColor = NSColor.purple
      textColor = NSColor.white
    case .succeeded:
      backgroundColor = NSColor(
        red: 0.21, green: 0.15, blue: 0.02, alpha: 1.00
      )
      textColor = NSColor.white
    case .denialOverflow:
      backgroundColor = NSColor(
        red: 0.13, green: 0.08, blue: 0.00, alpha: 1.00
      )
      textColor = NSColor(
        red: 1.00, green: 0.60, blue: 0.00, alpha: 1.00
      )
    case .denialInsufficiency:
      backgroundColor = NSColor(
        red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00
      )
      textColor = NSColor(
        red: 0.88, green: 0.88, blue: 0.88, alpha: 1.00
      )
    case .prompt:
      backgroundColor = NSColor(
        red: 0.09, green: 0.15, blue: 0.15, alpha: 1.00
      )
      textColor = NSColor(
        red: 0.91, green: 0.95, blue: 0.92, alpha: 1.00
      )
    }
    window?.backgroundColor = backgroundColor
    messageText.backgroundColor = backgroundColor
    messageText.textColor = textColor
  }

  public func resetColor() {
    setColor(state: .normal)
  }

  public func hide() {
    setColor(state: .normal)
    window?.orderOut(nil)
  }

  private func adjustSize() {
    let attrString = messageText.attributedStringValue
    var dimension = attrString.boundingDimension
    dimension.width *= 1.2
    if direction == .vertical {
      dimension.height *= 1.2
    }
    var rect = NSRect(origin: .zero, size: dimension)
    if direction == .vertical {
      rect = .init(x: rect.minX, y: rect.minY, width: rect.height, height: rect.width)
    }
    var bigRect = rect
    bigRect.size.width += NSFont.systemFontSize
    bigRect.size.height += NSFont.systemFontSize
    rect.origin.x += ceil(NSFont.systemFontSize / 2)
    rect.origin.y += ceil(NSFont.systemFontSize / 2)
    if direction == .vertical {
      messageText.boundsRotation = 90
    } else {
      messageText.boundsRotation = 0
    }
    messageText.frame = rect
    window?.setFrame(bigRect, display: true)
  }
}
