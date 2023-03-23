// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// MARK: - Implements Conforming to Phrase Editor Delegate Protocol

extension LMMgr: PhraseEditorDelegate {
  public var currentInputMode: Shared.InputMode { IMEApp.currentInputMode }

  public func openPhraseFile(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, app: String) {
    Self.openPhraseFile(fromURL: Self.userDictDataURL(mode: mode, type: type), app: app)
  }

  public func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool) {
    vChewingLM.LMConsolidator.consolidate(text: &strProcessed, pragma: shouldCheckPragma)
  }

  public func checkIfPhrasePairExists(userPhrase: String, mode: Shared.InputMode, key unigramKey: String) -> Bool {
    Self.checkIfPhrasePairExists(userPhrase: userPhrase, mode: mode, keyArray: [unigramKey])
  }

  public func retrieveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType) -> String {
    Self.retrieveData(mode: mode, type: type)
  }

  public static func retrieveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType) -> String {
    vCLog("Retrieving data. Mode: \(mode.localizedDescription), type: \(type.localizedDescription)")
    let theURL = Self.userDictDataURL(mode: mode, type: type)
    do {
      return try .init(contentsOf: theURL, encoding: .utf8)
    } catch {
      vCLog("Error reading: \(theURL.absoluteString)")
      return ""
    }
  }

  public func saveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, data: String) -> String {
    Self.saveData(mode: mode, type: type, data: data)
  }

  @discardableResult public static func saveData(
    mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, data: String
  ) -> String {
    DispatchQueue.main.async {
      let theURL = Self.userDictDataURL(mode: mode, type: type)
      do {
        try data.write(to: theURL, atomically: true, encoding: .utf8)
        Self.loadUserPhrasesData(type: type)
      } catch {
        vCLog("Failed to save current database to: \(theURL.absoluteString)")
      }
    }
    return data
  }

  public func tagOverrides(in strProcessed: inout String, mode: Shared.InputMode) {
    let outputStack: NSMutableString = .init()
    switch mode {
    case .imeModeCHT:
      if !Self.lmCHT.isCoreLMLoaded {
        Notifier.notify(
          message: NSLocalizedString("Loading CHT Core Dict...", comment: "")
        )
        Self.loadCoreLanguageModelFile(
          filenameSansExtension: "data-cht", langModel: Self.lmCHT
        )
        Notifier.notify(
          message: NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      }
    case .imeModeCHS:
      if !Self.lmCHS.isCoreLMLoaded {
        Notifier.notify(
          message: NSLocalizedString("Loading CHS Core Dict...", comment: "")
        )
        Self.loadCoreLanguageModelFile(
          filenameSansExtension: "data-chs", langModel: Self.lmCHS
        )
        Notifier.notify(
          message: NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      }
    case .imeModeNULL: return
    }
    for currentLine in strProcessed.split(separator: "\n") {
      let arr = currentLine.split(separator: " ")
      guard arr.count >= 2 else { continue }
      let exists = Self.checkIfPhrasePairExists(
        userPhrase: arr[0].description, mode: mode,
        keyArray: arr[1].split(separator: "-").map(\.description),
        factoryDictionaryOnly: true
      )
      outputStack.append(currentLine.description)
      let replace = !currentLine.contains(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎") && exists
      if replace { outputStack.append(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎") }
      outputStack.append("\n")
    }
    strProcessed = outputStack.description
  }
}
