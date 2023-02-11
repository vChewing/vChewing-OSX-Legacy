// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Foundation

public extension Megrez {
  /// 一個組字器用來在給定一系列的索引鍵的情況下（藉由一系列的觀測行為）返回一套資料值。
  ///
  /// 用於輸入法的話，給定的索引鍵可以是注音、且返回的資料值都是漢語字詞組合。該組字器
  /// 還可以用來對文章做分節處理：此時的索引鍵為漢字，返回的資料值則是漢語字詞分節組合。
  ///
  /// - Remark: 雖然這裡用了隱性 Markov 模型（HMM）的術語，但實際上在爬軌時用到的則是更
  /// 簡單的貝氏推論：因為底層的語言模組只會提供單元圖資料。一旦將所有可以組字的單元圖
  /// 作為節點塞到組字器內，就可以用一個簡單的有向無環圖爬軌過程、來利用這些隱性資料值
  /// 算出最大相似估算結果。
  struct Compositor {
    /// 就文字輸入方向而言的方向。
    public enum TypingDirection { case front, rear }
    /// 軌格增減行為。
    public enum ResizeBehavior { case expand, shrink }
    /// 該軌格內可以允許的最大幅位長度。
    public static var maxSpanLength: Int = 10 { didSet { maxSpanLength = max(6, maxSpanLength) } }
    /// 多字讀音鍵當中用以分割漢字讀音的記號的預設值，是「-」。
    public static var theSeparator: String = "-"
    /// 該組字器的敲字游標位置。
    public var cursor: Int = 0 {
      didSet {
        cursor = max(0, min(cursor, length))
        marker = cursor
      }
    }

    /// 該組字器的標記器（副游標）位置。
    public var marker: Int = 0 { didSet { marker = max(0, min(marker, length)) } }
    /// 多字讀音鍵當中用以分割漢字讀音的記號，預設為「-」。
    public var separator = theSeparator {
      didSet {
        Self.theSeparator = separator
      }
    }

    /// 最近一次爬軌結果。
    public var walkedNodes: [Node] = []
    /// 該組字器的長度，組字器內已經插入的單筆索引鍵的數量，也就是內建漢字讀音的數量（唯讀）。
    /// - Remark: 理論上而言，spans.count 也是這個數。
    /// 但是，為了防止萬一，就用了目前的方法來計算。
    public var length: Int { keys.count }
    /// 組字器是否為空。
    public var isEmpty: Bool { spans.isEmpty && keys.isEmpty }

    /// 該組字器已經插入的的索引鍵，以陣列的形式存放。
    public private(set) var keys = [String]()
    /// 該組字器的幅位單元陣列。
    public private(set) var spans = [SpanUnit]()
    /// 該組字器所使用的語言模型（被 LangModelRanked 所封裝）。
    public var langModel: LangModelRanked {
      didSet { clear() }
    }

    /// 初期化一個組字器。
    /// - Parameter langModel: 要對接的語言模組。
    public init(with langModel: LangModelProtocol, separator: String = "-") {
      self.langModel = .init(withLM: langModel)
      self.separator = separator
    }

    /// 重置包括游標在內的各項參數，且清空各種由組字器生成的內部資料。
    ///
    /// 將已經被插入的索引鍵陣列與幅位單元陣列（包括其內的節點）全部清空。
    /// 最近一次的爬軌結果陣列也會被清空。游標跳轉換算表也會被清空。
    public mutating func clear() {
      cursor = 0
      marker = 0
      keys.removeAll()
      spans.removeAll()
      walkedNodes.removeAll()
    }

    /// 在游標位置插入給定的索引鍵。
    /// - Parameter key: 要插入的索引鍵。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public mutating func insertKey(_ key: String) -> Bool {
      guard !key.isEmpty, key != separator, langModel.hasUnigramsFor(keyArray: [key]) else { return false }
      keys.insert(key, at: cursor)
      let gridBackup = spans
      resizeGrid(at: cursor, do: .expand)
      let nodesInserted = update()
      // 用來在 langModel.hasUnigramsFor() 結果不準確的時候防呆、恢復被搞壞的 spans。
      if nodesInserted == 0 {
        spans = gridBackup
        return false
      }
      cursor += 1 // 游標必須得在執行 update() 之後才可以變動。
      return true
    }

