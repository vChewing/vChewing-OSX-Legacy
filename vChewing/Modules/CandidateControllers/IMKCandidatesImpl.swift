// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

/// 威注音自用的 IMKCandidates 型別。因為有用到 bridging header，所以無法弄成 Swift Package。
public class CtlCandidateIMK: CtlCandidateProtocol {
  // Do not implement.
  public func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: Double, useGCD _: Bool) {
    Self.shared.set(windowTopLeftPoint: windowTopLeftPoint, bottomOutOfScreenAdjustmentHeight: height, useGCD: false)
  }

  public static var shared: IMKCandidates = .init(server: theServer, panelType: kIMKSingleRowSteppingCandidatePanel)

  public var imk: IMKCandidates { Self.shared }

  public var tooltip: String = ""
  public var reverseLookupResult: [String] = []
  public var locale: String = ""
  public var useLangIdentifier: Bool = false
  public var currentLayout: NSUserInterfaceLayoutOrientation = .horizontal
  public static let defaultIMKSelectionKey: [UInt16: String] = [
    18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
  ]
  public var delegate: CtlCandidateDelegate? {
    didSet {
      reloadData()
    }
  }

  public var visible: Bool {
    get { Self.shared.isVisible() }
    set { newValue ? Self.shared.show() : Self.shared.hide() }
  }

  public var windowTopLeftPoint: NSPoint {
    get {
      let frameRect = Self.shared.candidateFrame()
      return NSPoint(x: frameRect.minX, y: frameRect.maxY)
    }
    set {
      DispatchQueue.main.async {
        self.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0, useGCD: true)
      }
    }
  }

  public var candidateFont = NSFont.systemFont(ofSize: 16) {
    didSet {
      var attributes = Self.shared.attributes()
      // FB11300759: Set "NSAttributedString.Key.font" doesn't work.
      attributes?[NSAttributedString.Key.font] = candidateFont
      if #available(macOS 12.0, *) {
        if useLangIdentifier {
          attributes?[NSAttributedString.Key.languageIdentifier] = locale as AnyObject
        }
      }
      Self.shared.setAttributes(attributes)
      Self.shared.update()
    }
  }

  public func specifyLayout(_ layout: NSUserInterfaceLayoutOrientation = .horizontal) {
    currentLayout = layout
    switch currentLayout {
    case .horizontal:
      // macOS 10.13 High Sierra 的矩陣選字窗不支援選字鍵，所以只能弄成橫版單行。
      Self.shared.setPanelType(kIMKSingleRowSteppingCandidatePanel)
    case .vertical:
      Self.shared.setPanelType(kIMKSingleColumnScrollingCandidatePanel)
    @unknown default:
      Self.shared.setPanelType(kIMKSingleRowSteppingCandidatePanel)
    }
  }

  public func updateDisplay() {}

  public required init(_ layout: NSUserInterfaceLayoutOrientation = .horizontal) {
    specifyLayout(layout)
    // 設為 true 表示先交給 SessionCtl 處理
    Self.shared.setAttributes([IMKCandidatesSendServerKeyEventFirst: true])
    visible = false
    // guard let currentTISInputSource = currentTISInputSource else { return }  // 下面兩句都沒用，所以註釋掉。
    // setSelectionKeys([18, 19, 20, 21, 23, 22, 26, 28, 25])  // 這句是壞的，用了反而沒有選字鍵。
    // setSelectionKeysKeylayout(currentTISInputSource)  // 這句也是壞的，沒有卵用。
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func reloadData() {
    // guard let delegate = delegate else { return }  // 下文無效，所以這句沒用。
    // 既然下述函式無效，那中間這段沒用的也都砍了。
    // setCandidateData(candidates)  // 該函式無效。
    highlightedIndex = 0
    Self.shared.update()
  }

  /// 幹話：這裡很多函式內容亂寫也都無所謂了，因為都被 IMKCandidates 代管執行。
  /// 對於所有 IMK 選字窗的選字判斷動作，不是在 inputHandler 中，而是在 `SessionCtl_HandleEvent` 中。

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func showNextPage() -> Bool {
    do { currentLayout == .vertical ? Self.shared.moveRight(self) : Self.shared.moveDown(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func showPreviousPage() -> Bool {
    do { currentLayout == .vertical ? Self.shared.moveLeft(self) : Self.shared.moveUp(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func highlightNextCandidate() -> Bool {
    do { currentLayout == .vertical ? Self.shared.moveDown(self) : Self.shared.moveRight(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func highlightPreviousCandidate() -> Bool {
    do { currentLayout == .vertical ? Self.shared.moveUp(self) : Self.shared.moveLeft(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  public func showNextLine() -> Bool {
    do { currentLayout == .vertical ? Self.shared.moveRight(self) : Self.shared.moveDown(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  public func showPreviousLine() -> Bool {
    do { currentLayout == .vertical ? Self.shared.moveLeft(self) : Self.shared.moveUp(self) }
    return true
  }

  // IMK 選字窗目前無法實作該函式。威注音 IMK 選字窗目前也不需要使用該函式。
  public func candidateIndexAtKeyLabelIndex(_: Int) -> Int { 0 }

  public var highlightedIndex: Int {
    get { Self.shared.selectedCandidate() }
    set { Self.shared.selectCandidate(withIdentifier: newValue) }
  }
}

// MARK: - Generate TISInputSource Object

/// 該參數只用來獲取 "com.apple.keylayout.ABC" 對應的 TISInputSource，
/// 所以少寫了很多在這裡用不到的東西。
/// 想參考完整版的話，請洽該專案內的 IME.swift。
var currentTISInputSource: TISInputSource? {
  var result: TISInputSource?
  let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
  let matchedTISString = "com.apple.keylayout.ABC"
  for source in list {
    guard let ptrCat = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) else { continue }
    let category = Unmanaged<CFString>.fromOpaque(ptrCat).takeUnretainedValue()
    guard category == kTISCategoryKeyboardInputSource else { continue }
    guard let ptrSourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
    let sourceID = String(Unmanaged<CFString>.fromOpaque(ptrSourceID).takeUnretainedValue())
    if sourceID == matchedTISString { result = source }
  }
  return result
}

// MARK: - Translating NumPad KeyCodes to Default IMK Candidate Selection KeyCodes.

public extension CtlCandidateIMK {
  static func replaceNumPadKeyCodes(target event: NSEvent) -> NSEvent? {
    let mapNumPadKeyCodeTranslation: [UInt16: UInt16] = [
      83: 18, 84: 19, 85: 20, 86: 21, 87: 23, 88: 22, 89: 26, 91: 28, 92: 25,
    ]
    return event.reinitiate(keyCode: mapNumPadKeyCodeTranslation[event.keyCode] ?? event.keyCode)
  }
}
