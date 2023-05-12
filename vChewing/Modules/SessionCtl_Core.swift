// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
@objc(SessionCtl) // 必須加上 ObjC，因為 IMK 是用 ObjC 寫的。
public class SessionCtl: IMKInputController {
  /// 標記狀態來聲明目前新增的詞彙是否需要賦以非常低的權重。
  public static var areWeNerfing = false

  /// 目前在用的的選字窗副本。
  public var candidateUI: CtlCandidateProtocol?

  /// 工具提示視窗的副本。
  public var tooltipInstance = TooltipUI()

  /// 浮動組字窗的副本。
  public var popupCompositionBuffer = PopupCompositionBuffer()

  /// 用來標記當前副本是否已處於活動狀態。
  public var isActivated = false

  /// 當前副本的客體是否是輸入法本體？
  public var isServingIMEItself: Bool = false

  /// 用以存儲客體的 bundleIdentifier。
  /// 由於每次動態獲取都會耗時，所以這裡直接靜態記載之。
  public var clientBundleIdentifier: String = "" {
    willSet {
      if newValue.isEmpty { return }
      Self.recentClientBundleIdentifiers[newValue] = Int(Date().timeIntervalSince1970)
    }
  }

  /// 用以記錄最近存取過的十個客體（亂序），相關內容會在客體管理器當中用得到。
  public static var recentClientBundleIdentifiers = [String: Int]() {
    didSet {
      if recentClientBundleIdentifiers.count < 20 { return }
      if recentClientBundleIdentifiers.isEmpty { return }
      let x = recentClientBundleIdentifiers.sorted(by: { $0.value < $1.value }).first?.key
      guard let x = x else { return }
      recentClientBundleIdentifiers[x] = nil
    }
  }

  // MARK: -

