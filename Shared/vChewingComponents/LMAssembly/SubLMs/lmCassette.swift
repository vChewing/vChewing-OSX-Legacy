// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public extension vChewingLM {
  /// 磁帶模組，用來方便使用者自行擴充字根輸入法。
  @frozen struct LMCassette {
    public private(set) var filePath: String?
    public private(set) var nameShort: String = ""
    public private(set) var nameENG: String = ""
    public private(set) var nameCJK: String = ""
    public private(set) var nameIntl: String = ""
    public private(set) var nullCandidate: String = ""
    /// 一個漢字可能最多要用到多少碼。
    public private(set) var maxKeyLength: Int = 1
    public private(set) var selectionKeys: String = ""
    public private(set) var endKeys: [String] = []
    public private(set) var wildcardKey: String = ""
    public private(set) var keysToDirectlyCommit: String = ""
    public private(set) var keyNameMap: [String: String] = [:]
    public private(set) var quickDefMap: [String: String] = [:]
    public private(set) var charDefMap: [String: [String]] = [:]
    public private(set) var charDefWildcardMap: [String: [String]] = [:]
    public private(set) var symbolDefMap: [String: [String]] = [:]
    public private(set) var reverseLookupMap: [String: [String]] = [:]
    /// 字根輸入法專用八股文：[字詞:頻次]。
    public private(set) var octagramMap: [String: Int] = [:]
    /// 音韻輸入法專用八股文：[字詞:(頻次, 讀音)]。
    public private(set) var octagramDividedMap: [String: (Int, String)] = [:]
    public private(set) var areCandidateKeysShiftHeld: Bool = false
    public private(set) var supplyQuickResults: Bool = false
    public private(set) var supplyPartiallyMatchedResults: Bool = false

    /// 計算頻率時要用到的東西
    private static let fscale = 2.7
    private var norm = 0.0

    /// 萬用花牌字符，哪怕花牌鍵仍不可用。
    public var wildcard: String { wildcardKey.isEmpty ? "†" : wildcardKey }
    /// 資料陣列內承載的核心 charDef 資料筆數。
    public var count: Int { charDefMap.count }
    /// 是否已有資料載入。
    public var isLoaded: Bool { !charDefMap.isEmpty }
    /// 返回「允許使用的敲字鍵」的陣列。
    public var allowedKeys: [String] { Array(keyNameMap.keys + [" "]).deduplicated }
    /// 將給定的按鍵字母轉換成要顯示的形態。
    public func convertKeyToDisplay(char: String) -> String {
      keyNameMap[char] ?? char
    }

    /// 載入給定的 CIN 檔案內容。
    /// - Note:
    /// - 檢查是否以 `%gen_inp` 或者 `%ename` 開頭、以確認其是否為 cin 檔案。在讀到這些資訊之前的行都會被忽略。
    /// - `%ename` 決定磁帶的英文名、`%cname` 決定磁帶的 CJK 名稱、
    /// `%sname` 決定磁帶的最短英文縮寫名稱、`%intlname` 決定磁帶的本地化名稱綜合字串。
    /// - `%encoding` 不處理，因為 Swift 只認 UTF-8。
    /// - `%selkey`  不處理，因為威注音輸入法有自己的選字鍵體系。
    /// - `%endkey` 是會觸發組字事件的按鍵。
    /// - `%wildcardkey` 決定磁帶的萬能鍵名稱，只有第一個字元會生效。
    /// - `%nullcandidate` 用來指明 `%quick` 字段給出的候選字當中有哪一種是無效的。
    /// - `%keyname begin` 至 `%keyname end` 之間是字根翻譯表，先讀取為 Swift 辭典以備用。
    /// - `%quick begin` 至 `%quick end` 之間則是簡碼資料，對應的 value 得拆成單個漢字。
    /// - `%chardef begin` 至 `%chardef end` 之間則是詞庫資料。
    /// - `%symboldef begin` 至 `%symboldef end` 之間則是符號選單的專用資料。
    /// - `%octagram begin` 至 `%octagram end` 之間則是詞語頻次資料。
    /// 第三欄資料為對應字根、可有可無。第一欄與第二欄分別為「字詞」與「統計頻次」。
    /// - Parameter path: 檔案路徑。
    /// - Returns: 是否載入成功。
    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }
      let oldPath = filePath
      filePath = nil
      if FileManager.default.fileExists(atPath: path) {
        do {
          guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw FileErrors.fileHandleError("")
          }
          let lineReader = try LineReader(file: fileHandle)
          var theMaxKeyLength = 1
          var loadingKeys = false
          var loadingQuickSets = false
          var loadingCharDefinitions = false
          var loadingSymbolDefinitions = false
          var loadingOctagramData = false
          var keysUsedInCharDef: Set<String> = .init()
          for strLine in lineReader {
            if strLine.starts(with: "%keyname") {
              if !loadingKeys, strLine.contains("begin") { loadingKeys = true }
              if loadingKeys, strLine.contains("end") { loadingKeys = false }
            }
            // %flag_disp_partial_match
            if strLine == "%flag_disp_partial_match" {
              supplyPartiallyMatchedResults = true
              supplyQuickResults = true
            }
            // %quick
            if strLine.starts(with: "%quick") {
              supplyQuickResults = true
              if !loadingQuickSets, strLine.contains("begin") {
                loadingQuickSets = true
              }
              if loadingQuickSets, strLine.contains("end") {
                loadingQuickSets = false
                if quickDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
              }
            }
            // %chardef
            if strLine.starts(with: "%chardef") {
              if !loadingCharDefinitions, strLine.contains("begin") {
                loadingCharDefinitions = true
              }
              if loadingCharDefinitions, strLine.contains("end") {
                loadingCharDefinitions = false
                if charDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
              }
            }
            // %symboldef
            if strLine.starts(with: "%symboldef") {
              if !loadingSymbolDefinitions, strLine.contains("begin") {
                loadingSymbolDefinitions = true
              }
              if loadingSymbolDefinitions, strLine.contains("end") {
                loadingSymbolDefinitions = false
                if symbolDefMap.keys.contains(wildcardKey) { wildcardKey = "" }
              }
            }
            // %octagram
            if strLine.starts(with: "%octagram") {
              if !loadingOctagramData, strLine.contains("begin") {
                loadingOctagramData = true
              }
              if loadingOctagramData, strLine.contains("end") {
                loadingOctagramData = false
              }
            }
            // Start data parsing.
            let cells: [String.SubSequence] =
              strLine.contains("\t") ? strLine.split(separator: "\t") : strLine.split(separator: " ")
            guard cells.count >= 2 else { continue }
            let strFirstCell = cells[0].trimmingCharacters(in: .newlines)
            let strSecondCell = cells[1].trimmingCharacters(in: .newlines)
            if loadingKeys, !cells[0].starts(with: "%keyname") {
              keyNameMap[strFirstCell] = cells[1].trimmingCharacters(in: .newlines)
            } else if loadingQuickSets, !strLine.starts(with: "%quick") {
              theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
              quickDefMap[strFirstCell, default: .init()].append(strSecondCell)
            } else if loadingCharDefinitions, !loadingSymbolDefinitions,
                      !strLine.starts(with: "%chardef"), !strLine.starts(with: "%symboldef")
            {
              theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
              charDefMap[strFirstCell, default: []].append(strSecondCell)
              if strFirstCell.count > 1 {
                strFirstCell.map(\.description).forEach { keyChar in
                  keysUsedInCharDef.insert(keyChar.description)
                }
              }
              reverseLookupMap[strSecondCell, default: []].append(strFirstCell)
              var keyComps = strFirstCell.map(\.description)
              while !keyComps.isEmpty {
                keyComps.removeLast()
                charDefWildcardMap[keyComps.joined() + wildcard, default: []].append(strSecondCell)
              }
            } else if loadingSymbolDefinitions, !strLine.starts(with: "%chardef"), !strLine.starts(with: "%symboldef") {
              theMaxKeyLength = max(theMaxKeyLength, cells[0].count)
              symbolDefMap[strFirstCell, default: []].append(strSecondCell)
              reverseLookupMap[strSecondCell, default: []].append(strFirstCell)
            } else if loadingOctagramData, !strLine.starts(with: "%octagram") {
              guard let countValue = Int(cells[1]) else { continue }
              switch cells.count {
              case 2: octagramMap[strFirstCell] = countValue
              case 3: octagramDividedMap[strFirstCell] = (countValue, cells[2].trimmingCharacters(in: .newlines))
              default: break
              }
              norm += Self.fscale ** (Double(cells[0].count) / 3.0 - 1.0) * Double(countValue)
            }
            guard !loadingKeys, !loadingQuickSets, !loadingCharDefinitions, !loadingOctagramData else { continue }
            if nameENG.isEmpty, strLine.starts(with: "%ename ") {
              for neta in cells[1].components(separatedBy: ";") {
                let subNetaGroup = neta.components(separatedBy: ":")
                if subNetaGroup.count == 2, subNetaGroup[1].contains("en") {
                  nameENG = String(subNetaGroup[0])
                  break
                }
              }
              if nameENG.isEmpty { nameENG = strSecondCell }
            }
            if nameIntl.isEmpty, strLine.starts(with: "%intlname ") {
              nameIntl = strSecondCell.replacingOccurrences(of: "_", with: " ")
            }
            if nameCJK.isEmpty, strLine.starts(with: "%cname ") { nameCJK = strSecondCell }
            if nameShort.isEmpty, strLine.starts(with: "%sname ") { nameShort = strSecondCell }
            if nullCandidate.isEmpty, strLine.starts(with: "%nullcandidate ") { nullCandidate = strSecondCell }
            if selectionKeys.isEmpty, strLine.starts(with: "%selkey ") {
              selectionKeys = cells[1].map(\.description).deduplicated.joined()
            }
            if endKeys.isEmpty, strLine.starts(with: "%endkey ") {
              endKeys = cells[1].map(\.description).deduplicated
            }
            if wildcardKey.isEmpty, strLine.starts(with: "%wildcardkey ") {
              wildcardKey = cells[1].first?.description ?? ""
            }
            if keysToDirectlyCommit.isEmpty, strLine.starts(with: "%keys_to_directly_commit ") {
              keysToDirectlyCommit = strSecondCell
            }
          }
          // Post process.
          if CandidateKey.validate(keys: selectionKeys) != nil { selectionKeys = "1234567890" }
          if !keysUsedInCharDef.intersection(selectionKeys.map(\.description)).isEmpty {
            areCandidateKeysShiftHeld = true
          }
          maxKeyLength = theMaxKeyLength
          keyNameMap[wildcardKey] = keyNameMap[wildcardKey] ?? "？"
          filePath = path
          return true
        } catch {
          vCLog("CIN Loading Failed: File Access Error.")
        }
      } else {
        vCLog("CIN Loading Failed: File Missing.")
      }
      filePath = oldPath
      return false
    }

    public mutating func clear() {
      filePath = nil
      nullCandidate.removeAll()
      keyNameMap.removeAll()
      quickDefMap.removeAll()
      charDefMap.removeAll()
      charDefWildcardMap.removeAll()
      nameShort.removeAll()
      nameENG.removeAll()
      nameCJK.removeAll()
      selectionKeys.removeAll()
      endKeys.removeAll()
      reverseLookupMap.removeAll()
      octagramMap.removeAll()
      octagramDividedMap.removeAll()
      wildcardKey.removeAll()
      nameIntl.removeAll()
      maxKeyLength = 1
      norm = 0
    }

    public func quickSetsFor(key: String) -> String? {
      guard !key.isEmpty else { return nil }
      var result = [String]()
      if let specifiedResult = quickDefMap[key], !specifiedResult.isEmpty {
        result.append(contentsOf: specifiedResult.map(\.description))
      }
      if supplyQuickResults, result.isEmpty {
        if supplyPartiallyMatchedResults {
          let fetched = charDefMap.compactMap {
            $0.key.starts(with: key) ? $0 : nil
          }.stableSort {
            $0.key.count < $1.key.count
          }.flatMap(\.value).filter {
            $0.count == 1
          }
          result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
        } else {
          let fetched = (charDefMap[key] ?? [String]()).filter { $0.count == 1 }
          result.append(contentsOf: fetched.deduplicated.prefix(selectionKeys.count * 6))
        }
      }
      return result.isEmpty ? nil : result.joined(separator: "\t")
    }

    /// 根據給定的字根索引鍵，來獲取資料庫辭典內的對應結果。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      let arrRaw = charDefMap[key]?.deduplicated ?? []
      var arrRawWildcard: [String] = []
      if let arrRawWildcardValues = charDefWildcardMap[key]?.deduplicated,
         key.contains(wildcard), key.first?.description != wildcard
      {
        arrRawWildcard.append(contentsOf: arrRawWildcardValues)
      }
      var arrResults = [Megrez.Unigram]()
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
        arrResults.append(.init(value: neta, score: theScore))
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
          arrResults.append(.init(value: neta, score: theScore))
        }
      }
      return arrResults
    }

    /// 根據給定的讀音索引鍵來確認資料庫辭典內是否存在對應的資料。
    /// - parameters:
    ///   - key: 讀音索引鍵。
    public func hasUnigramsFor(key: String) -> Bool {
      charDefMap[key] != nil
        || (charDefWildcardMap[key] != nil && key.contains(wildcard) && key.first?.description != wildcard)
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
          Self.fscale ** (Double(phraseLength) / 3.0 - 1.0) * 0.25 / norm)
      default:
        weight = log10(
          Self.fscale ** (Double(phraseLength) / 3.0 - 1.0)
            * Double(theCount) / norm
        )
      }
      return weight
    }
  }
}

// MARK: - 引入冪乘函式

// Ref: https://stackoverflow.com/a/41581695/4162914
precedencegroup ExponentiationPrecedence {
  associativity: right
  higherThan: MultiplicationPrecedence
}

infix operator **: ExponentiationPrecedence

private func ** (_ base: Double, _ exp: Double) -> Double {
  pow(base, exp)
}
