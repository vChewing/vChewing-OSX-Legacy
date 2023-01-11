// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

private let kWindowTitleHeight: Double = 78

extension NSToolbarItem.Identifier {
  fileprivate static let ofGeneral = NSToolbarItem.Identifier(rawValue: "tabGeneral")
  fileprivate static let ofExperience = NSToolbarItem.Identifier(rawValue: "tabExperience")
  fileprivate static let ofDictionary = NSToolbarItem.Identifier(rawValue: "tabDictionary")
  fileprivate static let ofPhrases = NSToolbarItem.Identifier(rawValue: "tabPhrases")
  fileprivate static let ofCassette = NSToolbarItem.Identifier(rawValue: "tabCassette")
  fileprivate static let ofKeyboard = NSToolbarItem.Identifier(rawValue: "tabKeyboard")
  fileprivate static let ofDevZone = NSToolbarItem.Identifier(rawValue: "tabDevZone")
}

// Note: The "InputMethodServerPreferencesWindowControllerClass" in Info.plist
// only works with macOS System Preference pane (like macOS built-in input methods).
// It should be set as "Preferences" which correspondes to the "Preference" pref pane
// of this build target.
class CtlPrefWindow: NSWindowController, NSWindowDelegate {
  @IBOutlet var fontSizePopUpButton: NSPopUpButton!
  @IBOutlet var uiLanguageButton: NSPopUpButton!
  @IBOutlet var basicKeyboardLayoutButton: NSPopUpButton!
  @IBOutlet var selectionKeyComboBox: NSComboBox!
  @IBOutlet var chkTrad2KangXi: NSButton!
  @IBOutlet var chkTrad2JISShinjitai: NSButton!
  @IBOutlet var lblCurrentlySpecifiedUserDataFolder: NSTextFieldCell!
  @IBOutlet var tglControlDevZoneIMKCandidate: NSButton!
  @IBOutlet var cmbCandidateFontSize: NSPopUpButton!

  @IBOutlet var btnBrowseFolderForUserPhrases: NSButton!
  @IBOutlet var txtUserPhrasesFolderPath: NSTextField!
  @IBOutlet var lblUserPhraseFolderChangeDescription: NSTextField!

  @IBOutlet var cmbPEInputModeMenu: NSPopUpButton!
  @IBOutlet var cmbPEDataTypeMenu: NSPopUpButton!
  @IBOutlet var btnPEReload: NSButton!
  @IBOutlet var btnPEConsolidate: NSButton!
  @IBOutlet var btnPESave: NSButton!
  @IBOutlet var btnPEAdd: NSButton!
  @IBOutlet var btnPEOpenExternally: NSButton!
  @IBOutlet var tfdPETextEditor: NSTextView!
  @IBOutlet var txtPECommentField: NSTextField!
  @IBOutlet var txtPEField1: NSTextField!
  @IBOutlet var txtPEField2: NSTextField!
  @IBOutlet var txtPEField3: NSTextField!
  var isLoading = false {
    didSet { setPEUIControlAvailability() }
  }

  @IBOutlet var vwrGeneral: NSView!
  @IBOutlet var vwrExperience: NSView!
  @IBOutlet var vwrDictionary: NSView!
  @IBOutlet var vwrPhrases: NSView!
  @IBOutlet var vwrCassette: NSView!
  @IBOutlet var vwrKeyboard: NSView!
  @IBOutlet var vwrDevZone: NSView!

  public static var shared: CtlPrefWindow?

  static func show() {
    let resetPhraseEditor: Bool = shared?.window == nil || !(shared?.window?.isVisible ?? false) || shared == nil
    if shared == nil { shared = CtlPrefWindow(windowNibName: "frmPrefWindow") }
    guard let shared = shared, let sharedWindow = shared.window else { return }
    sharedWindow.delegate = shared
    sharedWindow.setPosition(vertical: .top, horizontal: .right, padding: 20)
    sharedWindow.orderFrontRegardless()  // 逼著視窗往最前方顯示
    sharedWindow.level = .statusBar
    shared.showWindow(shared)
    if resetPhraseEditor { shared.initPhraseEditor() }
    NSApp.activate(ignoringOtherApps: true)
  }

  private var currentLanguageSelectItem: NSMenuItem?

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.setPosition(vertical: .top, horizontal: .right, padding: 20)

    cmbCandidateFontSize.isEnabled = true

