// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public extension vChewingLM {
  @frozen struct LMRevLookup {
    public private(set) var dataMap: [String: [String]] = [:]
    public private(set) var filePath: String = ""

    public init(data dictData: (dict: [String: [String]]?, path: String)) {
      guard let theDict = dictData.dict else {
        vCLog("↑ Exception happened when reading JSON file at: \(dictData.path).")
        return
      }
      filePath = dictData.path
      dataMap = theDict
    }

    public init(path: String) {
      if path.isEmpty { return }
      do {
        let rawData = try Data(contentsOf: URL(fileURLWithPath: path))
        if let rawJSON = try? JSONSerialization.jsonObject(with: rawData) as? [String: [String]] {
          dataMap = rawJSON
        } else {
          vCLog("↑ Exception happened when reading JSON file at: \(path).")
          return
        }
      } catch {
        vCLog("↑ Exception happened when reading JSON file at: \(path).")
        return
      }
      filePath = path
    }

    public func query(with kanji: String) -> [String]? {
      guard let resultData = dataMap[kanji] else { return nil }
      let resultArray = resultData.compactMap {
        let result = restorePhonabetFromASCII($0)
        return result.isEmpty ? nil : result
      }
      return resultArray.isEmpty ? nil : resultArray
    }

    /// 內部函式，用以將被加密的注音讀音索引鍵進行解密。
    ///
    /// 如果傳入的字串當中包含 ASCII 下畫線符號的話，則表明該字串並非注音讀音字串，會被忽略處理。
    /// - parameters:
    ///   - incoming: 傳入的已加密注音讀音字串。
    func restorePhonabetFromASCII(_ incoming: String) -> String {
      var strOutput = incoming
      if !strOutput.contains("_") {
        for entry in Self.dicPhonabet4ASCII {
          strOutput = strOutput.replacingOccurrences(of: entry.key, with: entry.value)
        }
      }
      return strOutput
    }

    // MARK: - Constants

    static let dicPhonabet4ASCII: [String: String] = [
      "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ", "n": "ㄋ", "l": "ㄌ", "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
      "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "Z": "ㄓ", "C": "ㄔ", "S": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ", "s": "ㄙ", "i": "ㄧ",
      "u": "ㄨ", "v": "ㄩ", "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "E": "ㄝ", "B": "ㄞ", "P": "ㄟ", "M": "ㄠ", "F": "ㄡ", "D": "ㄢ",
      "T": "ㄣ", "N": "ㄤ", "L": "ㄥ", "R": "ㄦ", "2": "ˊ", "3": "ˇ", "4": "ˋ", "5": "˙",
    ]
  }
}
