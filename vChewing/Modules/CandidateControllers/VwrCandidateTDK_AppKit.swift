// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

/// 田所選字窗的 AppKit 简单版本，繪製效率不受 SwiftUI 的限制。
/// 該版本可以使用更少的系統資源來繪製選字窗。

public class VwrCandidateTDKAppKit: NSView {
  public weak var controller: CtlCandidateTDK?
  public var thePool: CandidatePool
  private var dimension: NSSize = .zero
  var action: Selector?
  weak var target: AnyObject?
  var theMenu: NSMenu?
  var clickedCell: CandidateCellData = CandidatePool.shitCell

  // MARK: - Variables used for rendering the UI.

  var padding: CGFloat { thePool.padding }
  var originDelta: CGFloat { thePool.originDelta }
  var cellRadius: CGFloat { thePool.cellRadius }
  var windowRadius: CGFloat { thePool.windowRadius }
  var isMatrix: Bool { thePool.isMatrix }

  // MARK: - Constructors.

  public init(controller: CtlCandidateTDK? = nil, thePool pool: CandidatePool) {
    self.controller = controller
    thePool = pool
    thePool.updateMetrics()
    super.init(frame: .init(origin: .zero, size: .init(width: 114_514, height: 114_514)))
  }

  deinit {
    theMenu?.cancelTrackingWithoutAnimation()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Interface Renderer (with shared public variables).

public extension VwrCandidateTDKAppKit {
  override var isFlipped: Bool { true }

  override var fittingSize: NSSize { thePool.metrics.fittingSize }

  static var candidateListBackground: NSColor {
    let brightBackground = NSColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.00)
    let darkBackground = NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1.00)
    return NSApplication.isDarkMode ? darkBackground : brightBackground
  }

  override func draw(_: NSRect) {
    let sizesCalculated = thePool.metrics
    // 先塗底色
    let allRect = NSRect(origin: .zero, size: sizesCalculated.fittingSize)
    Self.candidateListBackground.setFill()
    NSBezierPath(roundedRect: allRect, xRadius: windowRadius, yRadius: windowRadius).fill()
    // 繪製高亮行背景與高亮候選字詞背景
    lineBackground(isCurrentLine: true, isMatrix: isMatrix).setFill()
    NSBezierPath(roundedRect: sizesCalculated.highlightedLine, xRadius: cellRadius, yRadius: cellRadius).fill()
    var cellHighlightedDrawn = false
    // 開始繪製候選字詞
    let allCells = thePool.candidateLines[thePool.lineRangeForCurrentPage].flatMap { $0 }
    allCells.forEach { currentCell in
      if currentCell.isHighlighted, !cellHighlightedDrawn {
        currentCell.themeColorCocoa.setFill()
        NSBezierPath(roundedRect: sizesCalculated.highlightedCandidate, xRadius: cellRadius, yRadius: cellRadius).fill()
        cellHighlightedDrawn = true
      }
      currentCell.attributedStringHeader.draw(at:
        .init(
          x: currentCell.visualOrigin.x + 2 * padding,
          y: currentCell.visualOrigin.y + ceil(currentCell.visualDimension.height * 0.2)
        )
      )
      currentCell.attributedStringPhrase(isMatrix: false).draw(
        at: .init(
          x: currentCell.visualOrigin.x + 2 * padding + ceil(currentCell.size * 0.6),
          y: currentCell.visualOrigin.y + padding
        )
      )
    }
    // 繪製附加內容
    let strPeripherals = thePool.attributedDescriptionBottomPanes
    strPeripherals.draw(at: sizesCalculated.peripherals.origin)
  }
}

// MARK: - Mouse Interaction Handlers.

