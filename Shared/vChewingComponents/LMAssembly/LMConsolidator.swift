// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public extension vChewingLM {
  enum LMConsolidator {
    public static let kPragmaHeader = "# ๐ต๐พ๐๐ผ๐ฐ๐ ๐๐๐.๐๐๐๐๐๐๐๐ธ๐๐๐.๐๐๐๐๐ ๐๐๐.๐๐๐๐๐ป๐๐๐๐๐๐๐๐ผ๐๐๐๐๐ณ๐๐๐.๐๐๐๐๐๐๐๐๐"

    /// ๆชขๆฅ็ตฆๅฎๆชๆก็ๆจ้ ญๆฏๅฆๆญฃๅธธใ
    /// - Parameter path: ็ตฆๅฎๆชๆก่ทฏๅพใ
    /// - Returns: ็ตๆๆญฃๅธธๅ็บ็๏ผๅถ้ค็บๅใ
    public static func checkPragma(path: String) -> Bool {
      if FileManager.default.fileExists(atPath: path) {
        do {
          guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw FileErrors.fileHandleError("")
          }
          let lineReader = try LineReader(file: fileHandle)
          for strLine in lineReader { // ไธ้่ฆ i=0๏ผๅ ็บ็ฌฌไธ้่ฟดๅๅฐฑๅบ็ตๆใ
            if strLine != kPragmaHeader {
              vCLog("Header Mismatch, Starting In-Place Consolidation.")
              return false
            } else {
              vCLog("Header Verification Succeeded: \(strLine).")
              return true
            }
          }
        } catch {
          vCLog("Header Verification Failed: File Access Error.")
          return false
        }
      }
      vCLog("Header Verification Failed: File Missing.")
      return false
    }

    /// ๆชขๆฅๆชๆกๆฏๅฆไปฅ็ฉบ่ก็ตๅฐพ๏ผๅฆๆ็ผบๅคฑๅ่ฃๅไนใ
    /// - Parameter path: ็ตฆๅฎๆชๆก่ทฏๅพใ
    /// - Returns: ็ตๆๆญฃๅธธๆไฟฎๅพฉ้ ๅฉๅ็บ็๏ผๅถ้ค็บๅใ
    @discardableResult public static func fixEOF(path: String) -> Bool {
      let urlPath = URL(fileURLWithPath: path)
      if FileManager.default.fileExists(atPath: path) {
        var strIncoming = ""
        do {
          strIncoming += try String(contentsOf: urlPath, encoding: .utf8)
          /// ๆณจๆ๏ผSwift ็ LMConsolidator ไธฆๆชๅจๆญคๅฎๆๅฐ EOF ็ๅป้่คๅทฅๅบใ
          /// ไฝ้ๅๅฝๅผๅท่กๅฎไนๅพๅพๅพๅฐฑๆ consolidate() ๆด็ๆ ผๅผ๏ผๆไปฅไธๆๆๅทฎใ
          if !strIncoming.hasSuffix("\n") {
            vCLog("EOF Fix Necessity Confirmed, Start Fixing.")
            if let writeFile = FileHandle(forUpdatingAtPath: path),
               let endl = "\n".data(using: .utf8)
            {
              writeFile.seekToEndOfFile()
              writeFile.write(endl)
              writeFile.closeFile()
            } else {
              return false
            }
          }
        } catch {
          vCLog("EOF Fix Failed w/ File: \(path)")
          vCLog("EOF Fix Failed w/ Error: \(error).")
          return false
        }
        vCLog("EOF Successfully Ensured (with possible autofixes performed).")
        return true
      }
      vCLog("EOF Fix Failed: File Missing at \(path).")
      return false
    }

    /// ็ตฑๆด็ตฆๅฎ็ๅญไธฒใ
    /// - Parameters:
    ///   - text: ๆไฝๅฐ่ฑกใ
    ///   - shouldCheckPragma: ๆฏๅฆๅจๆชๆกๆจ้ ญๅฎๅฅฝ็กๆ็ๆๆณไธ็ฅ้ๅฐๆ ผๅผ็ๆด็ใ
    public static func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool) {
      var pragmaResult: Bool {
        let realPragmaHeader = kPragmaHeader + "\n"
        if strProcessed.count <= kPragmaHeader.count { return false }
        let range = 0 ..< (realPragmaHeader.count)
        let fetchedPragma = ContiguousArray(strProcessed.utf8CString[range])
        return fetchedPragma == realPragmaHeader.utf8CString
      }

      if shouldCheckPragma, pragmaResult { return }

      // Step 1: Consolidating formats per line.
      // -------
      // CJKWhiteSpace (\x{3000}) to ASCII Space
      // NonBreakWhiteSpace (\x{A0}) to ASCII Space
      // Tab to ASCII Space
      // ็ตฑๆด้ฃ็บ็ฉบๆ ผ็บไธๅ ASCII ็ฉบๆ ผ
      strProcessed.regReplace(pattern: #"(ย +|ใ+| +|\t+)+"#, replaceWith: " ")
      // ๅป้ค่กๅฐพ่ก้ฆ็ฉบๆ ผ
      strProcessed.regReplace(pattern: #"(^ | $)"#, replaceWith: "")
      strProcessed.regReplace(pattern: #"(\n | \n)"#, replaceWith: "\n")
      // CR & FF to LF, ไธๅป้ค้่ค่ก
      strProcessed.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")
      strProcessed.regReplace(pattern: "^\(kPragmaHeader)$", replaceWith: "")
      if strProcessed.prefix(1) == " " { // ๅป้คๆชๆก้้ ญ็ฉบๆ ผ
        strProcessed.removeFirst()
      }
      if strProcessed.suffix(1) == " " { // ๅป้คๆชๆก็ตๅฐพ็ฉบๆ ผ
        strProcessed.removeLast()
      }

      // Step 3: Deduplication.
      let arrData = strProcessed.split(separator: "\n")
      // ไธ้ขๅฉ่ก็ reversed ๆฏ้ฆๅฐพ้กๅ๏ผๅๅพ็ ดๅฃๆๆฐ็ override ่ณ่จใ
      let arrDataDeduplicated = Array(NSOrderedSet(array: arrData.reversed()).array as! [String])
      strProcessed = arrDataDeduplicated.reversed().joined(separator: "\n") + "\n"

      // Step 4: Remove duplicated newlines at the end of the file.
      strProcessed.regReplace(pattern: #"\n+"#, replaceWith: "\n")

      // Step 5: Add pragma header back.
      strProcessed = kPragmaHeader + "\n" + strProcessed // Add Pragma Header
    }

    /// ็ตฑๆด็ตฆๅฎ็ๆชๆก็ๆ ผๅผใ
    /// - Parameters:
    ///   - path: ็ตฆๅฎๆชๆก่ทฏๅพใ
    ///   - shouldCheckPragma: ๆฏๅฆๅจๆชๆกๆจ้ ญๅฎๅฅฝ็กๆ็ๆๆณไธ็ฅ้ๅฐๆ ผๅผ็ๆด็ใ
    /// - Returns: ่ฅๆด็้ ๅฉๆ็ก้ ๆด็๏ผๅ็บ็๏ผๅไน็บๅใ
    @discardableResult public static func consolidate(path: String, pragma shouldCheckPragma: Bool) -> Bool {
      let pragmaResult = checkPragma(path: path)
      if shouldCheckPragma {
        if pragmaResult {
          return true
        }
      }

      let urlPath = URL(fileURLWithPath: path)
      if FileManager.default.fileExists(atPath: path) {
        do {
          var strProcessed = try String(contentsOf: urlPath, encoding: .utf8)
          consolidate(text: &strProcessed, pragma: shouldCheckPragma)
          // Write consolidated file contents.
          try strProcessed.write(to: urlPath, atomically: false, encoding: .utf8)
        } catch {
          vCLog("Consolidation Failed w/ File: \(path), error: \(error)")
          return false
        }
        vCLog("Either Consolidation Successful Or No-Need-To-Consolidate.")
        return true
      }
      vCLog("Consolidation Failed: File Missing at \(path).")
      return false
    }
  }
}
