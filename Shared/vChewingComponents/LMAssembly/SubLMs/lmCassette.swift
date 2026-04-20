// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 以連續記憶體空間（contiguous Data blob）取代大量 Dictionary<String, [String]>，
// 將 charDef / symbolDef / reverseLookup / octagram 等大型字典改為
// sorted byte-range index + binary search，按需從 rawData 解析字串，
// 大幅降低 heap allocation 與 Dictionary 開銷。

import Foundation

// MARK: - LMAssembly.LMCassette

extension LMAssembly {
  /// 磁帶模組，用來方便使用者自行擴充字根輸入法。
  /// 以連續記憶體 Data blob + byte-range 索引取代各大型 Dictionary。
  struct LMCassette: Sendable {
    // MARK: Internal

    private(set) var filePath: String?
    private(set) var nameShort: String = ""
    private(set) var nameENG: String = ""
    private(set) var nameCJK: String = ""
    private(set) var nameIntl: String = ""
    private(set) var nullCandidate: String = ""
    /// 一個漢字可能最多要用到多少碼。
    private(set) var maxKeyLength: Int = 1
    private(set) var selectionKeys: String = ""
    private(set) var endKeys: [String] = []
    private(set) var wildcardKey: String = ""
    private(set) var keysToDirectlyCommit: String = ""
    /// 字根翻譯表（小型，~30 entries），保持 Dictionary。
    private(set) var keyNameMap: [String: String] = [:]
    /// `%quick` 簡碼資料（中型），保持 Dictionary（值為字元拼接字串）。
    private(set) var quickDefMap: [String: String] = [:]
    /// `%quickphrases` 詞語資料（極小，<10 entries），保持 Dictionary。
    private(set) var quickPhraseMap: [String: [String]] = [:]
    private(set) var quickPhraseCommissionKey: String = ""

    // 大型資料結構改為 contiguous-memory 索引。
    /// `%chardef` 字根→字詞對照，sorted by key UTF-8。
    private(set) var charDefMap: CassetteSortedMap = .init()
    /// `%chardef` wildcard 前綴對照，sorted by synthetic wildcard key UTF-8。
    private(set) var charDefWildcardMap: CassetteSortedMap = .init()
    /// `%symboldef` 符號選單資料，sorted by key UTF-8。
    private(set) var symbolDefMap: CassetteSortedMap = .init()
    /// 字→碼反向查詢（chardef + symboldef 合併），sorted by value UTF-8。
    private(set) var reverseLookupMap: CassetteSortedMap = .init()
    /// 字根輸入法專用八股文：字詞→頻次，sorted by key UTF-8。
    private(set) var octagramMap: CassetteOctagramMap = .init()
    /// 音韻輸入法專用八股文：字詞→(頻次, 讀音)，sorted by key UTF-8。
    private(set) var octagramDividedMap: CassetteOctagramDividedMap = .init()

    private(set) var areCandidateKeysShiftHeld: Bool = false
    private(set) var supplyQuickResults: Bool = false
    private(set) var supplyPartiallyMatchedResults: Bool = false
    var candidateKeysValidator: @Sendable (String) -> Bool = { _ in false }

    // MARK: Private

    /// 計算頻率時要用到的東西 - NORM
    private var norm = 0.0
  }
}

// MARK: - Contiguous-Memory Index Types

extension LMAssembly {
  /// 以連續 Data blob 承載的 sorted key→[value] 對照表。
  struct CassetteSortedMap: Sendable {
    // MARK: Internal

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    // MARK: Fileprivate

    fileprivate var rawData: Data = .init()
    fileprivate var entries: [CassetteMapEntry] = []
    fileprivate var allValues: [CassetteByteRange] = []
  }

  struct CassetteMapEntry: Sendable {
    let keyStart: Int
    let keyEnd: Int
    let valuesStart: Int
    let valuesEnd: Int
  }

  struct CassetteByteRange: Sendable {
    let start: Int
    let end: Int
  }