  /// 當前 Caps Lock 按鍵是否被摁下。
  public var isCapsLocked: Bool { NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) }

  /// 當前這個 SessionCtl 副本是否處於英數輸入模式。
  public var isASCIIMode: Bool {
    get {
      PrefMgr.shared.shareAlphanumericalModeStatusAcrossClients
        ? Self.isASCIIModeForAllClients : isASCIIModeForThisClient
    }
    set {
      if PrefMgr.shared.shareAlphanumericalModeStatusAcrossClients {
        Self.isASCIIModeForAllClients = newValue
      } else {
        isASCIIModeForThisClient = newValue
      }
      resetInputHandler()
      setKeyLayout()
    }
  }

  private var isASCIIModeForThisClient = false // 給每個副本用的。
  private static var isASCIIModeForAllClients = false // 給所有副本共用的。

  /// 輸入調度模組的副本。
  var inputHandler: InputHandlerProtocol?
  /// 用以記錄當前輸入法狀態的變數。
  public var state: IMEStateProtocol = IMEState.ofEmpty() {
    didSet {
      guard oldValue.type != state.type else { return }
      if PrefMgr.shared.isDebugModeEnabled {
        var stateDescription = state.type.rawValue
        if state.type == .ofCommitting { stateDescription += "(\(state.textToCommit))" }
        vCLog("Current State: \(stateDescription), client: \(clientBundleIdentifier)")
      }
      // 因鍵盤訊號翻譯機制存在，故禁用下文。
      // guard state.isCandidateContainer != oldValue.isCandidateContainer else { return }
      // if state.isCandidateContainer || oldValue.isCandidateContainer { setKeyLayout() }
    }
  }

  /// 記錄當前輸入環境是縱排輸入還是橫排輸入。
  public static var isVerticalTyping: Bool = false
  public var isVerticalTyping: Bool = false {
    didSet {
      Self.isVerticalTyping = isVerticalTyping
    }
  }

  private let sharedAlertForInputModeToggling: NSAlert = {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Target Input Mode Activation Required".localized
    alert.informativeText = "You are proceeding to System Preferences to enable the Input Source which corresponds to the input mode you are going to switch to.".localized
    alert.addButton(withTitle: "OK".localized)
    return alert
  }()

  public func updateVerticalTypingStatus() {
    guard let client = client() else {
      isVerticalTyping = false
      return
    }
    var textFrame = NSRect.seniorTheBeast
    let attributes: [AnyHashable: Any]? = client.attributes(
      forCharacterIndex: 0, lineHeightRectangle: &textFrame
    )
    let result = (attributes?["IMKTextOrientation"] as? NSNumber)?.intValue == 0 || false
    isVerticalTyping = result
  }

  /// 當前選字窗是否為縱向。（縱排輸入時，只會啟用縱排選字窗。）
  public var isVerticalCandidateWindow = false

  /// InputMode 需要在每次出現內容變更的時候都連帶重設組字器與各項語言模組，
  /// 順帶更新 IME 模組及 UserPrefs 當中對於當前語言模式的記載。
  public var inputMode: Shared.InputMode = .imeModeNULL {
    willSet {
      /// 將新的簡繁輸入模式提報給 Prefs 模組。IMEApp 模組會據此計算正確的資料值。
      PrefMgr.shared.mostRecentInputMode = newValue.rawValue
    }
    didSet {
      if PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModel(inputMode) }
      if oldValue != inputMode, inputMode != .imeModeNULL {
        /// 先重置輸入調度模組，不然會因為之後的命令而導致該命令無法正常執行。
        resetInputHandler()
        // ----------------------------
        /// 重設所有語言模組。這裡不需要做按需重設，因為對運算量沒有影響。
        inputHandler?.currentLM = LMMgr.currentLM // 會自動更新組字引擎內的模組。
        inputHandler?.currentUOM = LMMgr.currentUOM
        /// 清空注拼槽＋同步最新的注拼槽排列設定。
        inputHandler?.ensureKeyboardParser()
        /// 將輸入法偏好設定同步至語言模組內。
        syncBaseLMPrefs()
      }
      // 特殊處理：deactivateServer() 可能會遲於另一個客體會話的 activateServer() 執行。
      // 雖然所有在這個函式內影響到的變數都改為動態變數了（不會出現跨副本波及的情況），
      // 但 IMKCandidates 是有內部共用副本的、會被波及。所以在這裡糾偏一下。
      if PrefMgr.shared.useIMKCandidateWindow {
        guard let imkC = candidateUI as? CtlCandidateIMK else { return }
        if state.isCandidateContainer, !imkC.visible {
          handle(state: state, replace: false)
        }
      }
    }
  }

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  override public init() {
    super.init()
    construct(client: client())
  }

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  ///
  /// inputClient 參數是客體應用側存在的用以藉由 IMKServer 伺服器向輸入法傳訊的物件。該物件始終遵守 IMKTextInput 協定。
  /// - Remark: 所有由委任物件實裝的「被協定要求實裝的方法」都會有一個用來接受客體物件的參數。在 IMKInputController 內部的型別不需要接受這個參數，因為已經有「client()」這個參數存在了。
  /// - Parameters:
  ///   - server: IMKServer
  ///   - delegate: 客體物件
  ///   - inputClient: 用以接受輸入的客體應用物件
  override public init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
    super.init(server: server, delegate: delegate, client: inputClient)
    let theClient = inputClient as? (IMKTextInput & NSObjectProtocol)
    construct(client: theClient)
  }

  /// 所有建構子都會執行的共用部分，在 super.init() 之後執行。
  private func construct(client theClient: (IMKTextInput & NSObjectProtocol)? = nil) {
    DispatchQueue.main.async { [self] in
      inputHandler = InputHandler(
        lm: LMMgr.currentLM, uom: LMMgr.currentUOM, pref: PrefMgr.shared
      )
      inputHandler?.delegate = self
      syncBaseLMPrefs()
      // 下述兩行很有必要，否則輸入法會在手動重啟之後無法立刻生效。
      let maybeClient = theClient ?? client()
      activateServer(maybeClient)
      // GCD 會觸發 didSet，所以不用擔心。
      inputMode = .init(rawValue: PrefMgr.shared.mostRecentInputMode) ?? .imeModeNULL
    }
  }
}

// MARK: - 工具函式

public extension SessionCtl {
  /// 強制重設當前鍵盤佈局、使其與偏好設定同步。
  func setKeyLayout() {
    guard let client = client(), !isServingIMEItself else { return }

    DispatchQueue.main.async { [self] in
      if isASCIIMode, IMKHelper.isDynamicBasicKeyboardLayoutEnabled {
        client.overrideKeyboard(withKeyboardNamed: PrefMgr.shared.alphanumericalKeyboardLayout)
        return
      }
      client.overrideKeyboard(withKeyboardNamed: PrefMgr.shared.basicKeyboardLayout)
    }
  }

