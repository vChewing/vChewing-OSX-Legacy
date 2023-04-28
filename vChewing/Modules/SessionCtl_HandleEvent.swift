// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

// MARK: - Facade

public extension SessionCtl {
  /// 接受所有鍵鼠事件為 NSEvent，讓輸入法判斷是否要處理、該怎樣處理。
  /// 然後再交給 InputHandler.handleEvent() 分診。
  /// - Parameters:
  ///   - event: 裝置操作輸入事件，可能會是 nil。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該按鍵已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  @objc(handleEvent:client:) override func handle(_ event: NSEvent?, client sender: Any?) -> Bool {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。

    // 就這傳入的 NSEvent 都還有可能是 nil，Apple InputMethodKit 團隊到底在搞三小。
    // 只針對特定類型的 client() 進行處理。
    guard let event = event, sender is IMKTextInput else {
      resetInputHandler(forceComposerCleanup: true)
      return false
    }

    // MARK: 前置處理

    // 雖然在 recognizedEvents 當中有過定義，但這裡還是再多施加一道保險。
    if event.type != .keyDown, event.type != .flagsChanged { return false }

    // 如果是 deactivated 狀態的話，強制糾正其為 empty()。
    if let client = client(), state.type == .ofDeactivated {
      state = IMEState.ofEmpty()
      return handle(event, client: client)
    }

    // Caps Lock 通知與切換處理，要求至少 macOS 12 Monterey。
    if #available(macOS 12, *) {
      if event.type == .flagsChanged, event.keyCode == KeyCode.kCapsLock.rawValue {
        DispatchQueue.main.async {
          let isCapsLockTurnedOn = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock)
          let status = NSLocalizedString("NotificationSwitchASCII", comment: "")
          guard PrefMgr.shared.showNotificationsWhenTogglingCapsLock else { return }
          Notifier.notify(
            message: isCapsLockTurnedOn
              ? "Caps Lock " + "Alphanumerical Input Mode".localized + "\n" + status
              : "Chinese Input Mode".localized + "\n" + status
          )
          self.isASCIIMode = isCapsLockTurnedOn
        }
      }
    }

    // 切換英數模式開關。
    func toggleAlphanumericalMode() {
      let status = "NotificationSwitchASCII".localized
      Notifier.notify(
        message: isASCIIMode.toggled()
          ? NSLocalizedString("Alphanumerical Input Mode", comment: "") + "\n" + status
          : NSLocalizedString("Chinese Input Mode", comment: "") + "\n" + status
      )
    }

    // 用 JIS 鍵盤的英數切換鍵來切換中英文模式。
    if event.type == .keyDown, event.isJISAlphanumericalKey {
      toggleAlphanumericalMode()
      return true // Adobe Photoshop 相容：對 JIS 英數切換鍵傳入事件一律立刻返回 true。
    }

    // MARK: 針對客體的具體處理

    // 不再讓威注音處理由 Shift 切換到的英文模式的按鍵輸入。
    if isASCIIMode, !isCapsLocked { return false }

    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 InputHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須針對 event.type == .flagsChanged 提前返回結果，
    /// 否則，每次處理這種判斷時都會因為讀取 event.characters? 而觸發 NSInternalInconsistencyException。
    if event.type == .flagsChanged { return true }

    /// 沒有文字輸入客體的話，就不要再往下處理了。
    guard let inputHandler = inputHandler, client() != nil else { return false }

    /// 除非核心辭典有載入，否則一律蜂鳴。
    if !LMMgr.currentLM.isCoreLMLoaded {
      if (event as InputSignalProtocol).isReservedKey { return false }
      var newState: IMEStateProtocol = IMEState.ofEmpty()
      newState.tooltip = NSLocalizedString("Factory dictionary not loaded yet.", comment: "")
      newState.tooltipDuration = 1.85
      newState.data.tooltipColorState = .redAlert
      switchState(newState)
      callError("CoreLM not loaded yet.")
      return true
    }

    var eventToDeal = event

    // 如果是方向鍵輸入的話，就想辦法帶上標記資訊、來說明當前是縱排還是橫排。
    if event.isUp || event.isDown || event.isLeft || event.isRight {
      updateVerticalTypingStatus() // 檢查當前環境是否是縱排輸入。
      eventToDeal = event.reinitiate(charactersIgnoringModifiers: isVerticalTyping ? "Vertical" : "Horizontal") ?? event
    }

    // 使 NSEvent 自翻譯，這樣可以讓 Emacs NSEvent 變成標準 NSEvent。
    // 注意不要針對 Empty 空狀態使用這個轉換，否則會使得相關組合鍵第交出垃圾字元。
    if eventToDeal.isEmacsKey {
      if state.type == .ofEmpty { return false }
      let verticalProcessing = (state.isCandidateContainer) ? isVerticalCandidateWindow : isVerticalTyping
      eventToDeal = eventToDeal.convertFromEmacsKeyEvent(isVerticalContext: verticalProcessing)
    }

    // 在啟用注音排列而非拼音輸入的情況下，強制將當前鍵盤佈局翻譯為美規鍵盤。
    if !inputHandler.isComposerUsingPinyin || IMKHelper.isDynamicBasicKeyboardLayoutEnabled {
      eventToDeal = eventToDeal.layoutTranslated(to: .qwerty)
    }

    // Apple 數字小鍵盤處理
    if eventToDeal.isNumericPadKey,
       let eventCharConverted = eventToDeal.characters?.applyingTransformFW2HW(reverse: false)
    {
      eventToDeal = eventToDeal.reinitiate(characters: eventCharConverted) ?? eventToDeal
    } else if [.ofEmpty, .ofInputting].contains(state.type), eventToDeal.isMainAreaNumKey,
              !eventToDeal.isCommandHold, !eventToDeal.isControlHold, eventToDeal.isOptionHold
    {
      // Alt(+Shift)+主鍵盤區數字鍵 預先處理
      eventToDeal = eventToDeal.reinitiate(characters: eventToDeal.mainAreaNumKeyChar) ?? eventToDeal
    }

    // 準備修飾鍵，用來判定要新增的詞彙是否需要賦以非常低的權重。
    Self.areWeNerfing = eventToDeal.modifierFlags == [.shift, .command]

    /// 直接交給 commonEventHandler 來處理。
    let result = inputHandler.handleEvent(eventToDeal)
    if !result {
      // 除非是 .ofMarking 狀態，否則讓某些不用去抓的按鍵起到「取消工具提示」的作用。
      if [.ofEmpty].contains(state.type) { tooltipInstance.hide() }

      // 將 Apple 動態鍵盤佈局的 RAW 輸出轉為 ABC 輸出，除非轉換結果與轉換前的內容一致。
      if IMKHelper.isDynamicBasicKeyboardLayoutEnabled, event.text != eventToDeal.text {
        switchState(IMEState.ofCommitting(textToCommit: eventToDeal.text))
        return true
      }
    }

    return result
  }
}
