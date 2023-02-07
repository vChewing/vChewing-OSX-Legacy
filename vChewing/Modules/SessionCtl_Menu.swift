// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

private extension Bool {
  var state: NSControl.StateValue {
    self ? .on : .off
  }
}

// MARK: - IME Menu Manager

// 因為選單部分的內容又臭又長，所以就單獨拉到一個檔案內管理了。

extension SessionCtl {
  var optionKeyPressed: Bool { NSEvent.modifierFlags.contains(.option) }

  override public func menu() -> NSMenu! {
    let menu = NSMenu(title: "Input Method Menu")

    let useSCPCTypingModeItem = menu.addItem(
      withTitle: NSLocalizedString("Per-Char Select Mode", comment: ""),
      action: #selector(toggleSCPCTypingMode(_:)), keyEquivalent: PrefMgr.shared.usingHotKeySCPC ? "P" : ""
    )
    useSCPCTypingModeItem.keyEquivalentModifierMask = [.command, .control]
    useSCPCTypingModeItem.state = PrefMgr.shared.useSCPCTypingMode.state

    let userAssociatedPhrasesItem = menu.addItem(
      withTitle: NSLocalizedString("Per-Char Associated Phrases", comment: ""),
      action: #selector(toggleAssociatedPhrasesEnabled(_:)),
      keyEquivalent: PrefMgr.shared.usingHotKeyAssociates ? "O" : ""
    )
    userAssociatedPhrasesItem.keyEquivalentModifierMask = [.command, .control]
    userAssociatedPhrasesItem.state = PrefMgr.shared.associatedPhrasesEnabled.state

    if #available(macOS 10.13, *) {
      let cassetteModeItem = menu.addItem(
        withTitle: NSLocalizedString("CIN Cassette Mode", comment: ""),
        action: #selector(toggleCassetteMode(_:)),
        keyEquivalent: PrefMgr.shared.usingHotKeyCassette ? "I" : ""
      )
      cassetteModeItem.keyEquivalentModifierMask = [.command, .control]
      cassetteModeItem.state = PrefMgr.shared.cassetteEnabled.state
    }

    let useCNS11643SupportItem = menu.addItem(
      withTitle: NSLocalizedString("CNS11643 Mode", comment: ""),
      action: #selector(toggleCNS11643Enabled(_:)), keyEquivalent: PrefMgr.shared.usingHotKeyCNS ? "L" : ""
    )
    useCNS11643SupportItem.keyEquivalentModifierMask = [.command, .control]
    useCNS11643SupportItem.state = PrefMgr.shared.cns11643Enabled.state

    if IMEApp.currentInputMode == .imeModeCHT {
      let chineseConversionItem = menu.addItem(
        withTitle: NSLocalizedString("Force KangXi Writing", comment: ""),
        action: #selector(toggleChineseConverter(_:)), keyEquivalent: PrefMgr.shared.usingHotKeyKangXi ? "K" : ""
      )
      chineseConversionItem.keyEquivalentModifierMask = [.command, .control]
      chineseConversionItem.state = PrefMgr.shared.chineseConversionEnabled.state

      let shiftJISConversionItem = menu.addItem(
        withTitle: NSLocalizedString("JIS Shinjitai Output", comment: ""),
        action: #selector(toggleShiftJISShinjitaiOutput(_:)), keyEquivalent: PrefMgr.shared.usingHotKeyJIS ? "J" : ""
      )
      shiftJISConversionItem.keyEquivalentModifierMask = [.command, .control]
      shiftJISConversionItem.state = PrefMgr.shared.shiftJISShinjitaiOutputEnabled.state
    }

    let currencyNumeralsItem = menu.addItem(
      withTitle: NSLocalizedString("Currency Numeral Output", comment: ""),
      action: #selector(toggleCurrencyNumerals(_:)),
      keyEquivalent: PrefMgr.shared.usingHotKeyCurrencyNumerals ? "M" : ""
    )
    currencyNumeralsItem.keyEquivalentModifierMask = [.command, .control]
    currencyNumeralsItem.state = PrefMgr.shared.currencyNumeralsEnabled.state