public extension VwrCandidateTDKAppKit {
  private func findCell(from mouseEvent: NSEvent) -> Int? {
    var clickPoint = convert(mouseEvent.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y // 翻轉座標系
    guard bounds.contains(clickPoint) else { return nil }
    let flattenedCells = thePool.candidateLines[thePool.lineRangeForCurrentPage].flatMap { $0 }
    let x = flattenedCells.filter { theCell in
      NSPointInRect(clickPoint, .init(origin: theCell.visualOrigin, size: theCell.visualDimension))
    }.first
    guard let firstValidCell = x else { return nil }
    return firstValidCell.index
  }

  override func mouseDown(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    guard cellIndex != thePool.highlightedIndex else { return }
    thePool.highlight(at: cellIndex)
    thePool.updateMetrics()
    setNeedsDisplay(bounds)
  }

  override func mouseDragged(with event: NSEvent) {
    mouseDown(with: event)
  }

  override func mouseUp(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    didSelectCandidateAt(cellIndex)
  }

  override func rightMouseUp(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    clickedCell = thePool.candidateDataAll[cellIndex]
    let index = clickedCell.index
    let candidateText = clickedCell.displayedText
    let isEnabled: Bool = controller?.delegate?.isCandidateContextMenuEnabled ?? false
    guard isEnabled, !candidateText.isEmpty, index >= 0 else { return }
    prepareMenu()
    var clickPoint = convert(event.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y // 翻轉座標系
    theMenu?.popUp(positioning: nil, at: clickPoint, in: self)
  }
}

// MARK: - Context Menu.

private extension VwrCandidateTDKAppKit {
  private func prepareMenu() {
    let newMenu = NSMenu()
    let boostMenuItem = NSMenuItem(
      title: "↑ \(clickedCell.displayedText)",
      action: #selector(menuActionOfBoosting(_:)),
      keyEquivalent: ""
    )
    boostMenuItem.target = self
    newMenu.addItem(boostMenuItem)

    let nerfMenuItem = NSMenuItem(
      title: "↓ \(clickedCell.displayedText)",
      action: #selector(menuActionOfNerfing(_:)),
      keyEquivalent: ""
    )
    nerfMenuItem.target = self
    newMenu.addItem(nerfMenuItem)

    if thePool.isFilterable(target: clickedCell.index) {
      let filterMenuItem = NSMenuItem(
        title: "✖︎ \(clickedCell.displayedText)",
        action: #selector(menuActionOfFiltering(_:)),
        keyEquivalent: ""
      )
      filterMenuItem.target = self
      newMenu.addItem(filterMenuItem)
    }

    theMenu = newMenu
    CtlCandidateTDK.currentMenu = newMenu
  }

  @objc func menuActionOfBoosting(_: Any? = nil) {
    didRightClickCandidateAt(clickedCell.index, action: .toBoost)
  }

  @objc func menuActionOfNerfing(_: Any? = nil) {
    didRightClickCandidateAt(clickedCell.index, action: .toNerf)
  }

  @objc func menuActionOfFiltering(_: Any? = nil) {
    didRightClickCandidateAt(clickedCell.index, action: .toFilter)
  }
}

// MARK: - Delegate Methods

private extension VwrCandidateTDKAppKit {
  func didSelectCandidateAt(_ pos: Int) {
    controller?.delegate?.candidatePairSelectionConfirmed(at: pos)
  }

  func didRightClickCandidateAt(_ pos: Int, action: CandidateContextMenuAction) {
    controller?.delegate?.candidatePairRightClicked(at: pos, action: action)
  }
}

// MARK: - Extracted Internal Methods for UI Rendering.

private extension VwrCandidateTDKAppKit {
  private func lineBackground(isCurrentLine: Bool, isMatrix: Bool) -> NSColor {
    if !isCurrentLine { return .clear }
    let absBg: NSColor = NSApplication.isDarkMode ? .black : .white
    switch thePool.layout {
    case .horizontal where isMatrix:
      return NSApplication.isDarkMode ? .controlTextColor.withAlphaComponent(0.05) : .white
    case .vertical where isMatrix:
      return absBg.withAlphaComponent(0.9)
    default:
      return .clear
    }
  }

  private var finalContainerOrientation: NSUserInterfaceLayoutOrientation {
    if thePool.maxLinesPerPage == 1, thePool.layout == .horizontal { return .horizontal }
    return .vertical
  }
}
