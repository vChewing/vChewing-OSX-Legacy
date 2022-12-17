// (c) 2022 and onwards The vChewing Project for all modifications introduced to Voltaire MK3, plus the integration with the CandidatePool.
// (c) 2021 Zonble Yang for rewriting Voltaire MK2 in Swift.
// (c) 2012 Lukhnos Liu for Voltaire MK1 development in Objective-C.
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

// 將之前 Zonble 重寫的 Voltaire 選字窗隔的橫向版本與縱向版本合併到同一個型別實體內。
// 威注音輸入法原本有刪除該 Voltaire 選字窗、以 SwiftUI 田所選字窗取而代之（要求至少 macOS 10.15），
// 但後來發現 IMKCandidates 在 macOS 10.9-10.12 系統下根本不能用。
// 於是乎，對 macOS 10.9 只能繼續使用 Voltaire。讓使用者有選字窗可用，比起那些莫名其妙的潔癖而言，更重要。
// 註：Voltaire 的 MK3 版的誕生並非 OpenVanilla 與威注音專案的合作結果，其相對於小麥注音 2.x 用的 MK2 版而言的改動僅有威注音專案參與製作。

import Cocoa

/// Credit: Lukhnos Liu, Zonble Yang. UI Design Modified by Shiki Suen.
private class VwrCandidateUniversal: NSView {
  var highlightedInlineIndex: Int { delegate?.highlightedInlineIndex ?? 0 }

  var action: Selector?
  weak var target: AnyObject?
  weak var delegate: CtlCandidateUniversal?  // 糾偏用 /// Shiki Suen.
  var isVerticalLayout = false
  var fractionFontSize: CGFloat = 12.0

  private var keyLabels: [String] = []
  private var displayedCandidates: [String] = []
  private var dispCandidatesWithLabels: [String] = []
  private var keyLabelHeight: CGFloat = 0
  private var keyLabelWidth: CGFloat = 0
  private var candidateTextHeight: CGFloat = 0
  private var cellPadding: CGFloat = 0
  private var keyLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var candidateAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var candidateWithLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var windowWidth: CGFloat = 0  // 縱排專用
  private var elementWidths: [CGFloat] = []
  private var elementHeights: [CGFloat] = []  // 縱排專用
  private var trackingHighlightedIndex: Int = .max {
    didSet { trackingHighlightedIndex = max(trackingHighlightedIndex, 0) }
  }

  override var isFlipped: Bool {
    true
  }

  var sizeForView: NSSize {
    var result = NSSize.zero

    if !elementWidths.isEmpty {
      switch isVerticalLayout {
        case true:
          result.width = windowWidth
          result.height = elementHeights.reduce(0, +)
        case false:
          result.width = elementWidths.reduce(0, +) + CGFloat(elementWidths.count)
          result.height = candidateTextHeight + cellPadding
      }
    }
    return result
  }

  @objc(setKeyLabels:displayedCandidates:)
  func set(keyLabels labels: [String], displayedCandidates candidates: [String]) {
    let candidates = candidates.map { theCandidate -> String in
      let theConverted = ChineseConverter.kanjiConversionIfRequired(theCandidate)
      return (theCandidate == theConverted) ? theCandidate : "\(theConverted)(\(theCandidate))"
    }

    let count = min(labels.count, candidates.count)
    keyLabels = Array(labels[0..<count])
    displayedCandidates = Array(candidates[0..<count])
    dispCandidatesWithLabels = zip(keyLabels, displayedCandidates).map { $0 + $1 }

    var newWidths = [CGFloat]()
    var calculatedWindowWidth = CGFloat()
    var newHeights = [CGFloat]()
    let baseSize = NSSize(width: 10240.0, height: 10240.0)
    for index in 0..<count {
      let rctCandidate = (dispCandidatesWithLabels[index] as NSString).boundingRect(
        with: baseSize, options: .usesLineFragmentOrigin,
        attributes: candidateWithLabelAttrDict
      )
      var cellWidth = rctCandidate.size.width + cellPadding
      let cellHeight = rctCandidate.size.height + cellPadding
      switch isVerticalLayout {
        case true:
          if calculatedWindowWidth < rctCandidate.size.width {
            calculatedWindowWidth = rctCandidate.size.width + cellPadding * 2
          }
          calculatedWindowWidth = max(calculatedWindowWidth, 4 * rctCandidate.size.height)
        case false:
          if cellWidth < cellHeight * 1.4 {
            cellWidth = cellHeight * 1.4
          }
      }
      newWidths.append(round(cellWidth))
      newHeights.append(round(cellHeight))  // 縱排專用
    }
    elementWidths = newWidths
    elementHeights = newHeights
    // 縱排專用，防止窗體右側邊框粗細不一
    windowWidth = round(calculatedWindowWidth + cellPadding)
  }