    if #unavailable(macOS 10.14) {
      if PrefMgr.shared.useIMKCandidateWindow {
        if #available(macOS 10.13, *) {
          cmbCandidateFontSize.isEnabled = false
        }
      }
    }

    if #unavailable(macOS 10.13) {
      btnBrowseFolderForUserPhrases.isEnabled = false
      txtUserPhrasesFolderPath.isEnabled = false
      btnBrowseFolderForUserPhrases.toolTip =
        "User phrase folder path is not customizable in macOS 10.9 - 10.12.".localized
      txtUserPhrasesFolderPath.toolTip = "User phrase folder path is not customizable in macOS 10.9 - 10.12.".localized
      lblUserPhraseFolderChangeDescription.stringValue =
        "User phrase folder path is not customizable in macOS 10.9 - 10.12.".localized
    }

    var preferencesTitleName = NSLocalizedString("vChewing Preferences…", comment: "")
    preferencesTitleName.removeLast()

    let toolbar = NSToolbar(identifier: "preference toolbar")
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.sizeMode = .default
    toolbar.delegate = self
    toolbar.selectedItemIdentifier = .ofGeneral
    toolbar.showsBaselineSeparator = true
    if #available(macOS 11.0, *) {
      window?.toolbarStyle = .preference
    }
    window?.toolbar = toolbar
    window?.title = preferencesTitleName
    use(view: vwrGeneral)

    lblCurrentlySpecifiedUserDataFolder.placeholderString = LMMgr.dataFolderPath(
      isDefaultFolder: true)

    // Credit: Hiraku Wang (for the implementation of the UI language select support in Cocoa PrefWindow.
    do {
      let languages = ["auto", "en", "zh-Hans", "zh-Hant", "ja"]
      var autoMUISelectItem: NSMenuItem?
      var chosenLanguageItem: NSMenuItem?
      uiLanguageButton.menu?.removeAllItems()

      let appleLanguages = PrefMgr.shared.appleLanguages
      for language in languages {
        let menuItem = NSMenuItem()
        menuItem.title = NSLocalizedString(language, comment: language)
        menuItem.representedObject = language

        if language == "auto" {
          autoMUISelectItem = menuItem
        }

        if !appleLanguages.isEmpty {
          if appleLanguages[0] == language {
            chosenLanguageItem = menuItem
          }
        }
        uiLanguageButton.menu?.addItem(menuItem)
      }

      currentLanguageSelectItem = chosenLanguageItem ?? autoMUISelectItem
      uiLanguageButton.select(currentLanguageSelectItem)
    }

    var usKeyboardLayoutItem: NSMenuItem?
    var chosenBaseKeyboardLayoutItem: NSMenuItem?

    basicKeyboardLayoutButton.menu?.removeAllItems()

    let basicKeyboardLayoutID = PrefMgr.shared.basicKeyboardLayout

    for source in IMKHelper.allowedBasicLayoutsAsTISInputSources {
      guard let source = source else {
        basicKeyboardLayoutButton.menu?.addItem(NSMenuItem.separator())
        continue
      }
      let menuItem = NSMenuItem()
      menuItem.title = source.vChewingLocalizedName
      menuItem.representedObject = source.identifier
      if source.identifier == "com.apple.keylayout.US" { usKeyboardLayoutItem = menuItem }
      if basicKeyboardLayoutID == source.identifier { chosenBaseKeyboardLayoutItem = menuItem }
      basicKeyboardLayoutButton.menu?.addItem(menuItem)
    }

    basicKeyboardLayoutButton.select(chosenBaseKeyboardLayoutItem ?? usKeyboardLayoutItem)

    selectionKeyComboBox.usesDataSource = false
    selectionKeyComboBox.removeAllItems()
    selectionKeyComboBox.addItems(withObjectValues: CandidateKey.suggestions)

    var candidateSelectionKeys = PrefMgr.shared.candidateKeys
    if candidateSelectionKeys.isEmpty {
      candidateSelectionKeys = CandidateKey.defaultKeys
    }

    selectionKeyComboBox.stringValue = candidateSelectionKeys
    if PrefMgr.shared.useIMKCandidateWindow {
      selectionKeyComboBox.isEnabled = false  // 無法與 IMKCandidates 協作，故禁用。
    }

    initPhraseEditor()
  }

  func windowWillClose(_: Notification) {
    tfdPETextEditor.string = ""
  }

  // 這裡有必要加上這段處理，用來確保藉由偏好設定介面動過的 CNS 開關能夠立刻生效。
  // 所有涉及到語言模型開關的內容均需要這樣處理。
  @IBAction func toggleCNSSupport(_: Any) {
    LMMgr.setCNSEnabled(PrefMgr.shared.cns11643Enabled)
  }

  @IBAction func toggleSymbolInputEnabled(_: Any) {
    LMMgr.setSymbolEnabled(PrefMgr.shared.symbolInputEnabled)
  }

  @IBAction func toggleTrad2KangXiAction(_: Any) {
    if chkTrad2KangXi.state == .on, chkTrad2JISShinjitai.state == .on {
      PrefMgr.shared.shiftJISShinjitaiOutputEnabled.toggle()
    }
  }

  @IBAction func toggleTrad2JISShinjitaiAction(_: Any) {
    if chkTrad2KangXi.state == .on, chkTrad2JISShinjitai.state == .on {
      PrefMgr.shared.chineseConversionEnabled.toggle()
    }
  }

  @IBAction func updateBasicKeyboardLayoutAction(_: Any) {
    if let sourceID = basicKeyboardLayoutButton.selectedItem?.representedObject as? String {
      PrefMgr.shared.basicKeyboardLayout = sourceID
    }
  }

  @IBAction func updateUiLanguageAction(_: Any) {
    if let selectItem = uiLanguageButton.selectedItem {
      if currentLanguageSelectItem == selectItem {
        return
      }
    }
    if let language = uiLanguageButton.selectedItem?.representedObject as? String {
      if language != "auto" {
        PrefMgr.shared.appleLanguages = [language]
      } else {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
      }

      NSLog("vChewing App self-terminated due to UI language change.")
      NSApp.terminate(nil)
    }
  }

  @IBAction func updateIMKCandidateEnableStatusAction(_: Any) {
    NSLog("vChewing App self-terminated due to enabling / disabling IMK candidate window.")
    NSApp.terminate(nil)
  }

  @IBAction func clickedWhetherIMEShouldNotFartToggleAction(_: Any) {
    IMEApp.buzz()
  }

  @IBAction func changeSelectionKeyAction(_ sender: Any) {
    guard
      let keys = (sender as AnyObject).stringValue?.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      .deduplicated
    else {
      selectionKeyComboBox.stringValue = PrefMgr.shared.candidateKeys
      return
    }
    guard let errorResult = CandidateKey.validate(keys: keys) else {
      PrefMgr.shared.candidateKeys = keys
      selectionKeyComboBox.stringValue = PrefMgr.shared.candidateKeys
      return
    }
    if let window = window {
      let alert = NSAlert(error: NSLocalizedString("Invalid Selection Keys.", comment: ""))
      alert.informativeText = errorResult
      alert.beginSheetModal(for: window) { _ in
        self.selectionKeyComboBox.stringValue = PrefMgr.shared.candidateKeys
      }
      IMEApp.buzz()
    }
  }

  @IBAction func toggledExternalFactoryPlistDataOnOff(_: NSButton) {
    LMMgr.reloadFactoryDictionaryPlists()
  }

  @IBAction func resetSpecifiedUserDataFolder(_: Any) {
    LMMgr.resetSpecifiedUserDataFolder()
  }

  @IBAction func chooseUserDataFolderToSpecify(_: Any) {
    guard let window = window else { return }

    if #unavailable(macOS 10.13) {
      window.callAlert(
        title: Self.filePanelAlertMessageTitleForURLConfirmation,
        text: Self.strDefaultsWriteUserFolderPath + "\n\n" + Self.filePanelAlertMessageText
      )
      return
    }

    let dlgOpenPath = NSOpenPanel()
    dlgOpenPath.title = NSLocalizedString(
      "Choose your desired user data folder.", comment: ""
    )
    dlgOpenPath.showsResizeIndicator = true
    dlgOpenPath.showsHiddenFiles = true
    dlgOpenPath.canChooseFiles = false
    dlgOpenPath.canChooseDirectories = true
    dlgOpenPath.allowsMultipleSelection = false

    let bolPreviousFolderValidity = LMMgr.checkIfSpecifiedUserDataFolderValid(
      PrefMgr.shared.userDataFolderSpecified.expandingTildeInPath)

    dlgOpenPath.beginSheetModal(for: window) { result in
      if result == NSApplication.ModalResponse.OK {
        guard let url = dlgOpenPath.url else { return }
        // CommonDialog 讀入的路徑沒有結尾斜槓，這會導致檔案目錄合規性判定失準。
        // 所以要手動補回來。
        var newPath = url.path
        newPath.ensureTrailingSlash()
        if LMMgr.checkIfSpecifiedUserDataFolderValid(newPath) {
          PrefMgr.shared.userDataFolderSpecified = newPath
          (NSApp.delegate as? AppDelegate)?.updateDirectoryMonitorPath()
        } else {
          IMEApp.buzz()
          if !bolPreviousFolderValidity {
            LMMgr.resetSpecifiedUserDataFolder()
          }
          return
        }
      } else {
        if !bolPreviousFolderValidity {
          LMMgr.resetSpecifiedUserDataFolder()
        }
        return
      }
    }
  }

  @IBAction func onToggleCassetteMode(_: Any) {
    if PrefMgr.shared.cassetteEnabled, !LMMgr.checkCassettePathValidity(PrefMgr.shared.cassettePath) {
      if let window = window {
        IMEApp.buzz()
        let alert = NSAlert(error: NSLocalizedString("Path invalid or file access error.", comment: ""))
        alert.informativeText = NSLocalizedString(
          "Please reconfigure the cassette path to a valid one before enabling this mode.", comment: ""
        )
        alert.beginSheetModal(for: window) { _ in
          LMMgr.resetCassettePath()
          PrefMgr.shared.cassetteEnabled = false
        }
      }
    } else {
      LMMgr.loadCassetteData()
    }
  }

  @IBAction func resetSpecifiedCassettePath(_: Any) {
    LMMgr.resetCassettePath()
  }

  @IBAction func chooseCassettePath(_: Any) {
    guard let window = window else { return }

    if #unavailable(macOS 10.13) {
      window.callAlert(
        title: Self.filePanelAlertMessageTitleForURLConfirmation,
        text: Self.strDefaultsWriteCassettePath + "\n\n" + Self.filePanelAlertMessageText
      )
      return
    }

    let dlgOpenFile = NSOpenPanel()
    dlgOpenFile.title = NSLocalizedString(
      "Choose your desired cassette file path.", comment: ""
    )
    dlgOpenFile.showsResizeIndicator = true
    dlgOpenFile.showsHiddenFiles = true
    dlgOpenFile.canChooseFiles = true
    dlgOpenFile.canChooseDirectories = false
    dlgOpenFile.allowsMultipleSelection = false
    dlgOpenFile.allowedFileTypes = ["cin2", "vcin", "cin"]
    dlgOpenFile.allowsOtherFileTypes = true

    let bolPreviousPathValidity = LMMgr.checkCassettePathValidity(
      PrefMgr.shared.cassettePath.expandingTildeInPath)

    dlgOpenFile.beginSheetModal(for: window) { result in
      if result == NSApplication.ModalResponse.OK {
        guard let url = dlgOpenFile.url else { return }
        if LMMgr.checkCassettePathValidity(url.path) {
          PrefMgr.shared.cassettePath = url.path
          LMMgr.loadCassetteData()
        } else {
          IMEApp.buzz()
          if !bolPreviousPathValidity {
            LMMgr.resetCassettePath()
          }
          return
        }
      } else {
        if !bolPreviousPathValidity {
          LMMgr.resetCassettePath()
        }
        return
      }
    }
  }
}

