// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - SettingsUIHost 動作依賴注入

extension SettingsUIHost {
  /// 由宿主於啟動時呼叫，將 SettingsUI 所需的宿主服務
  /// （LMMgr、SessionUI、AppDelegate、InputSession）注入。
  ///
  /// 註：與 vChewing-macOS 不同，legacy 的 `PrefMgr.shared` 仍在
  /// `PrefMgr_Singleton.swift` 內於宣告時即完成全部 didSet 回呼掛載，
  /// 故此處無需（也不得）重複掛載。
  public static func wireUp() {
    let host = SettingsUIHost.shared
    // LMMgr 動作依賴。
    host.dataFolderPath = { LMMgr.dataFolderPath(isDefaultFolder: $0) }
    host.cassettePath = { LMMgr.cassettePath() }
    host.cassetteAccessFailureDescription = { LMMgr.cassetteAccessFailureDescription(path: $0) }
    host.checkCassettePathValidity = { LMMgr.checkCassettePathValidity($0) }
    host.checkIfSpecifiedUserDataFolderValid = { LMMgr.checkIfSpecifiedUserDataFolderValid($0) }
    host.resolveUserSpecifiedURL = { LMMgr.resolveUserSpecifiedURL($0) }
    host.chkUserLMFilesExist = { LMMgr.chkUserLMFilesExist($0) }
    host.initUserLangModels = { LMMgr.initUserLangModels() }
    host.connectCoreDB = { LMMgr.connectCoreDB() }
    host.syncLMPrefs = { LMMgr.syncLMPrefs() }
    host.loadUserPhraseReplacement = { LMMgr.loadUserPhraseReplacement() }
    host.loadCassetteData = { LMMgr.loadCassetteData() }
    host.resetCassettePath = { LMMgr.resetCassettePath() }
    host.resetSpecifiedUserDataFolder = { LMMgr.resetSpecifiedUserDataFolder() }
    host.importCassetteFileToCache = { LMMgr.importCassetteFileToCache(from: $0) }
    host.migrateUserDataFrom = { LMMgr.migrateUserDataFrom(oldPath: $0, to: $1) }
    host.importYahooKeyKeyUserDictionary = { url in
      try LMMgr.importYahooKeyKeyUserDictionary(url: url)
    }
    host.retrieveData = { LMMgr.retrieveData(mode: $0, type: $1) }
    host.saveData = { LMMgr.saveData(mode: $0, type: $1, data: $2) }
    host.tagOverrides = { text, mode in
      LMMgr.shared.tagOverrides(in: &text, mode: mode)
    }
    host.openPhraseFile = { mode, type, app in
      LMMgr.shared.openPhraseFile(mode: mode, type: type, using: app)
    }
    host.phraseEditorDelegate = LMMgr.shared
    // SessionUI / AppDelegate / InputSession 動作依賴。
    host.resyncShiftKeyUpCheckerSettings = { SessionUI.shared.resyncShiftKeyUpCheckerSettings() }
    host.updateDirectoryMonitorPath = { AppDelegate.shared.updateDirectoryMonitorPath() }
    host.recentClientBundleIdentifiers = { InputSession.recentClientBundleIdentifiers }
    // Notifier 動作依賴。
    host.notify = { Notifier.notify(message: $0) }
  }
}
