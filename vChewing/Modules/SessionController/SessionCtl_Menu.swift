// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - IME Menu Manager

// 因為選單部分的內容又臭又長，所以就單獨拉到一個檔案內管理了。

extension SessionCtl {
  var optionKeyPressed: Bool { NSEvent.keyModifierFlags.contains(.option) }
  var silentMode: Bool { clientBundleIdentifier == "com.apple.SecurityAgent" }

  var currentRAMUsageDescription: String? {
    guard PrefMgr.shared.isDebugModeEnabled else { return nil }
    guard let currentMemorySizeInBytes = NSApplication.memoryFootprint else { return nil }
    let currentMemorySize: Double = (Double(currentMemorySizeInBytes) / 1024 / 1024).rounded(toPlaces: 1)
    return "Total RAM Usage: \(currentMemorySize)MB"
  }

  override public func menu() -> NSMenu {
    .init().appendItems(self) {
      NSMenu.Item(verbatim: currentRAMUsageDescription)
      NSMenu.Item(
        verbatim: String(
          format: "Switch to %@ Input Mode".localized,
          IMEApp.currentInputMode.reversed.localizedDescription
        )
      )?.act(#selector(switchInputMode(_:)))
        .hotkey(PrefMgr.shared.usingHotKeyInputMode ? "D" : "", mask: [.command, .control])
      NSMenu.Item("Per-Char Select Mode")?
        .act(#selector(toggleSCPCTypingMode(_:)))
        .state(PrefMgr.shared.useSCPCTypingMode)
        .hotkey(PrefMgr.shared.usingHotKeySCPC ? "P" : "", mask: [.command, .control])
      NSMenu.Item("Associated Phrases")?
        .act(#selector(toggleAssociatedPhrasesEnabled(_:)))
        .state(PrefMgr.shared.associatedPhrasesEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyAssociates ? "O" : "", mask: [.command, .control])
      NSMenu.Item("CIN Cassette Mode")?
        .act(#selector(toggleCassetteMode(_:)))
        .state(PrefMgr.shared.cassetteEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCassette ? "I" : "", mask: [.command, .control])
      NSMenu.Item("CNS11643 Mode")?
        .act(#selector(toggleCNS11643Enabled(_:)))
        .state(PrefMgr.shared.cns11643Enabled)
        .hotkey(PrefMgr.shared.usingHotKeyCNS ? "L" : "", mask: [.command, .control])
      NSMenu.Item("Force KangXi Writing")?
        .act(#selector(toggleChineseConverter(_:)))
        .state(PrefMgr.shared.chineseConversionEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyKangXi ? "K" : "", mask: [.command, .control])
        .nulled(IMEApp.currentInputMode != .imeModeCHT)
      NSMenu.Item("JIS Shinjitai Output")?
        .act(#selector(toggleShiftJISShinjitaiOutput(_:)))
        .state(PrefMgr.shared.shiftJISShinjitaiOutputEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyJIS ? "J" : "", mask: [.command, .control])
        .nulled(IMEApp.currentInputMode != .imeModeCHT)
      NSMenu.Item("Currency Numeral Output")?
        .act(#selector(toggleCurrencyNumerals(_:)))
        .state(PrefMgr.shared.currencyNumeralsEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyCurrencyNumerals ? "M" : "", mask: [.command, .control])
      NSMenu.Item("Half-Width Punctuation Mode")?
        .act(#selector(toggleHalfWidthPunctuation(_:)))
        .state(PrefMgr.shared.halfWidthPunctuationEnabled)
        .hotkey(PrefMgr.shared.usingHotKeyHalfWidthASCII ? "H" : "", mask: [.command, .control])
      NSMenu.Item("Use Phrase Replacement")?
        .act(#selector(togglePhraseReplacement(_:)))
        .state(PrefMgr.shared.phraseReplacementEnabled)
        .nulled(!optionKeyPressed && !PrefMgr.shared.phraseReplacementEnabled)
      NSMenu.Item("Symbol & Emoji Input")?
        .act(#selector(toggleSymbolEnabled(_:)))
        .state(PrefMgr.shared.symbolInputEnabled)
        .nulled(!optionKeyPressed)

      NSMenu.Item.separator() // ---------------------
      NSMenu.Item("Open User Dictionary Folder")?.act(#selector(openUserDataFolder(_:))).nulled(silentMode)
      NSMenu.Item("Edit vChewing User Phrases…")?.act(#selector(openUserPhrases(_:))).nulled(silentMode)
      NSMenu.Item("Edit Excluded Phrases…")?.act(#selector(openExcludedPhrases(_:))).nulled(silentMode)
      NSMenu.Item("Edit Associated Phrases…")?.act(#selector(openAssociatedPhrases(_:))).nulled(
        !(!silentMode && (optionKeyPressed || PrefMgr.shared.associatedPhrasesEnabled))
      )
      NSMenu.Item("Edit Phrase Replacement Table…")?.act(#selector(openPhraseReplacement(_:))).nulled(silentMode || !optionKeyPressed)
      NSMenu.Item("Edit User Symbol & Emoji Data…")?.act(#selector(openUserSymbols(_:))).nulled(silentMode || !optionKeyPressed)
      NSMenu.Item("Open App Support Folder")?.act(#selector(openAppSupportFolderFromContainer(_:))).nulled(silentMode || !optionKeyPressed)

      NSMenu.Item("Reload User Phrases")?.act(#selector(reloadUserPhrasesData(_:))).nulled(PrefMgr.shared.shouldAutoReloadUserDataFiles && !optionKeyPressed)
      NSMenu.Item(verbatim: "Reverse Lookup (Phonabets)".localized.withEllipsis)?
        .act(#selector(callReverseLookupWindow(_:))).hotkey(PrefMgr.shared.usingHotKeyRevLookup ? "/" : "", mask: [.command, .control])

      NSMenu.Item("Optimize Memorized Phrases")?.act(#selector(removeUnigramsFromUOM(_:)))
      NSMenu.Item("Clear Memorized Phrases")?.act(#selector(clearUOM(_:)))

      NSMenu.Item.separator() // ---------------------
      NSMenu.Item("vChewing Preferences…")?.act(#selector(showPreferences(_:))).nulled(silentMode)
      NSMenu.Item(verbatim: "Client Manager".localized.withEllipsis)?.act(#selector(showClientListMgr(_:))).nulled(silentMode)
      NSMenu.Item("Check for Updates…")?.act(#selector(checkForUpdate(_:))).nulled(silentMode)
      NSMenu.Item("Reboot vChewing…")?.act(#selector(selfTerminate(_:)))
      NSMenu.Item("About vChewing…")?.act(#selector(showAbout(_:))).nulled(silentMode)
      NSMenu.Item("CheatSheet")?.act(#selector(showCheatSheet(_:))).nulled(silentMode)
      NSMenu.Item("Uninstall vChewing…")?.act(#selector(selfUninstall(_:))).nulled(silentMode || !optionKeyPressed)
    }
  }
}

// MARK: - IME Menu Items

public extension SessionCtl {
  @objc override func showPreferences(_: Any? = nil) {
    CtlSettingsCocoa.show()
    NSApp.popup()
  }

  @objc func showCheatSheet(_: Any? = nil) {
    guard let url = Bundle.main.url(forResource: "shortcuts", withExtension: "html") else { return }
    FileOpenMethod.safari.open(url: url)
  }

  @objc func showClientListMgr(_: Any? = nil) {
    CtlClientListMgr.show()
    NSApp.popup()
  }

  @objc func toggleCassetteMode(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    if !PrefMgr.shared.cassetteEnabled, !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
      DispatchQueue.main.async {
        IMEApp.buzz()
        let alert = NSAlert(error: "Path invalid or file access error.".localized)
        let informativeText = "Please reconfigure the cassette path to a valid one before enabling this mode."
        alert.informativeText = informativeText.localized
        let result = alert.runModal()
        NSApp.popup()
        if result == NSApplication.ModalResponse.alertFirstButtonReturn {
          LMMgr.resetCassettePath()
          PrefMgr.shared.cassetteEnabled = false
        }
      }
      return
    }
    Notifier.notify(
      message: "CIN Cassette Mode".localized + "\n"
        + (PrefMgr.shared.cassetteEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
    if !inputMode.langModel.isCassetteDataLoaded {
      LMMgr.loadCassetteData()
    }
  }

  @objc func toggleSCPCTypingMode(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Per-Char Select Mode".localized + "\n"
        + (PrefMgr.shared.useSCPCTypingMode.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func toggleChineseConverter(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Force KangXi Writing".localized + "\n"
        + (PrefMgr.shared.chineseConversionEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func toggleShiftJISShinjitaiOutput(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "JIS Shinjitai Output".localized + "\n"
        + (PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func toggleCurrencyNumerals(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Currency Numeral Output".localized + "\n"
        + (PrefMgr.shared.currencyNumeralsEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func toggleHalfWidthPunctuation(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Half-Width Punctuation Mode".localized + "\n"
        + (PrefMgr.shared.halfWidthPunctuationEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func toggleCNS11643Enabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "CNS11643 Mode".localized + "\n"
        + (PrefMgr.shared.cns11643Enabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func toggleSymbolEnabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Symbol & Emoji Input".localized + "\n"
        + (PrefMgr.shared.symbolInputEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func toggleAssociatedPhrasesEnabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Associated Phrases".localized + "\n"
        + (PrefMgr.shared.associatedPhrasesEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func togglePhraseReplacement(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: "Use Phrase Replacement".localized + "\n"
        + (PrefMgr.shared.phraseReplacementEnabled.toggled()
          ? "NotificationSwitchON".localized
          : "NotificationSwitchOFF".localized)
    )
  }

  @objc func selfUninstall(_: Any? = nil) {
    AppDelegate.shared.selfUninstall()
  }

  @objc func selfTerminate(_: Any? = nil) {
    NSApp.popup()
    NSApp.terminate(nil)
  }

  @objc func checkForUpdate(_: Any? = nil) {
    AppDelegate.shared.checkUpdate(forced: true) { [weak self] in
      self?.clientBundleIdentifier == "com.apple.SecurityAgent"
    }
  }

  @objc func openUserDataFolder(_: Any? = nil) {
    guard LMMgr.userDataFolderExists else { return }
    let url = URL(fileURLWithPath: LMMgr.dataFolderPath(isDefaultFolder: false))
    FileOpenMethod.finder.open(url: url)
  }

  @objc func openAppSupportFolderFromContainer(_: Any? = nil) {
    FileOpenMethod.finder.open(url: LMMgr.appSupportURL)
  }

  @objc func openUserPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .thePhrases, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc func openExcludedPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theFilter, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc func openUserSymbols(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theSymbols, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc func openPhraseReplacement(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theReplacements, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc func openAssociatedPhrases(_: Any? = nil) {
    LMMgr.openUserDictFile(type: .theAssociates, dual: optionKeyPressed, alt: optionKeyPressed)
  }

  @objc func reloadUserPhrasesData(_: Any? = nil) {
    LMMgr.initUserLangModels()
  }

  @objc func callReverseLookupWindow(_: Any? = nil) {
    CtlRevLookupWindow.show()
  }

  @objc func removeUnigramsFromUOM(_: Any? = nil) {
    LMMgr.removeUnigramsFromUserOverrideModel(IMEApp.currentInputMode)
    LMMgr.removeUnigramsFromUserOverrideModel(IMEApp.currentInputMode.reversed)
  }

  @objc func clearUOM(_: Any? = nil) {
    LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode)
    LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode.reversed)
  }

  @objc func showAbout(_: Any? = nil) {
    CtlAboutWindow.show()
    NSApp.popup()
  }
}