  /// 重設輸入調度模組，會將當前尚未遞交的內容遞交出去。
  func resetInputHandler(forceComposerCleanup forceCleanup: Bool = false) {
    guard let inputHandler = inputHandler else { return }
    var textToCommit = ""
    // 過濾掉尚未完成拼寫的注音。
    let sansReading: Bool =
      (state.type == .ofInputting) && (PrefMgr.shared.trimUnfinishedReadingsOnCommit || forceCleanup)
    if state.hasComposition {
      textToCommit = inputHandler.generateStateOfInputting(sansReading: sansReading).displayedText
    }
    // 威注音不再在這裡對 IMKTextInput 客體黑名單當中的應用做資安措施。
    // 有相關需求者，請在切換掉輸入法或者切換至新的客體應用之前敲一下 Shift+Delete。
    switchState(IMEState.ofCommitting(textToCommit: textToCommit))
  }
}

// MARK: - IMKStateSetting 協定規定的方法

public extension SessionCtl {
  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體。
  override func activateServer(_ sender: Any!) {
    super.activateServer(sender)
    DispatchQueue.main.async { [self] in
      if let senderBundleID: String = (sender as? IMKTextInput)?.bundleIdentifier() {
        vCLog("activateServer(\(senderBundleID))")
        isServingIMEItself = Bundle.main.bundleIdentifier == senderBundleID
        clientBundleIdentifier = senderBundleID
      }
    }
    DispatchQueue.main.async {
      // 自動啟用肛塞（廉恥模式），除非這一天是愚人節。
      if !Date.isTodayTheDate(from: 0401), !PrefMgr.shared.shouldNotFartInLieuOfBeep {
        PrefMgr.shared.shouldNotFartInLieuOfBeep = true
      }
    }
    DispatchQueue.main.async { [self] in
      if inputMode != IMEApp.currentInputMode {
        inputMode = IMEApp.currentInputMode
      }
    }
    DispatchQueue.main.async { [self] in
      if isActivated { return }

      // 這裡不需要 setValue()，因為 IMK 會在自動呼叫 activateServer() 之後自動執行 setValue()。
      inputHandler = InputHandler(
        lm: LMMgr.currentLM, uom: LMMgr.currentUOM, pref: PrefMgr.shared
      )
      inputHandler?.delegate = self
      syncBaseLMPrefs()

      DispatchQueue.main.async {
        UpdateSputnik.shared.checkForUpdate(forced: false, url: kUpdateInfoSourceURL)
        (NSApp.delegate as? AppDelegate)?.checkMemoryUsage()
      }

      state = IMEState.ofEmpty()
      isActivated = true // 登記啟用狀態。
      setKeyLayout()
    }
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func deactivateServer(_ sender: Any!) {
    DispatchQueue.main.async { [self] in
      isActivated = false
      resetInputHandler() // 這條會自動搞定 Empty 狀態。
      switchState(IMEState.ofDeactivated())
      inputHandler = nil
      // IMK 選字窗可以不用 nil，不然反而會出問題。反正 IMK 選字窗記憶體開銷可以不計。
      if !(candidateUI is CtlCandidateIMK) {
        candidateUI = nil
      }
    }
    super.deactivateServer(sender)
  }

  /// 切換至某一個輸入法的某個副本時（比如威注音的簡體輸入法副本與繁體輸入法副本），會觸發該函式。
  /// - Remark: 當系統呼叫 activateServer() 的時候，setValue() 會被自動呼叫。
  /// 但是，手動呼叫 activateServer() 的時候，setValue() 不會被自動呼叫。
  /// - Parameters:
  ///   - value: 輸入法在系統偏好設定當中的副本的 identifier，與 bundle identifier 類似。在輸入法的 info.plist 內定義。
  ///   - tag: 標記（無須使用）。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
    DispatchQueue.main.async { [self] in
      let newMode: Shared.InputMode = .init(rawValue: value as? String ?? PrefMgr.shared.mostRecentInputMode) ?? .imeModeNULL
      if inputMode != newMode { inputMode = newMode }
    }
    super.setValue(value, forTag: tag, client: sender)
  }