  @objc(setKeyLabelFont:candidateFont:)
  func set(keyLabelFont labelFont: NSFont, candidateFont: NSFont) {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = isVerticalLayout ? .left : .center

    candidateWithLabelAttrDict = [
      .font: candidateFont,
      .paragraphStyle: paraStyle,
      .foregroundColor: NSColor.textColor,
    ]  // We still need this dummy section to make sure that…
    // …the space occupations of the candidates are correct.

    keyLabelAttrDict = [
      .font: labelFont,
      .paragraphStyle: paraStyle,
      .verticalGlyphForm: true as AnyObject,
      .foregroundColor: NSColor.textColor.withAlphaComponent(0.8),
    ]  // Candidate phrase text color
    candidateAttrDict = [
      .font: candidateFont,
      .paragraphStyle: paraStyle,
      .foregroundColor: NSColor.textColor,
    ]  // Candidate index text color
    let labelFontSize = labelFont.pointSize
    let candidateFontSize = candidateFont.pointSize
    let biggestSize = max(labelFontSize, candidateFontSize)
    fractionFontSize = round(biggestSize * 0.75)
    keyLabelWidth = ceil(labelFontSize)
    keyLabelHeight = ceil(labelFontSize * 2)
    candidateTextHeight = ceil(candidateFontSize * 1.20)
    cellPadding = ceil(biggestSize / 4.0) * 2
  }