// MARK: - NSToolbarDelegate Methods

extension CtlPrefWindow: NSToolbarDelegate {
  func use(view: NSView) {
    guard let window = window else {
      return
    }
    window.contentView?.subviews.first?.removeFromSuperview()
    let viewFrame = view.frame
    var windowRect = window.frame
    windowRect.size.height = kWindowTitleHeight + viewFrame.height
    windowRect.size.width = viewFrame.width
    windowRect.origin.y = window.frame.maxY - (viewFrame.height + kWindowTitleHeight)
    window.setFrame(windowRect, display: true, animate: true)
    window.contentView?.frame = view.bounds
    window.contentView?.addSubview(view)
  }

  var toolbarIdentifiers: [NSToolbarItem.Identifier] {
    if #unavailable(macOS 10.13) {
      return [.ofGeneral, .ofExperience, .ofDictionary, .ofPhrases, .ofKeyboard]
    }
    return [.ofGeneral, .ofExperience, .ofDictionary, .ofPhrases, .ofCassette, .ofKeyboard]
  }

  func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarIdentifiers
  }

  @objc func showGeneralView(_: Any?) {
    use(view: vwrGeneral)
    window?.toolbar?.selectedItemIdentifier = .ofGeneral
  }

  @objc func showExperienceView(_: Any?) {
    use(view: vwrExperience)
    window?.toolbar?.selectedItemIdentifier = .ofExperience
  }

  @objc func showDictionaryView(_: Any?) {
    use(view: vwrDictionary)
    window?.toolbar?.selectedItemIdentifier = .ofDictionary
  }

  @objc func showPhrasesView(_: Any?) {
    use(view: vwrPhrases)
    window?.toolbar?.selectedItemIdentifier = .ofPhrases
  }

  @objc func showCassetteView(_: Any?) {
    use(view: vwrCassette)
    window?.toolbar?.selectedItemIdentifier = .ofCassette
  }

  @objc func showKeyboardView(_: Any?) {
    use(view: vwrKeyboard)
    window?.toolbar?.selectedItemIdentifier = .ofKeyboard
  }

  @objc func showDevZoneView(_: Any?) {
    use(view: vwrDevZone)
    window?.toolbar?.selectedItemIdentifier = .ofDevZone
  }

  func toolbar(
    _: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar _: Bool
  ) -> NSToolbarItem? {
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.target = self
    switch itemIdentifier {
      case .ofGeneral:
        let title = NSLocalizedString("General", comment: "")
        item.label = title
        item.image = .tabImageGeneral
        item.action = #selector(showGeneralView(_:))

      case .ofExperience:
        let title = NSLocalizedString("Experience", comment: "")
        item.label = title
        item.image = .tabImageExperience
        item.action = #selector(showExperienceView(_:))

      case .ofDictionary:
        let title = NSLocalizedString("Dictionary", comment: "")
        item.label = title
        item.image = .tabImageDictionary
        item.action = #selector(showDictionaryView(_:))

      case .ofPhrases:
        item.label = CtlPrefWindow.locPhrasesTabTitle
        item.image = .tabImagePhrases
        item.action = #selector(showPhrasesView(_:))

      case .ofCassette:
        let title = NSLocalizedString("Cassette", comment: "")
        item.label = title
        item.image = .tabImageCassette
        item.action = #selector(showCassetteView(_:))

      case .ofKeyboard:
        let title = NSLocalizedString("Keyboard", comment: "")
        item.label = title
        item.image = .tabImageKeyboard
        item.action = #selector(showKeyboardView(_:))

      case .ofDevZone:
        let title = NSLocalizedString("DevZone", comment: "")
        item.label = title
        item.image = .tabImageDevZone
        item.action = #selector(showDevZoneView(_:))

      default:
        return nil
    }
    return item
  }
}