    /// 朝著指定方向砍掉一個與游標相鄰的讀音。
    ///
    /// 在威注音的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear），反之則為向前（Front）。
    /// 如果是朝著與文字輸入方向相反的方向砍的話，游標位置會自動遞減。
    /// - Parameter direction: 指定方向（相對於文字輸入方向而言）。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public mutating func dropKey(direction: TypingDirection) -> Bool {
      let isBackSpace: Bool = direction == .rear ? true : false
      guard cursor != (isBackSpace ? 0 : keys.count) else { return false }
      keys.remove(at: cursor - (isBackSpace ? 1 : 0))
      cursor -= isBackSpace ? 1 : 0 // 在縮節之前。
      resizeGrid(at: cursor, do: .shrink)
      update()
      return true
    }

    /// 按幅位來前後移動游標。
    ///
    /// 在威注音的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear），反之則為向前（Front）。
    /// - Parameters:
    ///   - direction: 指定移動方向（相對於文字輸入方向而言）。
    ///   - isMarker: 要移動的是否為作為選擇標記的副游標（而非打字用的主游標）。
    /// 具體用法可以是這樣：你在標記模式下，
    /// 如果出現了「副游標切了某個字音數量不相等的節點」的情況的話，
    /// 則直接用這個函式將副游標往前推到接下來的正常的位置上。
    /// // 該特性不適用於小麥注音，除非小麥注音重新設計 InputState 且修改 KeyHandler、
    /// 將標記游標交給敝引擎來管理。屆時，NSStringUtils 將徹底卸任。
    /// - Returns: 該操作是否順利完成。
    @discardableResult public mutating func jumpCursorBySpan(to direction: TypingDirection, isMarker: Bool = false)
      -> Bool
    {
      var target = isMarker ? marker : cursor
      switch direction {
      case .front:
        if target == length { return false }
      case .rear:
        if target == 0 { return false }
      }
      guard let currentRegion = walkedNodes.cursorRegionMap[target] else { return false }

      let aRegionForward = max(currentRegion - 1, 0)
      let currentRegionBorderRear: Int = walkedNodes[0 ..< currentRegion].map(\.spanLength).reduce(0, +)
      switch target {
      case currentRegionBorderRear:
        switch direction {
        case .front:
          target =
            (currentRegion > walkedNodes.count)
              ? keys.count : walkedNodes[0 ... currentRegion].map(\.spanLength).reduce(0, +)
        case .rear:
          target = walkedNodes[0 ..< aRegionForward].map(\.spanLength).reduce(0, +)
        }
      default:
        switch direction {
        case .front:
          target = currentRegionBorderRear + walkedNodes[currentRegion].spanLength
        case .rear:
          target = currentRegionBorderRear
        }
      }
      switch isMarker {
      case false: cursor = target
      case true: marker = target
      }
      return true
    }

    /// 生成用以交給 GraphViz 診斷的資料檔案內容，純文字。
    public var dumpDOT: String {
      // C# StringBuilder 與 Swift NSMutableString 能提供爆發性的效能。
      let strOutput: NSMutableString = .init(string: "digraph {\ngraph [ rankdir=LR ];\nBOS;\n")
      for (p, span) in spans.enumerated() {
        for ni in 0 ... (span.maxLength) {
          guard let np = span.nodeOf(length: ni) else { continue }
          if p == 0 {
            strOutput.append("BOS -> \(np.value);\n")
          }
          strOutput.append("\(np.value);\n")
          if (p + ni) < spans.count {
            let destinationSpan = spans[p + ni]
            for q in 0 ... (destinationSpan.maxLength) {
              guard let dn = destinationSpan.nodeOf(length: q) else { continue }
              strOutput.append(np.value + " -> " + dn.value + ";\n")
            }
          }
          guard (p + ni) == spans.count else { continue }
          strOutput.append(np.value + " -> EOS;\n")
        }
      }
      strOutput.append("EOS;\n}\n")
      return strOutput.description
    }
  }
}

// MARK: - Internal Methods (Maybe Public)

extension Megrez.Compositor {
  /// 在該軌格的指定幅位座標擴增或減少一個幅位單元。
  /// - Parameters:
  ///   - location: 給定的幅位座標。
  ///   - action: 指定是擴張還是縮減一個幅位。
  mutating func resizeGrid(at location: Int, do action: ResizeBehavior) {
    let location = max(min(location, spans.count), 0) // 防呆
    switch action {
    case .expand:
      spans.insert(SpanUnit(), at: location)
      if [0, spans.count].contains(location) { return }
    case .shrink:
      if spans.count == location { return }
      spans.remove(at: location)
    }
    dropWreckedNodes(at: location)
  }