  func ensureLangIdentifier(for attr: inout [NSAttributedString.Key: AnyObject]) {
    if PrefMgr.shared.handleDefaultCandidateFontsByLangIdentifier {
      switch IMEApp.currentInputMode {
        case .imeModeCHS:
          if #available(macOS 12.0, *) {
            attr[.languageIdentifier] = "zh-Hans" as AnyObject
          }
        case .imeModeCHT:
          if #available(macOS 12.0, *) {
            attr[.languageIdentifier] =
              (PrefMgr.shared.shiftJISShinjitaiOutputEnabled || PrefMgr.shared.chineseConversionEnabled)
              ? "ja" as AnyObject : "zh-Hant" as AnyObject
          }
        default:
          break
      }
    }
  }

  var highlightedColor: NSColor { IMEApp.currentInputMode == .imeModeCHS ? .red : .alternateSelectedControlColor }

  override func draw(_: NSRect) {
    NSColor.controlBackgroundColor.setFill()  // Candidate list panel base background
    NSBezierPath.fill(bounds)

    switch isVerticalLayout {
      case true:
        var accuHeight: CGFloat = 0
        for (index, elementHeight) in elementHeights.enumerated() {
          let currentHeight = elementHeight
          let rctCandidateArea = NSRect(
            x: 0, y: accuHeight, width: windowWidth,
            height: candidateTextHeight + cellPadding
          )
          let rctLabel = NSRect(
            x: cellPadding / 2 + 2, y: accuHeight + cellPadding / 2, width: keyLabelWidth,
            height: keyLabelHeight * 2.0
          )
          let rctCandidatePhrase = NSRect(
            x: cellPadding / 2 + 2 + keyLabelWidth, y: accuHeight + cellPadding / 2 - 1,
            width: windowWidth - keyLabelWidth, height: candidateTextHeight
          )

          var activeCandidateIndexAttr = keyLabelAttrDict
          var activeCandidateAttr = candidateAttrDict
          if index == highlightedInlineIndex {
            highlightedColor.setFill()
            // Highlightened index text color
            activeCandidateIndexAttr[.foregroundColor] = NSColor.alternateSelectedControlTextColor.withAlphaComponent(
              0.8
            )
            .withAlphaComponent(0.84)
            // Highlightened phrase text color
            activeCandidateAttr[.foregroundColor] = NSColor.alternateSelectedControlTextColor
            rctCandidateArea.fill()
          }
          ensureLangIdentifier(for: &activeCandidateAttr)
          (keyLabels[index] as NSString).draw(
            in: rctLabel, withAttributes: activeCandidateIndexAttr
          )
          (displayedCandidates[index] as NSString).draw(
            in: rctCandidatePhrase, withAttributes: activeCandidateAttr
          )
          accuHeight += currentHeight
        }
      case false:
        var accuWidth: CGFloat = 0
        for (index, elementWidth) in elementWidths.enumerated() {
          let currentWidth = elementWidth
          let rctCandidateArea = NSRect(
            x: accuWidth, y: 0, width: currentWidth + 1.0,
            height: candidateTextHeight + cellPadding
          )
          let rctLabel = NSRect(
            x: accuWidth + cellPadding / 2 - 1, y: cellPadding / 2, width: keyLabelWidth,
            height: keyLabelHeight * 2.0
          )
          let rctCandidatePhrase = NSRect(
            x: accuWidth + keyLabelWidth - 1, y: cellPadding / 2 - 1,
            width: currentWidth - keyLabelWidth,
            height: candidateTextHeight
          )

          var activeCandidateIndexAttr = keyLabelAttrDict
          var activeCandidateAttr = candidateAttrDict
          if index == highlightedInlineIndex {
            highlightedColor.setFill()
            // Highlightened index text color
            activeCandidateIndexAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
              .withAlphaComponent(0.84)
            // Highlightened phrase text color
            activeCandidateAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
            rctCandidateArea.fill()
          }
          ensureLangIdentifier(for: &activeCandidateAttr)
          (keyLabels[index] as NSString).draw(
            in: rctLabel, withAttributes: activeCandidateIndexAttr
          )
          (displayedCandidates[index] as NSString).draw(
            in: rctCandidatePhrase, withAttributes: activeCandidateAttr
          )
          accuWidth += currentWidth + 1.0
        }
    }
  }

  private func findHitIndex(event: NSEvent) -> Int {
    let location = convert(event.locationInWindow, to: nil)
    if !bounds.contains(location) {
      return NSNotFound
    }
    switch isVerticalLayout {
      case true:
        var accuHeight: CGFloat = 0.0
        for (index, elementHeight) in elementHeights.enumerated() {
          let currentHeight = elementHeight

          if location.y >= accuHeight, location.y <= accuHeight + currentHeight {
            return index
          }
          accuHeight += currentHeight
        }
      case false:
        var accuWidth: CGFloat = 0.0
        for (index, elementWidth) in elementWidths.enumerated() {
          let currentWidth = elementWidth

          if location.x >= accuWidth, location.x <= accuWidth + currentWidth {
            return index
          }
          accuWidth += currentWidth + 1.0
        }
    }
    return NSNotFound
  }

  override func mouseUp(with event: NSEvent) {
    guard let delegate = delegate else { return }
    trackingHighlightedIndex = highlightedInlineIndex
    let newIndex = findHitIndex(event: event)
    guard newIndex != NSNotFound else {
      return
    }

    // 糾偏 /// Added by Shiki Suen.
    delegate.highlightedIndex = delegate.candidateAmountBeforeCurrentPage + newIndex
    setNeedsDisplay(bounds)
  }

  override func mouseDown(with event: NSEvent) {
    guard let delegate = delegate else { return }
    let newIndex = findHitIndex(event: event)
    guard newIndex != NSNotFound else {
      return
    }
    var triggerAction = false
    if newIndex == highlightedInlineIndex {
      triggerAction = true
    } else {
      // 糾偏 /// Added by Shiki Suen.
      delegate.highlightedIndex = delegate.candidateAmountBeforeCurrentPage + newIndex
    }

    trackingHighlightedIndex = 0
    setNeedsDisplay(bounds)
    if triggerAction {
      if let target = target as? NSObject, let action = action {
        target.perform(action, with: self)
      }
    }
  }
}

public class CtlCandidateUniversal: CtlCandidate {
  public var keyLabels: [String] = []

  /// Added by Shiki Suen.
  private static var thePoolHorizontal: CandidatePool = .init(candidates: [], rowCapacity: 9)
  /// Added by Shiki Suen.
  private static var thePoolVertical: CandidatePool = .init(candidates: [], columnCapacity: 9)
  /// Added by Shiki Suen.