  struct CassetteOctagramMap: Sendable {
    // MARK: Internal

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    // MARK: Fileprivate

    fileprivate var rawData: Data = .init()
    fileprivate var entries: [CassetteOctagramEntry] = []
  }

  struct CassetteOctagramEntry: Sendable {
    let keyStart: Int
    let keyEnd: Int
    let count: Int
  }

  struct CassetteOctagramDividedMap: Sendable {
    // MARK: Internal

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    // MARK: Fileprivate

    fileprivate var rawData: Data = .init()
    fileprivate var entries: [CassetteOctagramDividedEntry] = []
  }

  struct CassetteOctagramDividedEntry: Sendable {
    let keyStart: Int
    let keyEnd: Int
    let count: Int
    let readingStart: Int
    let readingEnd: Int
  }
}

// MARK: - CassetteSortedMap: Binary Search & Query API

extension LMAssembly.CassetteSortedMap {
  fileprivate func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0, hi = entries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.cassetteCompareUTF8Range(e.keyStart ..< e.keyEnd, with: keyUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
    }
    return nil
  }

  func valuesFor(key: String) -> [String]? {
    guard let idx = binarySearchIndex(for: key) else { return nil }
    let e = entries[idx]
    var result = [String]()
    result.reserveCapacity(e.valuesEnd - e.valuesStart)
    for i in e.valuesStart ..< e.valuesEnd {
      let vr = allValues[i]
      result.append(String(decoding: rawData[vr.start ..< vr.end], as: UTF8.self))
    }
    return result
  }

  subscript(key: String) -> [String]? {
    valuesFor(key: key)
  }

  func containsKey(_ key: String) -> Bool {
    binarySearchIndex(for: key) != nil
  }

  func prefixScan(prefix: String) -> [(key: String, values: [String])] {
    let prefixUTF8 = Array(prefix.utf8)
    guard !prefixUTF8.isEmpty else { return [] }
    var lo = 0, hi = entries.count
    while lo < hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.cassetteCompareUTF8RangePrefix(e.keyStart ..< e.keyEnd, with: prefixUTF8)
      if cmp < 0 { lo = mid + 1 } else { hi = mid }
    }
    var results = [(key: String, values: [String])]()
    while lo < entries.count {
      let e = entries[lo]
      let keyLen = e.keyEnd - e.keyStart
      guard keyLen >= prefixUTF8.count else { break }
      var isPrefix = true
      for i in 0 ..< prefixUTF8.count {
        if rawData[e.keyStart + i] != prefixUTF8[i] { isPrefix = false; break }
      }
      guard isPrefix else { break }
      let key = String(decoding: rawData[e.keyStart ..< e.keyEnd], as: UTF8.self)
      var vals = [String]()
      vals.reserveCapacity(e.valuesEnd - e.valuesStart)
      for i in e.valuesStart ..< e.valuesEnd {
        let vr = allValues[i]
        vals.append(String(decoding: rawData[vr.start ..< vr.end], as: UTF8.self))
      }
      results.append((key, vals))
      lo += 1
    }
    return results
  }

  var keys: [String] {
    entries.map { String(decoding: rawData[$0.keyStart ..< $0.keyEnd], as: UTF8.self) }
  }
}

// MARK: - CassetteOctagramMap: Binary Search

extension LMAssembly.CassetteOctagramMap {
  fileprivate func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0, hi = entries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.cassetteCompareUTF8Range(e.keyStart ..< e.keyEnd, with: keyUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
    }
    return nil
  }

  subscript(key: String) -> Int? {
    guard let idx = binarySearchIndex(for: key) else { return nil }
    return entries[idx].count
  }
}

