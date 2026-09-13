// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - SettingsUIHost 動作依賴注入

extension SettingsUIHost {
  /// 由宿主於啟動時呼叫，將 SettingsUI 所需的宿主服務
  /// （LXMgr、SessionUI、AppDelegate、InputSession）注入。
  ///
  /// 註：與 vChewing-macOS 不同，legacy 的 `PrefMgr.shared` 仍在
  /// `PrefMgr_Singleton.swift` 內於宣告時即完成全部 didSet 回呼掛載，
  /// 故此處無需（也不得）重複掛載。
  public static func wireUp() {
    let host = SettingsUIHost.shared
    // LXMgr 動作依賴。
    host.dataFolderPath = { LXMgr.dataFolderPath(isDefaultFolder: $0) }
    host.cassettePath = { LXMgr.cassettePath() }
    host.cassetteAccessFailureDescription = { LXMgr.cassetteAccessFailureDescription(path: $0) }
    host.checkCassettePathValidity = { LXMgr.checkCassettePathValidity($0) }
    host.checkIfSpecifiedUserDataFolderValid = { LXMgr.checkIfSpecifiedUserDataFolderValid($0) }
    host.resolveUserSpecifiedURL = { LXMgr.resolveUserSpecifiedURL($0) }
    host.chkUserLMFilesExist = { LXMgr.chkUserLMFilesExist($0) }
    host.initUserLexicons = { LXMgr.initUserLexicons() }
    host.connectCoreDB = { LXMgr.connectCoreDB() }
    host.syncLMPrefs = { LXMgr.syncLMPrefs() }
    host.loadUserPhraseReplacement = { LXMgr.loadUserPhraseReplacement() }
    host.loadCassetteData = { LXMgr.loadCassetteData() }
    host.resetCassettePath = { LXMgr.resetCassettePath() }
    host.resetSpecifiedUserDataFolder = { LXMgr.resetSpecifiedUserDataFolder() }
    host.importCassetteFileToCache = { LXMgr.importCassetteFileToCache(from: $0) }
    host.migrateUserDataFrom = { LXMgr.migrateUserDataFrom(oldPath: $0, to: $1) }
    host.importYahooKeyKeyUserDictionary = { url in
      try LXMgr.importYahooKeyKeyUserDictionary(url: url)
    }
    host.retrieveData = { LXMgr.retrieveData(mode: $0, type: $1) }
    host.saveData = { LXMgr.saveData(mode: $0, type: $1, data: $2) }
    host.tagOverrides = { text, mode in
      LXMgr.shared.tagOverrides(in: &text, mode: mode)
    }
    host.openPhraseFile = { mode, type, app in
      LXMgr.shared.openPhraseFile(mode: mode, type: type, using: app)
    }
    // 以 provider 延遲注入：LXMgr.shared 僅在詞彙編輯頁真正開啟時才實體化，
    // 避免程序啟動階段就武裝其 KVO 路徑失效觀察器。
    host.phraseEditorDelegateProvider = { LXMgr.shared }
    // SessionUI / AppDelegate / InputSession 動作依賴。
    host.resyncShiftKeyUpCheckerSettings = { SessionUI.shared.resyncShiftKeyUpCheckerSettings() }
    host.updateDirectoryMonitorPath = { AppDelegate.shared.updateDirectoryMonitorPath() }
    host.recentClientBundleIdentifiers = { InputSession.recentClientBundleIdentifiers }
    // Notifier 動作依賴。
    host.notify = { Notifier.notify(message: $0) }
  }
}
