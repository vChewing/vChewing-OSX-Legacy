// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation

public extension SettingsPanesCocoa {
  class Keyboard: NSViewController {
    let windowWidth: CGFloat = 577
    let contentWidth: CGFloat = 512
    var contentHalfWidth: CGFloat { contentWidth / 2 - 4 }

    override public func loadView() {
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.horizontal) {
            "Quick Setup:".makeNSLabel(fixWidth: contentWidth)
            NSView()
            NSButton(
              verbatim: "↻ㄅ" + " " + "Dachen Trad.".localized,
              target: self,
              action: #selector(quickSetupButtonDachen(_:))
            )
            NSButton(
              verbatim: "↻ㄅ" + " " + "Eten Trad.".localized,
              target: self,
              action: #selector(quickSetupButtonEtenTraditional(_:))
            )
            NSButton(
              verbatim: "↻Ａ", target: self,
              action: #selector(quickSetupButtonHanyuPinyin(_:))
            )
          }
          UserDef.kKeyboardParser.render(fixWidth: contentWidth)
          UserDef.kBasicKeyboardLayout.render(fixWidth: contentWidth)
          UserDef.kAlphanumericalKeyboardLayout.render(fixWidth: contentWidth)
        }?.boxed()
        NSStackView.build(.horizontal, insets: .new(all: 4, left: 16, right: 16)) {
          "Keyboard Shortcuts:".makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(.horizontal, width: contentWidth) {
          NSStackView.build(.vertical) {
            UserDef.kUsingHotKeySCPC.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyAssociates.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyCNS.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyKangXi.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyRevLookup.render(fixWidth: contentHalfWidth)
          }
          NSStackView.build(.vertical) {
            UserDef.kUsingHotKeyJIS.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyHalfWidthASCII.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyCurrencyNumerals.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyCassette.render(fixWidth: contentHalfWidth)
            UserDef.kUsingHotKeyInputMode.render(fixWidth: contentHalfWidth)
          }
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction func quickSetupButtonDachen(_: NSControl) {
      PrefMgr.shared.keyboardParser = 0
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
    }

    @IBAction func quickSetupButtonEtenTraditional(_: NSControl) {
      PrefMgr.shared.keyboardParser = 1
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
    }

    @IBAction func quickSetupButtonHanyuPinyin(_: NSControl) {
      PrefMgr.shared.keyboardParser = 100
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ABC"
    }
  }
}
