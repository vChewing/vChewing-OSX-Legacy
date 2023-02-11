// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

/// 用以呈現輸入法控制器（SessionCtl）的各種狀態。
///
/// 從實際角度來看，輸入法屬於有限態械（Finite State Machine）。其藉由滑鼠/鍵盤
/// 等輸入裝置接收輸入訊號，據此切換至對應的狀態，再根據狀態更新使用者介面內容，
/// 最終生成文字輸出、遞交給接收文字輸入行為的客體應用。此乃單向資訊流序，且使用
/// 者介面內容與文字輸出均無條件地遵循某一個指定的資料來源。
///
/// IMEState 型別用以呈現輸入法控制器正在做的事情，且分狀態儲存各種狀態限定的
/// 常數與變數。
///
/// 對 IMEState 型別下的諸多狀態的切換，應以生成新副本來取代舊有副本的形式來完
/// 成。唯一例外是 IMEState.ofMarking、擁有可以將自身轉變為 IMEState.ofInputting
/// 的成員函式，但也只是生成副本、來交給輸入法控制器來處理而已。每個狀態都有
/// 各自的構造器 (Constructor)。
///
/// 輸入法控制器持下述狀態：
///
/// - **失活狀態 .ofDeactivated**: 使用者沒在使用輸入法、或者使用者已經切換到另一個客體應用來敲字。
/// - **空狀態 .ofEmpty**: 使用者剛剛切換至該輸入法、卻還沒有任何輸入行為。
/// 抑或是剛剛敲字遞交給客體應用、準備新的輸入行為。
/// 威注音輸入法在「組字區與組音區/組筆區同時為空」、
/// 且客體軟體正在準備接收使用者文字輸入行為的時候，會處於空狀態。
/// 有時，威注音會利用呼叫空狀態的方式，讓組字區內已經顯示出來的內容遞交出去。
/// - **聯想詞狀態 .ofAssociates**: 逐字選字模式內的聯想詞輸入狀態。
/// - **中絕狀態 .ofAbortion**: 與 .ofEmpty() 類似，但會扔掉上一個狀態的內容、
/// 不將這些內容遞交給客體應用。該狀態在處理完畢之後會被立刻切換至 .ofEmpty()。
/// - **遞交狀態 .ofCommitting**: 該狀態會承載要遞交出去的內容，讓輸入法控制器處理時代為遞交。
/// 該狀態在處理完畢之後會被立刻切換至 .ofEmpty()。如果直接呼叫處理該狀態的話，
/// 在呼叫處理之前的組字區的內容會消失，除非你事先呼叫處理過 .ofEmpty()。
/// - **輸入狀態 .ofInputting**: 使用者輸入了內容。此時會出現組字區（Compositor）。
/// - **標記狀態 .ofMarking**: 使用者在組字區內標記某段範圍，
/// 可以決定是添入新詞、還是將這個範圍的詞音組合放入語彙濾除清單。
/// - **選字狀態 .ofCandidates**: 叫出選字窗、允許使用者選字。
/// - **分類分層符號表狀態 .ofSymbolTable**: 分類分層符號表選單專用的狀態，有自身的特殊處理。
public struct IMEState: IMEStateProtocol {
  public var type: StateType = .ofEmpty
  public var data: IMEStateDataProtocol = IMEStateData() as IMEStateDataProtocol
  public var node: CandidateNode = .init(name: "")
  init(_ data: IMEStateDataProtocol = IMEStateData() as IMEStateDataProtocol, type: StateType = .ofEmpty) {
    self.data = data
    self.type = type
  }

  /// 內部專用初期化函式，僅用於生成「有輸入內容」的狀態。
  /// - Parameters:
  ///   - displayTextSegments: 用以顯示的文本的字詞字串陣列，其中包含正在輸入的讀音或字根。
  ///   - cursor: 要顯示的游標（UTF8）。
  fileprivate init(displayTextSegments: [String], cursor: Int) {
    // 注意資料的設定順序，一定得先設定 displayTextSegments。
    data.displayTextSegments = displayTextSegments.map {
      if !SessionCtl.isVerticalTyping { return $0 }
      guard PrefMgr.shared.hardenVerticalPunctuations else { return $0 }
      var neta = $0
      ChineseConverter.hardenVerticalPunctuations(target: &neta, convert: SessionCtl.isVerticalTyping)
      return neta
    }
    data.cursor = cursor
    data.marker = cursor
  }