    let halfWidthPunctuationItem = menu.addItem(
      withTitle: NSLocalizedString("Half-Width Punctuation Mode", comment: ""),
      action: #selector(toggleHalfWidthPunctuation(_:)),
      keyEquivalent: PrefMgr.shared.usingHotKeyHalfWidthASCII ? "H" : ""
    )
    halfWidthPunctuationItem.keyEquivalentModifierMask = [.command, .control]
    halfWidthPunctuationItem.state = PrefMgr.shared.halfWidthPunctuationEnabled.state

    if optionKeyPressed || PrefMgr.shared.phraseReplacementEnabled {
      let phaseReplacementItem = menu.addItem(
        withTitle: NSLocalizedString("Use Phrase Replacement", comment: ""),
        action: #selector(togglePhraseReplacement(_:)), keyEquivalent: ""
      )
      phaseReplacementItem.state = PrefMgr.shared.phraseReplacementEnabled.state
    }

    if optionKeyPressed {
      let toggleSymbolInputItem = menu.addItem(
        withTitle: NSLocalizedString("Symbol & Emoji Input", comment: ""),
        action: #selector(toggleSymbolEnabled(_:)), keyEquivalent: ""
      )
      toggleSymbolInputItem.state = PrefMgr.shared.symbolInputEnabled.state
    }

    menu.addItem(NSMenuItem.separator()) // ---------------------

    menu.addItem(
      withTitle: NSLocalizedString("Open User Dictionary Folder", comment: ""),
      action: #selector(openUserDataFolder(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Edit vChewing User Phrases…", comment: ""),
      action: #selector(openUserPhrases(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Edit Excluded Phrases…", comment: ""),
      action: #selector(openExcludedPhrases(_:)), keyEquivalent: ""
    )

    if optionKeyPressed || PrefMgr.shared.associatedPhrasesEnabled {
      menu.addItem(
        withTitle: NSLocalizedString("Edit Associated Phrases…", comment: ""),
        action: #selector(openAssociatedPhrases(_:)), keyEquivalent: ""
      )
    }

    if optionKeyPressed {
      menu.addItem(
        withTitle: NSLocalizedString("Edit Phrase Replacement Table…", comment: ""),
        action: #selector(openPhraseReplacement(_:)), keyEquivalent: ""
      )
      menu.addItem(
        withTitle: NSLocalizedString("Edit User Symbol & Emoji Data…", comment: ""),
        action: #selector(openUserSymbols(_:)), keyEquivalent: ""
      )
    }

    if optionKeyPressed || !PrefMgr.shared.shouldAutoReloadUserDataFiles {
      menu.addItem(
        withTitle: NSLocalizedString("Reload User Phrases", comment: ""),
        action: #selector(reloadUserPhrasesData(_:)), keyEquivalent: ""
      )
    }

    let revLookupMenuItem = menu.addItem(
      withTitle: "Reverse Lookup (Phonabets)".localized.withEllipsis,
      action: #selector(callReverseLookupWindow(_:)),
      keyEquivalent: PrefMgr.shared.usingHotKeyRevLookup ? "/" : ""
    )
    revLookupMenuItem.keyEquivalentModifierMask = [.command, .control]

    menu.addItem(NSMenuItem.separator()) // ---------------------

    menu.addItem(
      withTitle: NSLocalizedString("Optimize Memorized Phrases", comment: ""),
      action: #selector(removeUnigramsFromUOM(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Clear Memorized Phrases", comment: ""),
      action: #selector(clearUOM(_:)), keyEquivalent: ""
    )

    menu.addItem(NSMenuItem.separator()) // ---------------------

    menu.addItem(
      withTitle: NSLocalizedString("vChewing Preferences…", comment: ""),
      action: #selector(showPreferences(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("Client Manager", comment: "") + "…",
      action: #selector(showClientListMgr(_:)), keyEquivalent: ""
    )
    if !optionKeyPressed {
      menu.addItem(
        withTitle: NSLocalizedString("Check for Updates…", comment: ""),
        action: #selector(checkForUpdate(_:)), keyEquivalent: ""
      )
    }
    menu.addItem(
      withTitle: NSLocalizedString("Reboot vChewing…", comment: ""),
      action: #selector(selfTerminate(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("About vChewing…", comment: ""),
      action: #selector(showAbout(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: NSLocalizedString("CheatSheet", comment: "") + "…",
      action: #selector(showCheatSheet(_:)), keyEquivalent: ""
    )
    if optionKeyPressed {
      menu.addItem(
        withTitle: NSLocalizedString("Uninstall vChewing…", comment: ""),
        action: #selector(selfUninstall(_:)), keyEquivalent: ""
      )
    }