// MARK: - Toolbar Icons.

extension NSImage {
  static let tabImageGeneral: NSImage! = .init(named: "PrefToolbar-General")
  static let tabImageExperience: NSImage! = .init(named: "PrefToolbar-Experience")
  static let tabImageDictionary: NSImage! = .init(named: "PrefToolbar-Dictionary")
  static let tabImagePhrases: NSImage! = .init(named: "PrefToolbar-Phrases")
  static let tabImageCassette: NSImage! = .init(named: "PrefToolbar-Cassette")
  static let tabImageKeyboard: NSImage! = .init(named: "PrefToolbar-Keyboard")
  static let tabImageDevZone: NSImage! = .init(named: "PrefToolbar-DevZone")
}

// MARK: - Localization-Related Contents.

extension CtlPrefWindow {
  /// 由於用於頁籤標題的某些用語放在 localizable 資源內管理的話容易混亂，所以這裡單獨處理。
  static var locPhrasesTabTitle: String {
    switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return "辞書編集"
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Hans") {
          return "语汇编辑"
        } else if PrefMgr.shared.appleLanguages[0].contains("zh-Hant") {
          return "語彙編輯"
        }
        return "Phrases"
    }
  }

  static var filePanelAlertMessageTitleForURLConfirmation: String =
    "Please use “defaults write” terminal command to modify this String value:".localized
  static var filePanelAlertMessageTitleForClientIdentifiers: String = "Please manually enter the identifier(s)."
    .localized
  static var filePanelAlertMessageText: String =
    "There is a bug in macOS 10.9, preventing an input method from accessing its own file panels. Doing so will result in eternal hang-crash of not only the input method but all client apps it tries attached to, requiring SSH connection to this computer to terminate the input method process by executing “killall vChewing”. Due to possible concerns of the same possible issue in macOS 10.10 and 10.11, we completely disabled this feature."
    .localized
  static var strDefaultsWriteUserFolderPath: String =
    "defaults write org.atelierInmu.inputmethod.vChewing UserDataFolderSpecified -string \"~/FolderPathEndedWithTrailingSlash/\""
    .localized
  static var strDefaultsWriteCassettePath: String =
    "defaults write org.atelierInmu.inputmethod.vChewing CassettePath -string \"~/FilePathEndedWithoutTrailingSlash\""
    .localized
}