extension LMAssembly.CassetteOctagramDividedMap {
  fileprivate func binarySearchIndex(for key: String) -> Int? {
    let keyUTF8 = Array(key.utf8)
    var lo = 0, hi = entries.count - 1
    while lo <= hi {
      let mid = lo + (hi - lo) / 2
      let e = entries[mid]
      let cmp = rawData.cassetteCompareUTF8Range(e.keyStart ..< e.keyEnd, with: keyUTF8)
      if cmp < 0 { lo = mid + 1 } else if cmp > 0 { hi = mid - 1 } else { return mid }
    }
    return nil
  }

  subscript(key: String) -> (Int, String)? {
    guard let idx = binarySearchIndex(for: key) else { return nil }
    let e = entries[idx]
    let reading = String(decoding: rawData[e.readingStart ..< e.readingEnd], as: UTF8.self)
    return (e.count, reading)
  }
}

// MARK: - Data Extension: UTF-8 Byte-Level Comparison

extension Data {
  fileprivate func cassetteCompareUTF8Range(_ range: Range<Int>, with rhs: [UInt8]) -> Int {
    let lhsCount = range.count
    let rhsCount = rhs.count
    let minCount = Swift.min(lhsCount, rhsCount)
    for i in 0 ..< minCount {
      let lb = self[range.lowerBound + i]
      let rb = rhs[i]
      if lb < rb { return -1 }
      if lb > rb { return 1 }
    }
    if lhsCount < rhsCount { return -1 }
    if lhsCount > rhsCount { return 1 }
    return 0
  }

  fileprivate func cassetteCompareUTF8RangePrefix(_ range: Range<Int>, with prefix: [UInt8]) -> Int {
    let lhsCount = range.count
    let prefixCount = prefix.count
    let minCount = Swift.min(lhsCount, prefixCount)
    for i in 0 ..< minCount {
      let lb = self[range.lowerBound + i]
      let rb = prefix[i]
      if lb < rb { return -1 }
      if lb > rb { return 1 }
    }
    if lhsCount < prefixCount { return -1 }
    return 0
  }
}

// MARK: - CassetteSortedMap Builder