  /// Credit: Shiki Suen.
  internal var thePool: CandidatePool {
    get {
      switch currentLayout {
        case .horizontal: return Self.thePoolHorizontal
        case .vertical: return Self.thePoolVertical
        @unknown default: return .init(candidates: [], rowCapacity: 0)
      }
    }
    set {
      switch currentLayout {
        case .horizontal: Self.thePoolHorizontal = newValue
        case .vertical: Self.thePoolVertical = newValue
        @unknown default: break
      }
    }
  }

  private var candidateView: VwrCandidateUniversal
  private var prevPageButton: NSButton
  private var nextPageButton: NSButton
  private var pageCounterLabel: NSTextField
  override public var currentLayout: NSUserInterfaceLayoutOrientation {
    get { candidateView.isVerticalLayout ? .vertical : .horizontal }
    set {
      switch newValue {
        case .vertical: candidateView.isVerticalLayout = true
        case .horizontal: candidateView.isVerticalLayout = false
        @unknown default: break
      }
    }
  }

  public required init(_ layout: NSUserInterfaceLayoutOrientation = .horizontal) {
    var contentRect = NSRect(x: 128.0, y: 128.0, width: 0.0, height: 0.0)
    let styleMask: NSWindow.StyleMask = [.nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 2)
    panel.hasShadow = true
    panel.isOpaque = false
    panel.backgroundColor = NSColor.clear

    contentRect.origin = NSPoint.zero
    candidateView = VwrCandidateUniversal(frame: contentRect)

    panel.contentView?.addSubview(candidateView)

    // MARK: Add Buttons

    contentRect.size = NSSize(width: 20.0, height: 10.0)  // Reduce the button width
    let buttonAttribute: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9.0)]

    nextPageButton = .init(frame: contentRect)
    nextPageButton.wantsLayer = true
    nextPageButton.layer?.masksToBounds = true
    nextPageButton.layer?.borderColor = NSColor.clear.cgColor
    nextPageButton.layer?.borderWidth = 0.0
    nextPageButton.setButtonType(.momentaryLight)
    nextPageButton.bezelStyle = .disclosure
    nextPageButton.userInterfaceLayoutDirection = .leftToRight
    nextPageButton.attributedTitle = NSMutableAttributedString(
      string: " ", attributes: buttonAttribute
    )  // Next Page Arrow
    prevPageButton = .init(frame: contentRect)
    prevPageButton.wantsLayer = true
    prevPageButton.layer?.masksToBounds = true
    prevPageButton.layer?.borderColor = NSColor.clear.cgColor
    prevPageButton.layer?.borderWidth = 0.0
    prevPageButton.setButtonType(.momentaryLight)
    prevPageButton.bezelStyle = .disclosure
    prevPageButton.userInterfaceLayoutDirection = .rightToLeft
    prevPageButton.attributedTitle = NSMutableAttributedString(
      string: " ", attributes: buttonAttribute
    )  // Previous Page Arrow
    panel.contentView?.addSubview(nextPageButton)
    panel.contentView?.addSubview(prevPageButton)

    // MARK: Add Page Counter (by Shiki Suen)

    /// Credit: Shiki Suen.
    contentRect = NSRect(x: 128.0, y: 128.0, width: 48.0, height: 20.0)
    pageCounterLabel = .init(frame: contentRect)
    pageCounterLabel.isEditable = false
    pageCounterLabel.isSelectable = false
    pageCounterLabel.isBezeled = false
    pageCounterLabel.attributedStringValue = NSMutableAttributedString(
      string: " ", attributes: buttonAttribute
    )
    panel.contentView?.addSubview(pageCounterLabel)

    // MARK: Post-Init()

    super.init(layout)
    window = panel
    currentLayout = layout

    candidateView.target = self
    candidateView.action = #selector(candidateViewMouseDidClick(_:))

    nextPageButton.target = self
    nextPageButton.action = #selector(pageButtonAction(_:))

    prevPageButton.target = self
    prevPageButton.action = #selector(pageButtonAction(_:))

    /// Credit: Shiki Suen.
    candidateView.delegate = self
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Credit: Shiki Suen.
  override public func reloadData() {
    CandidateCellData.highlightBackground = highlightedColor()
    CandidateCellData.unifiedSize = candidateFont.pointSize
    guard let delegate = delegate else { return }

    switch currentLayout {
      case .horizontal:
        Self.thePoolHorizontal = .init(
          candidates: delegate.candidatePairs(conv: true).map(\.1), rowCapacity: 9,
          rows: 1, selectionKeys: delegate.selectionKeys, locale: locale
        )
        Self.thePoolHorizontal.highlight(at: 0)
      case .vertical:
        Self.thePoolVertical = .init(
          candidates: delegate.candidatePairs(conv: true).map(\.1), columnCapacity: 9,
          columns: 1, selectionKeys: delegate.selectionKeys, locale: locale
        )
        Self.thePoolVertical.highlight(at: 0)
      @unknown default:
        return
    }
    thePool.maxLinesPerPage = 1
    keyLabels = thePool.selectionKeys.map(\.description)
    layoutCandidateView()
  }

  /// Credit: Shiki Suen.
  @discardableResult override public func showNextPage() -> Bool {
    showNextLine(count: thePool.maxLinesPerPage)
  }

  /// Credit: Shiki Suen.
  @discardableResult override public func showNextLine() -> Bool {
    showNextLine(count: 1)
  }

  /// Credit: Shiki Suen.
  public func showNextLine(count: Int) -> Bool {
    if thePool.currentLineNumber == thePool.candidateLines.count - 1 {
      return highlightNextCandidate()
    }
    if count <= 0 { return false }
    for _ in 0..<min(thePool.maxLinesPerPage, count) {
      thePool.selectNewNeighborLine(isForward: true)
    }
    thePool.highlight(at: candidateAmountBeforeCurrentPage)
    layoutCandidateView()
    return true
  }

  /// Credit: Shiki Suen.
  @discardableResult override public func showPreviousPage() -> Bool {
    showPreviousLine(count: thePool.maxLinesPerPage)
  }

  /// Credit: Shiki Suen.
  @discardableResult override public func showPreviousLine() -> Bool {
    showPreviousLine(count: 1)
  }

  /// Credit: Shiki Suen.
  public func showPreviousLine(count: Int) -> Bool {
    if thePool.currentLineNumber == 0 {
      return highlightPreviousCandidate()
    }
    if count <= 0 { return false }
    for _ in 0..<min(thePool.maxLinesPerPage, count) {
      thePool.selectNewNeighborLine(isForward: false)
    }
    thePool.highlight(at: candidateAmountBeforeCurrentPage)
    layoutCandidateView()
    return true
  }

  /// Credit: Shiki Suen.
  @discardableResult override public func highlightNextCandidate() -> Bool {
    if thePool.highlightedIndex == thePool.candidateDataAll.count - 1 {
      thePool.highlight(at: 0)
      layoutCandidateView()
      return false
    }
    thePool.highlight(at: thePool.highlightedIndex + 1)
    layoutCandidateView()
    return true
  }

  /// Credit: Shiki Suen.
  @discardableResult override public func highlightPreviousCandidate() -> Bool {
    if thePool.highlightedIndex == 0 {
      thePool.highlight(at: thePool.candidateDataAll.count - 1)
      layoutCandidateView()
      return false
    }
    thePool.highlight(at: thePool.highlightedIndex - 1)
    layoutCandidateView()
    return true
  }

  /// Credit: Shiki Suen.
  override public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int {
    let arrCurrentLine = thePool.candidateLines[thePool.currentLineNumber]
    if !(0..<arrCurrentLine.count).contains(id) { return -114_514 }
    let actualID = max(0, min(id, arrCurrentLine.count - 1))
    return arrCurrentLine[actualID].index
  }

  /// Credit: Shiki Suen.
  override public var highlightedIndex: Int {
    get { thePool.highlightedIndex }
    set {
      thePool.highlight(at: newValue)
      layoutCandidateView()
    }
  }
}