    return menu
  }
}

// MARK: - IME Menu Items

public extension SessionCtl {
  @objc override func showPreferences(_: Any? = nil) {
    CtlPrefWindow.show()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func showCheatSheet(_: Any? = nil) {
    guard let url = Bundle.main.url(forResource: "shortcuts", withExtension: "html") else { return }
    DispatchQueue.main.async {
      NSWorkspace.shared.openFile(url.path, withApplication: "Safari")
    }
  }

  @objc func showClientListMgr(_: Any? = nil) {
    CtlClientListMgr.show()
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func toggleCassetteMode(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    if !PrefMgr.shared.cassetteEnabled, !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
      DispatchQueue.main.async {
        IMEApp.buzz()
        let alert = NSAlert(error: NSLocalizedString("Path invalid or file access error.", comment: ""))
        alert.informativeText = NSLocalizedString(
          "Please reconfigure the cassette path to a valid one before enabling this mode.", comment: ""
        )
        let result = alert.runModal()
        NSApp.activate(ignoringOtherApps: true)
        if result == NSApplication.ModalResponse.alertFirstButtonReturn {
          LMMgr.resetCassettePath()
          PrefMgr.shared.cassetteEnabled = false
        }
      }
      return
    }
    Notifier.notify(
      message: NSLocalizedString("CIN Cassette Mode", comment: "") + "\n"
        + (PrefMgr.shared.cassetteEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
    if !LMMgr.currentLM.isCassetteDataLoaded {
      LMMgr.loadCassetteData()
    }
  }

  @objc func toggleSCPCTypingMode(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Per-Char Select Mode", comment: "") + "\n"
        + (PrefMgr.shared.useSCPCTypingMode.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleChineseConverter(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Force KangXi Writing", comment: "") + "\n"
        + (PrefMgr.shared.chineseConversionEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleShiftJISShinjitaiOutput(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("JIS Shinjitai Output", comment: "") + "\n"
        + (PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleCurrencyNumerals(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Currency Numeral Output", comment: "") + "\n"
        + (PrefMgr.shared.currencyNumeralsEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleHalfWidthPunctuation(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Half-Width Punctuation Mode", comment: "") + "\n"
        + (PrefMgr.shared.halfWidthPunctuationEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleCNS11643Enabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("CNS11643 Mode", comment: "") + "\n"
        + (PrefMgr.shared.cns11643Enabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleSymbolEnabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Symbol & Emoji Input", comment: "") + "\n"
        + (PrefMgr.shared.symbolInputEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func toggleAssociatedPhrasesEnabled(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Per-Char Associated Phrases", comment: "") + "\n"
        + (PrefMgr.shared.associatedPhrasesEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func togglePhraseReplacement(_: Any? = nil) {
    resetInputHandler(forceComposerCleanup: true)
    Notifier.notify(
      message: NSLocalizedString("Use Phrase Replacement", comment: "") + "\n"
        + (PrefMgr.shared.phraseReplacementEnabled.toggled()
          ? NSLocalizedString("NotificationSwitchON", comment: "")
          : NSLocalizedString("NotificationSwitchOFF", comment: ""))
    )
  }

  @objc func selfUninstall(_: Any? = nil) {
    (NSApp.delegate as? AppDelegate)?.selfUninstall()
  }

  @objc func selfTerminate(_: Any? = nil) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.terminate(nil)
  }

  @objc func checkForUpdate(_: Any? = nil) {
    UpdateSputnik.shared.checkForUpdate(forced: true, url: kUpdateInfoSourceURL)
  }

  @objc func openUserDataFolder(_: Any? = nil) {
    if !LMMgr.userDataFolderExists {
      return
    }
    NSWorkspace.shared.openFile(
      LMMgr.dataFolderPath(isDefaultFolder: false), withApplication: "Finder"
    )
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
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.removeUnigramsFromUserOverrideModel(IMEApp.currentInputMode.reversed)
    }
  }

  @objc func clearUOM(_: Any? = nil) {
    LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode)
    if NSEvent.modifierFlags.contains(.option) {
      LMMgr.clearUserOverrideModelData(IMEApp.currentInputMode.reversed)
    }
  }

  @objc func showAbout(_: Any? = nil) {
    CtlAboutWindow.show()
    NSApp.activate(ignoringOtherApps: true)
  }
}