extension LMAssembly.CassetteSortedMap {
  static func build(from dictionary: [String: [String]]) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    var totalBytes = 0
    var totalValueCount = 0
    for (key, values) in dictionary {
      totalBytes += key.utf8.count
      totalValueCount += values.count
      for value in values { totalBytes += value.utf8.count }
    }
    let sortedKeys = dictionary.keys.sorted { lhs, rhs in
      lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
    var rawData = Data(capacity: totalBytes)
    var entries = [LMAssembly.CassetteMapEntry]()
    entries.reserveCapacity(sortedKeys.count)
    var allValues = [LMAssembly.CassetteByteRange]()
    allValues.reserveCapacity(totalValueCount)
    for key in sortedKeys {
      guard let values = dictionary[key] else { continue }
      let keyStart = rawData.count
      rawData.append(contentsOf: key.utf8)
      let keyEnd = rawData.count
      let valuesStart = allValues.count
      for value in values {
        let valueStart = rawData.count
        rawData.append(contentsOf: value.utf8)
        allValues.append(.init(start: valueStart, end: rawData.count))
      }
      entries.append(.init(
        keyStart: keyStart,
        keyEnd: keyEnd,
        valuesStart: valuesStart,
        valuesEnd: allValues.count
      ))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    result.allValues = allValues
    return result
  }

  static func buildWildcard(from dictionary: [String: [String]], wildcard: String) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    typealias Prototype = (key: String, values: [String])
    var prototypeCount = 0
    var totalValueBytes = 0
    var totalValueCount = 0
    for (key, values) in dictionary {
      let wildcardDepth = key.count
      guard wildcardDepth > 0 else { continue }
      prototypeCount += wildcardDepth
      totalValueCount += values.count * wildcardDepth
      let perValueBytes = values.reduce(into: 0) { partialResult, value in
        partialResult += value.utf8.count
      }
      totalValueBytes += perValueBytes * wildcardDepth
    }
    var prototypes = [Prototype]()
    prototypes.reserveCapacity(prototypeCount)
    for (key, values) in dictionary {
      var prefix = key
      while !prefix.isEmpty {
        prefix.removeLast()
        prototypes.append((prefix + wildcard, values))
      }
    }
    guard !prototypes.isEmpty else { return .init() }
    prototypes.sort { lhs, rhs in
      lhs.key.utf8.lexicographicallyPrecedes(rhs.key.utf8)
    }
    var totalKeyBytes = 0
    var previousKey: String?
    for prototype in prototypes where prototype.key != previousKey {
      totalKeyBytes += prototype.key.utf8.count
      previousKey = prototype.key
    }
    var rawData = Data(capacity: totalKeyBytes + totalValueBytes)
    var entries = [LMAssembly.CassetteMapEntry]()
    var allValues = [LMAssembly.CassetteByteRange]()
    entries.reserveCapacity(prototypes.count)
    allValues.reserveCapacity(totalValueCount)
    var index = 0
    while index < prototypes.count {
      let currentKey = prototypes[index].key
      let keyStart = rawData.count
      rawData.append(contentsOf: currentKey.utf8)
      let keyEnd = rawData.count
      let valuesStart = allValues.count
      while index < prototypes.count, prototypes[index].key == currentKey {
        for value in prototypes[index].values {
          let valueStart = rawData.count
          rawData.append(contentsOf: value.utf8)
          allValues.append(.init(start: valueStart, end: rawData.count))
        }
        index += 1
      }
      entries.append(.init(
        keyStart: keyStart,
        keyEnd: keyEnd,
        valuesStart: valuesStart,
        valuesEnd: allValues.count
      ))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    result.allValues = allValues
    return result
  }

  static func buildReverseLookup(
    charDefs: [String: [String]],
    symbolDefs: [String: [String]]
  )
    -> Self {
    typealias Prototype = (lookupKey: String, sourceKey: String)

    func makePrototypes(from dictionary: [String: [String]]) -> [Prototype] {
      var prototypeCount = 0
      for values in dictionary.values { prototypeCount += values.count }
      var prototypes = [Prototype]()
      prototypes.reserveCapacity(prototypeCount)
      for (sourceKey, values) in dictionary {
        for lookupKey in values {
          prototypes.append((lookupKey, sourceKey))
        }
      }
      return prototypes
    }

    var prototypes = makePrototypes(from: charDefs)
    prototypes.append(contentsOf: makePrototypes(from: symbolDefs))
    guard !prototypes.isEmpty else { return .init() }
    prototypes.sort { lhs, rhs in
      lhs.lookupKey.utf8.lexicographicallyPrecedes(rhs.lookupKey.utf8)
    }
    var totalKeyBytes = 0
    var totalValueBytes = 0
    var previousLookupKey: String?
    for prototype in prototypes {
      if prototype.lookupKey != previousLookupKey {
        totalKeyBytes += prototype.lookupKey.utf8.count
        previousLookupKey = prototype.lookupKey
      }
      totalValueBytes += prototype.sourceKey.utf8.count
    }
    var rawData = Data(capacity: totalKeyBytes + totalValueBytes)
    var entries = [LMAssembly.CassetteMapEntry]()
    entries.reserveCapacity(prototypes.count)
    var allValues = [LMAssembly.CassetteByteRange]()
    allValues.reserveCapacity(prototypes.count)
    var index = 0
    while index < prototypes.count {
      let currentLookupKey = prototypes[index].lookupKey
      let keyStart = rawData.count
      rawData.append(contentsOf: currentLookupKey.utf8)
      let keyEnd = rawData.count
      let valuesStart = allValues.count
      while index < prototypes.count, prototypes[index].lookupKey == currentLookupKey {
        let valueStart = rawData.count
        rawData.append(contentsOf: prototypes[index].sourceKey.utf8)
        allValues.append(.init(start: valueStart, end: rawData.count))
        index += 1
      }
      entries.append(.init(
        keyStart: keyStart,
        keyEnd: keyEnd,
        valuesStart: valuesStart,
        valuesEnd: allValues.count
      ))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    result.allValues = allValues
    return result
  }
}

// MARK: - CassetteOctagramMap Builder

extension LMAssembly.CassetteOctagramMap {
  static func build(from dictionary: [String: Int]) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    let sortedKeys = dictionary.keys.sorted { lhs, rhs in
      lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
    var totalBytes = 0
    for key in sortedKeys { totalBytes += key.utf8.count }
    var rawData = Data(capacity: totalBytes)
    var entries = [LMAssembly.CassetteOctagramEntry]()
    entries.reserveCapacity(sortedKeys.count)
    for key in sortedKeys {
      guard let count = dictionary[key] else { continue }
      let keyStart = rawData.count
      rawData.append(contentsOf: key.utf8)
      entries.append(.init(keyStart: keyStart, keyEnd: rawData.count, count: count))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    return result
  }
}

extension LMAssembly.CassetteOctagramDividedMap {
  static func build(from dictionary: [String: (Int, String)]) -> Self {
    guard !dictionary.isEmpty else { return .init() }
    let sortedKeys = dictionary.keys.sorted { lhs, rhs in
      lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
    var totalBytes = 0
    for key in sortedKeys {
      guard let value = dictionary[key] else { continue }
      totalBytes += key.utf8.count + value.1.utf8.count
    }
    var rawData = Data(capacity: totalBytes)
    var entries = [LMAssembly.CassetteOctagramDividedEntry]()
    entries.reserveCapacity(sortedKeys.count)
    for key in sortedKeys {
      guard let value = dictionary[key] else { continue }
      let keyStart = rawData.count
      rawData.append(contentsOf: key.utf8)
      let keyEnd = rawData.count
      let readingStart = rawData.count
      rawData.append(contentsOf: value.1.utf8)
      entries.append(.init(
        keyStart: keyStart,
        keyEnd: keyEnd,
        count: value.0,
        readingStart: readingStart,
        readingEnd: rawData.count
      ))
    }
    var result = Self()
    result.rawData = rawData
    result.entries = entries
    return result
  }
}

// MARK: - LMCassette Public API

extension LMAssembly.LMCassette {
  /// 計算頻率時要用到的東西 - fscale
  private static let fscale = 2.7
  /// 萬用花牌字符，哪怕花牌鍵仍不可用。
  var wildcard: String { wildcardKey.isEmpty ? "†" : wildcardKey }
  /// 資料陣列內承載的核心 charDef 資料筆數（唯一 key 數量）。
  var count: Int { charDefMap.count }
  /// 是否已有資料載入。
  var isLoaded: Bool { !charDefMap.isEmpty }
  /// 返回「允許使用的敲字鍵」的陣列。
  var allowedKeys: [String] { Array(keyNameMap.keys + [" "]).deduplicated }
  /// 將給定的按鍵字母轉換成要顯示的形態。
  func convertKeyToDisplay(char: String) -> String {
    keyNameMap[char] ?? char
  }

  /// 載入給定的 CIN 檔案內容。
  @discardableResult
  mutating func open(_ path: String) -> Bool {
    if isLoaded { return false }
    let oldPath = filePath
    filePath = nil
    if FileManager.default.fileExists(atPath: path) {
      do {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
          throw LMAssembly.FileErrors.fileHandleError("")
        }
        let lineReader = try LineReader(file: fileHandle)
        var theMaxKeyLength = 1
        var loadingKeys = false

        // 僅保留必要的 grouped Dictionary；reverse / wildcard 改在建構期以輕量 prototype 直接生成。
        var tmpCharDef = [String: [String]]()
        var tmpSymbolDef = [String: [String]]()
        var tmpOctagram = [String: Int]()
        var tmpOctagramDivided = [String: (Int, String)]()

        var loadingQuickSets = false {
          willSet {
            supplyQuickResults = true
            if !newValue, quickDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
          }
        }
        var loadingCharDefinitions = false {
          willSet {
            if !newValue, tmpCharDef.keys.contains(wildcardKey) { wildcardKey = "" }
          }
        }
        var loadingSymbolDefinitions = false {
          willSet {
            if !newValue, tmpSymbolDef.keys.contains(wildcardKey) { wildcardKey = "" }
          }
        }
        var loadingOctagramData = false
        var loadingQuickPhrases = false
        var keysUsedInCharDef: Set<String> = .init()

        for strLine in lineReader {
          let isTabDelimiting = strLine.contains("\t")
          let cells = isTabDelimiting ? strLine.split(separator: "\t") : strLine
            .split(separator: " ")
          guard cells.count >= 1 else { continue }
          let strFirstCell = cells[0].trimmingCharacters(in: .newlines)
          let strSecondCell = cells.count >= 2 ? cells[1].trimmingCharacters(in: .newlines) : nil
          if strLine.first == "%", strFirstCell != "%" {
            if strLine == "%flag_disp_partial_match" {
              supplyPartiallyMatchedResults = true
              supplyQuickResults = true
            }
            guard let strSecondCell = strSecondCell else { continue }
            processTags: switch strFirstCell {
            case "%keyname" where strSecondCell == "begin": loadingKeys = true
            case "%keyname" where strSecondCell == "end": loadingKeys = false
            case "%quick" where strSecondCell == "begin": loadingQuickSets = true
            case "%quick" where strSecondCell == "end": loadingQuickSets = false
            case "%chardef" where strSecondCell == "begin": loadingCharDefinitions = true
            case "%chardef" where strSecondCell == "end": loadingCharDefinitions = false
            case "%symboldef" where strSecondCell == "begin": loadingSymbolDefinitions = true
            case "%symboldef" where strSecondCell == "end": loadingSymbolDefinitions = false
            case "%octagram" where strSecondCell == "begin": loadingOctagramData = true
            case "%octagram" where strSecondCell == "end": loadingOctagramData = false
            case "%quickphrases" where strSecondCell == "begin": loadingQuickPhrases = true
            case "%quickphrases" where strSecondCell == "end": loadingQuickPhrases = false
            case "%ename" where nameENG.isEmpty:
              parseSubCells: for neta in strSecondCell.components(separatedBy: ";") {
                let subNetaGroup = neta.components(separatedBy: ":")
                guard subNetaGroup.count == 2, subNetaGroup[1].contains("en") else { continue }
                nameENG = String(subNetaGroup[0])
                break parseSubCells
              }
              guard nameENG.isEmpty else { break processTags }
              nameENG = strSecondCell
            case "%intlname"
              where nameIntl.isEmpty: nameIntl = strSecondCell
              .replacingOccurrences(of: "_", with: " ")
            case "%cname" where nameCJK.isEmpty: nameCJK = strSecondCell
            case "%sname" where nameShort.isEmpty: nameShort = strSecondCell
            case "%nullcandidate" where nullCandidate.isEmpty: nullCandidate = strSecondCell
            case "%selkey"
              where selectionKeys.isEmpty: selectionKeys = strSecondCell.map(\.description)
              .deduplicated.joined()
            case "%endkey"
              where endKeys.isEmpty: endKeys = strSecondCell.map(\.description).deduplicated
            case "%wildcardkey"
              where wildcardKey.isEmpty: wildcardKey = strSecondCell.first?.description ?? ""
            case "%keys_to_directly_commit"
              where keysToDirectlyCommit.isEmpty: keysToDirectlyCommit = strSecondCell
            case "%quickphrases_commission_key"
              where quickPhraseCommissionKey.isEmpty:
              quickPhraseCommissionKey = strSecondCell.first?.description ?? ""
            default: break processTags
            }
            continue
          }

          guard let strSecondCell = strSecondCell else { continue }
          if loadingKeys {
            keyNameMap[strFirstCell] = strSecondCell.trimmingCharacters(in: .newlines)
          } else if loadingQuickSets {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            quickDefMap[strFirstCell, default: .init()].append(strSecondCell)
          } else if loadingQuickPhrases {
            theMaxKeyLength = max(theMaxKeyLength, strFirstCell.count)
            var remainderLine = strLine.trimmingCharacters(in: .newlines)
            if remainderLine.hasPrefix(strFirstCell) {
              remainderLine.removeFirst(strFirstCell.count)
            }
            let trimmedRemainder = remainderLine.drop(while: { $0 == "\t" || $0 == " " })
            let remainderString = String(trimmedRemainder)
            var phraseCandidates: [String] = []
            if isTabDelimiting {
              phraseCandidates = remainderString.split(separator: "\t").map {
                $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
              }
            } else {
              let trimmed = remainderString
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
              if !trimmed.isEmpty { phraseCandidates = [trimmed] }
            }
            let sanitized = phraseCandidates
              .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
              .filter { !$0.isEmpty && $0 != nullCandidate }
            guard !sanitized.isEmpty else { continue }
            var phrases = quickPhraseMap[strFirstCell, default: []]
            phrases.append(contentsOf: sanitized)
            phrases = phrases
              .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
              .filter { !$0.isEmpty && $0 != nullCandidate }
              .deduplicated
            quickPhraseMap[strFirstCell] = phrases
          } else if loadingCharDefinitions, !loadingSymbolDefinitions {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            tmpCharDef[strFirstCell, default: []].append(strSecondCell)
            if strFirstCell.count > 1 {
              strFirstCell.map(\.description).forEach { keyChar in
                keysUsedInCharDef.insert(keyChar.description)
              }
            }
          } else if loadingSymbolDefinitions {
            theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
            tmpSymbolDef[strFirstCell, default: []].append(strSecondCell)
          } else if loadingOctagramData {
            guard let countValue = Int(strSecondCell) else { continue }
            switch cells.count {
            case 2: tmpOctagram[strFirstCell] = countValue
            case 3: tmpOctagramDivided[strFirstCell] = (
                countValue,
                cells[2].trimmingCharacters(in: .newlines)
              )
            default: break
            }
            let powResult = pow(Self.fscale, Double(cells[0].count) / 3.0 - 1.0)
            norm += powResult * Double(countValue)
          }
        }
        // Post process.
        if !candidateKeysValidator(selectionKeys) { selectionKeys = "1234567890" }
        if !keysUsedInCharDef.intersection(selectionKeys.map(\.description)).isEmpty {
          areCandidateKeysShiftHeld = true
        }
        maxKeyLength = theMaxKeyLength
        keyNameMap[wildcardKey] = keyNameMap[wildcardKey] ?? "？"

        // 直接從 grouped Dictionary 建構最終索引，避免 reverse / wildcard 的額外大型暫存結構。
        let theWildcard = wildcard
        charDefMap = .build(from: tmpCharDef)
        charDefWildcardMap = .buildWildcard(from: tmpCharDef, wildcard: theWildcard)
        symbolDefMap = .build(from: tmpSymbolDef)
        reverseLookupMap = .buildReverseLookup(charDefs: tmpCharDef, symbolDefs: tmpSymbolDef)
        octagramMap = .build(from: tmpOctagram)
        octagramDividedMap = .build(from: tmpOctagramDivided)

        filePath = path
        return true
      } catch {
        vCLMLog("CIN Loading Failed: File Access Error.")
      }
    } else {
      vCLMLog("CIN Loading Failed: File Missing.")
    }
    filePath = oldPath
    return false
  }

  mutating func clear() {
    keyNameMap.removeAll(keepingCapacity: false)
    quickDefMap.removeAll(keepingCapacity: false)
    quickPhraseMap.removeAll(keepingCapacity: false)
    endKeys.removeAll(keepingCapacity: false)
    charDefMap = .init()
    charDefWildcardMap = .init()
    symbolDefMap = .init()
    reverseLookupMap = .init()
    octagramMap = .init()
    octagramDividedMap = .init()
    self = .init()
  }

  func quickSetsFor(key: String) -> String? {
    guard !key.isEmpty else { return nil }
    var result = [String]()
    if let specifiedResult = quickDefMap[key], !specifiedResult.isEmpty {
      result.append(contentsOf: specifiedResult.map(\.description))
    }
    if supplyQuickResults, result.isEmpty {
      if supplyPartiallyMatchedResults {
        let fetched = charDefMap.prefixScan(prefix: key)
          .sorted { $0.key.count < $1.key.count }
          .flatMap(\.values)
          .filter { $0.count == 1 }
        result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
      } else {
        let fetched = (charDefMap.valuesFor(key: key) ?? []).filter { $0.count == 1 }
        result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
      }
    }
    return result.isEmpty ? nil : result.joined(separator: "\t")
  }

  func quickPhrasesFor(key: String) -> [String]? {
    guard !key.isEmpty else { return nil }
    guard let phrases = quickPhraseMap[key]?
      .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
      .filter({ !$0.isEmpty }) else { return nil }
    let sanitized = phrases.filter { $0 != nullCandidate }.deduplicated
    return sanitized.isEmpty ? nil : sanitized
  }

  func unigramsFor(key: String, keyArray: [String]? = nil) -> [Homa.Gram] {
    let keyArray = keyArray ?? key.split(separator: "-").map(\.description)
    let arrRaw = (charDefMap.valuesFor(key: key) ?? []).deduplicated
    var arrRawWildcard: [String] = []
    if let arrRawWildcardValues = charDefWildcardMap.valuesFor(key: key)?.deduplicated,
       key.contains(wildcard), key.first?.description != wildcard {
      arrRawWildcard.append(contentsOf: arrRawWildcardValues)
    }
    var arrResults = [Homa.Gram]()
    var lowestScore: Double = 0
    for neta in arrRaw {
      let theScore: Double = {
        if let freqDataPair = octagramDividedMap[neta], key == freqDataPair.1 {
          return calculateWeight(count: freqDataPair.0, phraseLength: neta.count)
        } else if let freqData = octagramMap[neta] {
          return calculateWeight(count: freqData, phraseLength: neta.count)
        }
        return Double(arrResults.count) * -0.001 - 9.5
      }()
      lowestScore = min(theScore, lowestScore)
      arrResults.append(.init(keyArray: keyArray, value: neta, score: theScore))
    }
    lowestScore = min(-9.5, lowestScore)
    if !arrRawWildcard.isEmpty {
      for neta in arrRawWildcard {
        var theScore: Double = {
          if let freqDataPair = octagramDividedMap[neta], key == freqDataPair.1 {
            return calculateWeight(count: freqDataPair.0, phraseLength: neta.count)
          } else if let freqData = octagramMap[neta] {
            return calculateWeight(count: freqData, phraseLength: neta.count)
          }
          return Double(arrResults.count) * -0.001 - 9.7
        }()
        theScore += lowestScore
        arrResults.append(.init(keyArray: keyArray, value: neta, score: theScore))
      }
    }
    return arrResults
  }

  func hasUnigramsFor(key: String) -> Bool {
    if charDefMap.containsKey(key) { return true }
    guard charDefWildcardMap.containsKey(key) else { return false }
    guard key.contains(wildcard) else { return false }
    return key.first?.description != wildcard
  }

  // MARK: - Private Functions.

  private func calculateWeight(count theCount: Int, phraseLength: Int) -> Double {
    var weight: Double = 0
    switch theCount {
    case -2: // 拗音假名
      weight = -13
    case -1: // 單個假名
      weight = -13
    case 0: // 墊底低頻漢字與詞語
      weight = log10(
        pow(Self.fscale, Double(phraseLength) / 3.0 - 1.0) * 0.25 / norm
      )
    default:
      weight = log10(
        pow(Self.fscale, Double(phraseLength) / 3.0 - 1.0) * Double(theCount) / norm
      )
    }
    return weight
  }
}