extension CtlCandidateUniversal {
  /// Credit: Shiki Suen.
  internal var candidateAmountBeforeCurrentPage: Int {
    var delta = 0
    for i in 0..<thePool.currentLineNumber {
      delta += thePool.candidateLines[i].count
    }
    return delta
  }

  /// Credit: Shiki Suen.
  internal var highlightedInlineIndex: Int {
    let currentLine = thePool.candidateLines[thePool.currentLineNumber]
    var result = 0
    theCheck: for (i, neta) in currentLine.enumerated() {
      if neta.isSelected {
        result = i
        break theCheck
      }
    }
    return result
  }

  private var keyLabelFont: NSFont { NSFont.systemFont(ofSize: max(11, round(candidateFont.pointSize * 0.7))) }

  private func layoutCandidateView() {
    guard delegate != nil else { return }

    candidateView.set(keyLabelFont: keyLabelFont, candidateFont: candidateFont)
    var candidates = [(String, String)]()

    /// Credit: Shiki Suen.
    let currentLine = thePool.candidateLines[thePool.currentLineNumber]
    var effectiveKeyLabels = [String]()
    currentLine.enumerated().forEach { i, x in
      candidates.append((x.key, x.displayedText))
      effectiveKeyLabels.append(keyLabels[i])
    }
    candidateView.set(
      keyLabels: effectiveKeyLabels, displayedCandidates: candidates.map(\.1)
    )

    var newSize = candidateView.sizeForView
    var frameRect = candidateView.frame
    frameRect.size = newSize
    candidateView.frame = frameRect
    let counterHeight: CGFloat = newSize.height - 24

    if thePool.candidateLines.count > 1 {
      var buttonRect = nextPageButton.frame
      let spacing: CGFloat = 0.0

      if currentLayout == .horizontal { buttonRect.size.height = floor(newSize.height / 2) }
      let buttonOriginY: CGFloat = {
        if currentLayout == .vertical {
          return counterHeight
        }
        return (newSize.height - (buttonRect.size.height * 2.0 + spacing)) / 2.0
      }()
      buttonRect.origin = NSPoint(x: newSize.width, y: buttonOriginY)
      nextPageButton.frame = buttonRect
      buttonRect.origin = NSPoint(
        x: newSize.width, y: buttonOriginY + buttonRect.size.height + spacing
      )
      prevPageButton.frame = buttonRect
      newSize.width += 20
      nextPageButton.isHidden = false
      prevPageButton.isHidden = false
    } else {
      nextPageButton.isHidden = true
      prevPageButton.isHidden = true
    }

    /// Credit: Shiki Suen.
    if thePool.candidateLines.count >= 2 {
      let attrString = NSMutableAttributedString(
        string: "\(thePool.currentLineNumber + 1)/\(thePool.candidateLines.count)",
        attributes: [
          .font: NSFont.systemFont(ofSize: candidateView.fractionFontSize)
        ]
      )
      pageCounterLabel.attributedStringValue = attrString
      var rect = attrString.boundingRect(
        with: NSSize(width: 1600.0, height: 1600.0),
        options: .usesLineFragmentOrigin
      )

      rect.size.height += 3
      rect.size.width += 8
      let rectOriginY: CGFloat =
        (currentLayout == .horizontal)
        ? (newSize.height - rect.height) / 2
        : counterHeight
      let rectOriginX: CGFloat = newSize.width
      // PrefMgr.shared.showPageButtonsInCandidateWindow ? newSize.width : newSize.width + 4
      rect.origin = NSPoint(x: rectOriginX, y: rectOriginY)
      pageCounterLabel.frame = rect
      newSize.width += rect.width + 4
      pageCounterLabel.isHidden = false
    } else {
      pageCounterLabel.isHidden = true
    }

    frameRect = window?.frame ?? NSRect.seniorTheBeast

    let topLeftPoint = NSPoint(x: frameRect.origin.x, y: frameRect.origin.y + frameRect.size.height)
    frameRect.size = newSize
    frameRect.origin = NSPoint(x: topLeftPoint.x, y: topLeftPoint.y - frameRect.size.height)
    window?.setFrame(frameRect, display: false)
    candidateView.setNeedsDisplay(candidateView.bounds)
  }

  @objc private func pageButtonAction(_ sender: Any) {
    guard let sender = sender as? NSButton else {
      return
    }
    if sender == nextPageButton {
      _ = showNextPage()
    } else if sender == prevPageButton {
      _ = showPreviousPage()
    }
  }

  /// Credit: Shiki Suen.
  @objc private func candidateViewMouseDidClick(_: Any) {
    delegate?.candidatePairSelected(
      at: candidateView.highlightedInlineIndex + candidateAmountBeforeCurrentPage
    )
  }
}