  /// 扔掉所有被 resizeGrid() 損毀的節點。
  ///
  /// 拿新增幅位來打比方的話，在擴增幅位之前：
  /// ```
  /// Span Index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// 在幅位座標 2 (SpanIndex = 2) 的位置擴增一個幅位之後:
  /// ```
  /// Span Index 0   1   2   3   4
  ///                (---)
  ///                (XXX?   ?XXX) <-被扯爛的節點
  ///            (XXXXXXX?   ?XXX) <-被扯爛的節點
  /// ```
  /// 拿縮減幅位來打比方的話，在縮減幅位之前：
  /// ```
  /// Span Index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// 在幅位座標 2 的位置就地砍掉一個幅位之後:
  /// ```
  /// Span Index 0   1   2   3   4
  ///                (---)
  ///                (XXX? <-被砍爛的節點
  ///            (XXXXXXX? <-被砍爛的節點
  /// ```
  /// - Parameter location: 給定的幅位座標。
  mutating func dropWreckedNodes(at location: Int) {
    let location = max(min(location, spans.count), 0) // 防呆
    guard !spans.isEmpty else { return }
    let affectedLength = Megrez.Compositor.maxSpanLength - 1
    let begin = max(0, location - affectedLength)
    guard location >= begin else { return }
    for i in begin ..< location {
      spans[i].dropNodesOfOrBeyond(length: location - i + 1)
    }
  }

  /// 自索引鍵陣列獲取指定範圍的資料。
  /// - Parameter range: 指定範圍。
  /// - Returns: 拿到的資料。
  func getJoinedKeyArray(range: Range<Int>) -> [String] {
    // 下面這句不能用 contains，不然會要求至少 macOS 13 Ventura。
    guard range.upperBound <= keys.count, range.lowerBound >= 0 else { return [] }
    return keys[range].map(\.description)
  }

  /// 在指定位置（以指定索引鍵陣列和指定幅位長度）拿取節點。
  /// - Parameters:
  ///   - location: 指定游標位置。
  ///   - length: 指定幅位長度。
  ///   - keyArray: 指定索引鍵陣列。
  /// - Returns: 拿取的節點。拿不到的話就會是 nil。
  func getNode(at location: Int, length: Int, keyArray: [String]) -> Node? {
    let location = max(min(location, spans.count - 1), 0) // 防呆
    guard let node = spans[location].nodeOf(length: length) else { return nil }
    return keyArray == node.keyArray ? node : nil
  }

  /// 根據當前狀況更新整個組字器的節點文脈。
  /// - Parameter updateExisting: 是否根據目前的語言模型的資料狀態來對既有節點更新其內部的單元圖陣列資料。
  /// 該特性可以用於「在選字窗內屏蔽了某個詞之後，立刻生效」這樣的軟體功能需求的實現。
  /// - Returns: 新增或影響了多少個節點。如果返回「0」則表示可能發生了錯誤。
  @discardableResult public mutating func update(updateExisting: Bool = false) -> Int {
    let maxSpanLength = Megrez.Compositor.maxSpanLength
    let range = max(0, cursor - maxSpanLength) ..< min(cursor + maxSpanLength, keys.count)
    var nodesChanged = 0
    for position in range {
      for theLength in 1 ... min(maxSpanLength, range.upperBound - position) {
        let joinedKeyArray = getJoinedKeyArray(range: position ..< (position + theLength))
        if let theNode = getNode(at: position, length: theLength, keyArray: joinedKeyArray) {
          if !updateExisting { continue }
          let unigrams = langModel.unigramsFor(keyArray: joinedKeyArray)
          // 自動銷毀無效的節點。
          if unigrams.isEmpty {
            if theNode.keyArray.count == 1 { continue }
            spans[position].nodes.removeAll { $0 == theNode }
          } else {
            theNode.syncingUnigrams(from: unigrams)
          }
          nodesChanged += 1
          continue
        }
        let unigrams = langModel.unigramsFor(keyArray: joinedKeyArray)
        guard !unigrams.isEmpty else { continue }
        spans[position].append(
          node: .init(keyArray: joinedKeyArray, spanLength: theLength, unigrams: unigrams)
        )
        nodesChanged += 1
      }
    }
    return nodesChanged
  }
}