  /// 專門用來就地切換繁簡模式的函式。
  @objc func switchInputMode(_: Any? = nil) {
    guard let client: IMKTextInput = client() else { return }
    defer { isASCIIMode = false }
    let nowMode = IMEApp.currentInputMode
    guard nowMode != .imeModeNULL else { return }
    modeCheck: for neta in TISInputSource.allRegisteredInstancesOfThisInputMethod {
      guard !neta.isActivated else { continue }
      osCheck: if #unavailable(macOS 12) {
        neta.activate()
        if !neta.isActivated {
          break osCheck
        }
        break modeCheck
      }
      let result = sharedAlertForInputModeToggling.runModal()
      NSApp.activate(ignoringOtherApps: true)
      if result == NSApplication.ModalResponse.alertFirstButtonReturn {
        neta.activate()
      }
      return
    }
    let status = "NotificationSwitchRevolver".localized
    DispatchQueue.main.async {
      if LMMgr.lmCHT.isCoreLMLoaded, LMMgr.lmCHS.isCoreLMLoaded {
        Notifier.notify(
          message: nowMode.reversed.localizedDescription + "\n" + status
        )
      }
    }
    client.selectMode(nowMode.reversed.rawValue)
  }

  /// 將輸入法偏好設定同步至語言模組內。
  func syncBaseLMPrefs() {
    LMMgr.currentLM.isPhraseReplacementEnabled = PrefMgr.shared.phraseReplacementEnabled
    LMMgr.currentLM.isCNSEnabled = PrefMgr.shared.cns11643Enabled
    LMMgr.currentLM.isSymbolEnabled = PrefMgr.shared.symbolInputEnabled
    LMMgr.currentLM.isSCPCEnabled = PrefMgr.shared.useSCPCTypingMode
    LMMgr.currentLM.isCassetteEnabled = PrefMgr.shared.cassetteEnabled
    LMMgr.currentLM.deltaOfCalendarYears = PrefMgr.shared.deltaOfCalendarYears
  }
}

// MARK: - IMKServerInput 協定規定的方法（僅部分）

// 註：handle(_ event:) 位於 SessionCtl_HandleEvent.swift。

public extension SessionCtl {
  /// 該函式的回饋結果決定了輸入法會攔截且捕捉哪些類型的輸入裝置操作事件。
  ///
  /// 一個客體應用會與輸入法共同確認某個輸入裝置操作事件是否可以觸發輸入法內的某個方法。預設情況下，
  /// 該函式僅響應 Swift 的「`NSEvent.EventTypeMask = [.keyDown]`」，也就是 ObjC 當中的「`NSKeyDownMask`」。
  /// 如果您的輸入法「僅攔截」鍵盤按鍵事件處理的話，IMK 會預設啟用這些對滑鼠的操作：當組字區存在時，
  /// 如果使用者用滑鼠點擊了該文字輸入區內的組字區以外的區域的話，則該組字區的顯示內容會被直接藉由
  /// 「`commitComposition(_ message)`」遞交給客體。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 返回一個 uint，其中承載了與系統 NSEvent 操作事件有關的掩碼集合（詳見 NSEvent.h）。
  override func recognizedEvents(_ sender: Any!) -> Int {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func commitComposition(_ sender: Any!) {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    resetInputHandler()
    clearInlineDisplay()
    // super.commitComposition(sender)  // 這句不要引入，否則每次切出輸入法時都會死當。
  }

  /// 指定輸入法要遞交出去的內容（雖然 InputMethodKit 可能並不會真的用到這個函式）。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 字串內容，或者 nil。
  override func composedString(_ sender: Any!) -> Any! {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    guard state.hasComposition else { return "" }
    return state.displayedTextConverted
  }

  /// 輸入法要被換掉或關掉的時候，要做的事情。
  /// 不過好像因為 IMK 的 Bug 而並不會被執行。
  override func inputControllerWillClose() {
    // 下述兩行用來防止尚未完成拼寫的注音內容被遞交出去。
    resetInputHandler()
    super.inputControllerWillClose()
  }

  /// 指定標記模式下被高亮的部分。
  override func selectionRange() -> NSRange {
    attributedStringSecured.range
  }

  /// 該函式僅用來取消任何輸入法浮動視窗的顯示。
  override func hidePalettes() {
    candidateUI?.visible = false
    popupCompositionBuffer.hide()
    tooltipInstance.hide()
  }
}