  /// 泛用初期化函式。
  /// - Parameters:
  ///   - data: 資料載體。
  ///   - type: 狀態類型。
  ///   - node: 節點。
  init(
    _ data: IMEStateDataProtocol = IMEStateData() as IMEStateDataProtocol, type: StateType = .ofEmpty,
    node: CandidateNode
  ) {
    self.data = data
    self.type = type
    self.node = node
    self.data.candidates = node.members.map { ([""], $0.name) }
  }
}

// MARK: - 針對不同的狀態，規定不同的構造器

public extension IMEState {
  static func ofDeactivated() -> IMEState { .init(type: .ofDeactivated) }
  static func ofEmpty() -> IMEState { .init(type: .ofEmpty) }
  static func ofAbortion() -> IMEState { .init(type: .ofAbortion) }

  /// 用以手動遞交指定內容的狀態。
  /// - Remark: 直接切換至該狀態的話，會丟失上一個狀態的內容。
  /// 如不想丟失的話，請先切換至 `.ofEmpty()` 再切換至 `.ofCommitting()`。
  /// - Parameter textToCommit: 要遞交的文本。
  /// - Returns: 要切換到的狀態。
  static func ofCommitting(textToCommit: String) -> IMEState {
    var result = IMEState(type: .ofCommitting)
    result.textToCommit = textToCommit
    ChineseConverter.ensureCurrencyNumerals(target: &result.data.textToCommit)
    return result
  }

  static func ofAssociates(candidates: [([String], String)]) -> IMEState {
    var result = IMEState(type: .ofAssociates)
    result.candidates = candidates
    return result
  }

  static func ofInputting(displayTextSegments: [String], cursor: Int) -> IMEState {
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofInputting
    return result
  }

  static func ofMarking(
    displayTextSegments: [String], markedReadings: [String], cursor: Int, marker: Int
  )
    -> IMEState
  {
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofMarking
    result.data.marker = marker
    result.data.markedReadings = markedReadings
    result.data.updateTooltipForMarking()
    return result
  }

  static func ofCandidates(candidates: [([String], String)], displayTextSegments: [String], cursor: Int)
    -> IMEState
  {
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofCandidates
    result.data.candidates = candidates
    return result
  }

  static func ofSymbolTable(node: CandidateNode) -> IMEState {
    var result = IMEState(node: node)
    result.type = .ofSymbolTable
    return result
  }
}

// MARK: - 規定一個狀態該怎樣返回自己的資料值

public extension IMEState {
  var isFilterable: Bool { data.isFilterable }
  var isMarkedLengthValid: Bool { data.isMarkedLengthValid }
  var displayedText: String { data.displayedText }
  var displayedTextConverted: String { data.displayedTextConverted }
  var displayTextSegments: [String] { data.displayTextSegments }
  var markedRange: Range<Int> { data.markedRange }
  var u16MarkedRange: Range<Int> { data.u16MarkedRange }
  var u16Cursor: Int { data.u16Cursor }

  var cursor: Int {
    get { data.cursor }
    set { data.cursor = newValue }
  }

  var marker: Int {
    get { data.marker }
    set { data.marker = newValue }
  }

  var convertedToInputting: IMEStateProtocol {
    if type == .ofInputting { return self }
    var result = Self.ofInputting(displayTextSegments: data.displayTextSegments, cursor: data.cursor)
    result.tooltip = data.tooltipBackupForInputting
    return result
  }

  var candidates: [([String], String)] {
    get { data.candidates }
    set { data.candidates = newValue }
  }

  var textToCommit: String {
    get { data.textToCommit }
    set { data.textToCommit = newValue }
  }

  var tooltip: String {
    get { data.tooltip }
    set { data.tooltip = newValue }
  }

  var attributedString: NSAttributedString {
    switch type {
    case .ofMarking: return data.attributedStringMarking
    case .ofAssociates, .ofSymbolTable: return data.attributedStringPlaceholder
    default: return data.attributedStringNormal
    }
  }

  /// 該參數僅用作輔助判斷。在 InputHandler 內使用的話，必須再檢查 !compositor.isEmpty。
  var hasComposition: Bool {
    switch type {
    case .ofInputting, .ofMarking, .ofCandidates: return true
    default: return false
    }
  }

  var isCandidateContainer: Bool {
    switch type {
    case .ofCandidates, .ofAssociates, .ofSymbolTable: return true
    default: return false
    }
  }

  var tooltipBackupForInputting: String {
    get { data.tooltipBackupForInputting }
    set { data.tooltipBackupForInputting = newValue }
  }

  var tooltipDuration: Double {
    get { type == .ofMarking ? 0 : data.tooltipDuration }
    set { data.tooltipDuration = newValue }
  }
}
