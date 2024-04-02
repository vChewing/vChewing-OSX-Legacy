// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

extension LMAssembly {
  struct LMReplacements {
    public private(set) var filePath: String?
    var rangeMap: [String: Range<String.Index>] = [:]
    var strData: String = ""

    public var count: Int { rangeMap.count }

    public init() {
      rangeMap = [:]
    }

    public var isLoaded: Bool { !rangeMap.isEmpty }

    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded { return false }
      let oldPath = filePath
      filePath = nil

      LMConsolidator.fixEOF(path: path)
      LMConsolidator.consolidate(path: path, pragma: true)

      do {
        let rawStrData = try String(contentsOfFile: path, encoding: .utf8)
        replaceData(textData: rawStrData)
      } catch {
        filePath = oldPath
        vCLMLog("\(error)")
        vCLMLog("↑ Exception happened when reading data at: \(path).")
        return false
      }

      filePath = path
      return true
    }

    /// 將資料從檔案讀入至資料庫辭典內。
    /// - parameters:
    ///   - path: 給定路徑。
    public mutating func replaceData(textData rawStrData: String) {
      if strData == rawStrData { return }
      strData = rawStrData
      var newMap: [String: Range<String.Index>] = [:]
      strData.parse(splitee: "\n") { theRange in
        let theCells = rawStrData[theRange].split(separator: " ")
        if theCells.count < 2 { return }
        let theKey = theCells[0].description
        if theKey.first != "#" { newMap[theKey] = theRange }
      }
      rangeMap = newMap
      newMap.removeAll()
    }

    public mutating func clear() {
      filePath = nil
      strData.removeAll()
      rangeMap.removeAll()
    }

    public func saveData() {
      guard let filePath = filePath else { return }
      do {
        try strData.write(toFile: filePath, atomically: true, encoding: .utf8)
      } catch {
        vCLMLog("Failed to save current database to: \(filePath)")
      }
    }

    public func dump() {
      var strDump = ""
      for entry in rangeMap {
        strDump += strData[entry.value] + "\n"
      }
      vCLMLog(strDump)
    }

    public func valuesFor(key: String) -> String {
      guard let range = rangeMap[key] else {
        return ""
      }
      let arrNeta = strData[range].split(separator: " ")
      guard arrNeta.count >= 2 else {
        return ""
      }
      return String(arrNeta[1])
    }

    public func hasValuesFor(key: String) -> Bool {
      rangeMap[key] != nil
    }
  }
}

extension LMAssembly.LMReplacements {
  var dictRepresented: [String: String] {
    var result = [String: String]()
    rangeMap.forEach { key, valueRange in
      result[key] = strData[valueRange].description
    }
    return result
  }
}
