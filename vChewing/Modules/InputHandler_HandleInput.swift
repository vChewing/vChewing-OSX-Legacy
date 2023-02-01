// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// 該檔案乃輸入調度模組當中「用來規定當 IMK 接受按鍵訊號時且首次交給輸入調度模組處理時、
/// 輸入調度模組要率先處理」的部分。據此判斷是否需要將按鍵處理委派給其它成員函式。

import Carbon
import Foundation

// MARK: - § 根據狀態調度按鍵輸入 (Handle Input with States)

extension InputHandler {
  /// 對於輸入訊號的第一關處理均藉由此函式來進行。
  /// - Remark: 送入該函式處理之前，先用 inputHandler?.handleEvent() 分診、來判斷是否需要交給 IMKCandidates 處理。
  /// - Parameters:
  ///   - input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  func handleInput(event input: InputSignalProtocol) -> Bool {
    // 如果按鍵訊號內的 inputTest 是空的話，則忽略該按鍵輸入，因為很可能是功能修飾鍵。
    // 不處理任何包含不可列印字元的訊號。
    // delegate 必須存在，否則不處理。
    guard !input.text.isEmpty, input.charCode.isPrintable, let delegate = delegate else { return false }

    let inputText: String = input.text
    var state: IMEStateProtocol { delegate.state }  // 常數轉變數。

    // 提前放行一些用不到的特殊按鍵輸入情形。
    if input.isInvalid, state.type == .ofEmpty || state.type == .ofDeactivated { return false }

    // 如果當前組字器為空的話，就不再攔截某些修飾鍵，畢竟這些鍵可能會會用來觸發某些功能。
    let isFunctionKey: Bool =
      input.isControlHotKey || (input.isCommandHold || input.isOptionHotKey || input.isNonLaptopFunctionKey)
    if state.type != .ofAssociates, !state.hasComposition, !state.isCandidateContainer, isFunctionKey {
      return false
    }

    // MARK: Caps Lock 處理

    /// 若 Caps Lock 被啟用的話，則暫停對注音輸入的處理。
    /// 這裡的處理仍舊有用，不然 Caps Lock 英文模式無法直接鍵入小寫字母。
    if input.isCapsLockOn || delegate.isASCIIMode {
      // 低於 macOS 12 的系統無法偵測 CapsLock 的啟用狀態，所以這裡一律強制重置狀態為 .ofEmpty()。
      delegate.switchState(IMEState.ofEmpty())

      // 字母鍵摁 Shift 的話，無須額外處理，因為直接就會敲出大寫字母。
      if (input.isUpperCaseASCIILetterKey && delegate.isASCIIMode)
        || (input.isCapsLockOn && input.isShiftHold)
      {
        return false
      }

      /// 如果是 ASCII 當中的不可列印的字元的話，不使用「insertText:replacementRange:」。
      /// 某些應用無法正常處理非 ASCII 字符的輸入。
      if input.isASCII, !input.charCode.isPrintableASCII { return false }

      // 將整個組字區的內容遞交給客體應用。
      delegate.switchState(IMEState.ofCommitting(textToCommit: inputText.lowercased()))

      return true
    }

    // MARK: 處理數字小鍵盤 (Numeric Pad Processing)

    // 這裡的「isNumericPadKey」處理邏輯已經改成用 KeyCode 判定數字鍵區輸入、以鎖定按鍵範圍。
    // 不然、使用 Cocoa 內建的 flags 的話，會誤傷到在主鍵盤區域的功能鍵。
    // 我們先規定允許小鍵盤區域操縱選字窗，其餘場合一律直接放行。
    if input.isNumericPadKey {
      if ![.ofCandidates, .ofAssociates, .ofSymbolTable].contains(state.type) {
        delegate.switchState(IMEState.ofEmpty())
        delegate.switchState(IMEState.ofCommitting(textToCommit: inputText.lowercased()))
        return true
      }
    }

    // MARK: 處理候選字詞 (Handle Candidates)

    if [.ofCandidates, .ofSymbolTable].contains(state.type) { return handleCandidate(input: input) }

    // MARK: 處理聯想詞 (Handle Associated Phrases)

    if state.type == .ofAssociates {
      if handleCandidate(input: input) {
        return true
      } else {
        delegate.switchState(IMEState.ofEmpty())
      }
    }

    // MARK: 處理標記範圍、以便決定要把哪個範圍拿來新增使用者(濾除)語彙 (Handle Marking)

    if state.type == .ofMarking {
      if handleMarkingState(input: input) { return true }
      delegate.switchState(state.convertedToInputting)
    }

    // MARK: 注音按鍵輸入處理 (Handle BPMF Keys)

    if let compositionHandled = handleComposition(input: input) { return compositionHandled }

    // MARK: 用上下左右鍵呼叫選字窗 (Calling candidate window using Up / Down or PageUp / PageDn.)

    // 僅憑藉 state.hasComposition 的話，並不能真實把握組字器的狀況。
    // 另外，這裡不要用「!input.isFunctionKeyHold」，否則會導致對上下左右鍵與翻頁鍵的判斷失效。
    if state.hasComposition, !compositor.isEmpty, isComposerOrCalligrapherEmpty,
      !input.isOptionHold, !input.isShiftHold, !input.isCommandHold, !input.isControlHold,
      input.isCursorClockLeft || input.isCursorClockRight || (input.isSpace && prefs.chooseCandidateUsingSpace)
        || input.isPageDown || input.isPageUp || (input.isTab && prefs.specifyShiftTabKeyBehavior)
    {
      // 開始決定是否切換至選字狀態。
      let candidateState: IMEStateProtocol = generateStateOfCandidates()
      _ = candidateState.candidates.isEmpty ? delegate.callError("3572F238") : delegate.switchState(candidateState)
      return true
    }

    // MARK: Ctrl+Command+[] 輪替候選字

    // Shift+Command+[] 被 Chrome 系瀏覽器佔用，所以改用 Ctrl。
    revolveCandidateWithBrackets: if input.modifierFlags == [.control, .command] {
      if state.type != .ofInputting { break revolveCandidateWithBrackets }
      // 此處 JIS 鍵盤判定無法用於螢幕鍵盤。所以，螢幕鍵盤的場合，系統會依照 US 鍵盤的判定方案。
      let isJIS: Bool = KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS
      switch (input.keyCode, isJIS) {
        case (30, true): return revolveCandidate(reverseOrder: true)
        case (42, true): return revolveCandidate(reverseOrder: false)
        case (33, false): return revolveCandidate(reverseOrder: true)
        case (30, false): return revolveCandidate(reverseOrder: false)
        default: break
      }
    }

    // MARK: 批次集中處理某些常用功能鍵

    if let keyCodeType = KeyCode(rawValue: input.keyCode) {
      switch keyCodeType {
        case .kEscape: return handleEsc()
        case .kTab, .kContextMenu: return revolveCandidate(reverseOrder: input.isShiftHold)
        case .kUpArrow, .kDownArrow, .kLeftArrow, .kRightArrow:
          let rotation: Bool = (input.isOptionHold || input.isShiftHold) && state.type == .ofInputting
          handleArrowKey: switch (keyCodeType, delegate.isVerticalTyping) {
            case (.kLeftArrow, false), (.kUpArrow, true): return handleBackward(input: input)
            case (.kRightArrow, false), (.kDownArrow, true): return handleForward(input: input)
            case (.kUpArrow, false), (.kLeftArrow, true):
              return rotation ? revolveCandidate(reverseOrder: true) : handleClockKey()
            case (.kDownArrow, false), (.kRightArrow, true):
              return rotation ? revolveCandidate(reverseOrder: false) : handleClockKey()
            default: break handleArrowKey  // 該情況應該不會發生，因為上面都有處理過。
          }
        case .kHome: return handleHome()
        case .kEnd: return handleEnd()
        case .kBackSpace: return handleBackSpace(input: input)
        case .kWindowsDelete: return handleDelete(input: input)
        case .kCarriageReturn, .kLineFeed: return handleEnter(input: input)
        case .kSpace:  // 倘若沒有在偏好設定內將 Space 空格鍵設為選字窗呼叫用鍵的話………
          // 空格字符輸入行為處理。
          switch state.type {
            case .ofEmpty:
              if !input.isOptionHold, !input.isControlHold, !input.isCommandHold {
                delegate.switchState(IMEState.ofCommitting(textToCommit: input.isShiftHold ? "　" : " "))
                return true
              }
            case .ofInputting:
              // 臉書等網站會攔截 Tab 鍵，所以用 Shift+Command+Space 對候選字詞做正向/反向輪替。
              if input.isShiftHold, !input.isControlHold, !input.isOptionHold {
                return revolveCandidate(reverseOrder: input.isCommandHold)
              }
              if compositor.cursor < compositor.length, compositor.insertKey(" ") {
                walk()
                // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
                let textToCommit = commitOverflownComposition
                var inputting = generateStateOfInputting()
                inputting.textToCommit = textToCommit
                delegate.switchState(inputting)
              } else {
                let displayedText = state.displayedText
                if !displayedText.isEmpty {
                  delegate.switchState(IMEState.ofCommitting(textToCommit: displayedText))
                }
                delegate.switchState(IMEState.ofCommitting(textToCommit: " "))
              }
              return true
            default: break
          }
        default: break
      }
    }

    // MARK: Punctuation list

    if input.isSymbolMenuPhysicalKey, !input.isShiftHold, !input.isControlHold, state.type != .ofDeactivated {
      if input.isOptionHold {
        if currentLM.hasUnigramsFor(keyArray: ["_punctuation_list"]) {
          if isComposerOrCalligrapherEmpty, compositor.insertKey("_punctuation_list") {
            walk()
            // 一邊吃一邊屙（僅對位列黑名單的 App 用這招限制組字區長度）。
            let textToCommit = commitOverflownComposition
            var inputting = generateStateOfInputting()
            inputting.textToCommit = textToCommit
            delegate.switchState(inputting)
            // 開始決定是否切換至選字狀態。
            let newState = generateStateOfCandidates()
            _ = newState.candidates.isEmpty ? delegate.callError("B5127D8A") : delegate.switchState(newState)
          } else {  // 不要在注音沒敲完整的情況下叫出統合符號選單。
            delegate.callError("17446655")
          }
          return true
        } else {
          let errorMessage =
            NSLocalizedString(
              "Please manually implement the symbols of this menu \nin the user phrase file with “_punctuation_list” key.",
              comment: ""
            )
          vCLog("8EB3FB1A: " + errorMessage)
          delegate.switchState(IMEState.ofEmpty())
          let isJIS: Bool = input.keyCode == KeyCode.kSymbolMenuPhysicalKeyJIS.rawValue
          delegate.switchState(IMEState.ofCommitting(textToCommit: isJIS ? "_" : "`"))
          return true
        }
      } else {
        // 得在這裡先 commit buffer，不然會導致「在摁 ESC 離開符號選單時會重複輸入上一次的組字區的內容」的不當行為。
        delegate.switchState(IMEState.ofCommitting(textToCommit: state.displayedText))
        delegate.switchState(IMEState.ofSymbolTable(node: CandidateNode.root))
        return true
      }
    }

    // MARK: 全形/半形阿拉伯數字輸入 (FW / HW Arabic Numbers Input)

    if state.type == .ofEmpty {
      if input.isMainAreaNumKey, input.modifierFlags == [.shift, .option] {
        // NOTE: 將來棄用 macOS 10.11 El Capitan 支援的時候，把這裡由 CFStringTransform 改為 StringTransform:
        // https://developer.apple.com/documentation/foundation/stringtransform
        guard let stringRAW = input.mainAreaNumKeyChar else { return false }
        let string = NSMutableString(string: stringRAW)
        CFStringTransform(string, nil, kCFStringTransformFullwidthHalfwidth, true)
        delegate.switchState(
          IMEState.ofCommitting(textToCommit: prefs.halfWidthPunctuationEnabled ? stringRAW : string as String)
        )
        return true
      }
    }

    // MARK: Punctuation

    /// 如果仍無匹配結果的話，先看一下：
    /// - 是否是針對當前注音排列/拼音輸入種類專門提供的標點符號。
    /// - 是否是需要摁修飾鍵才可以輸入的那種標點符號。
    let punctuationNamePrefix: String = generatePunctuationNamePrefix(withKeyCondition: input)
    let parser = currentKeyboardParser
    let arrCustomPunctuations: [String] = [punctuationNamePrefix, parser, input.text]
    let customPunctuation: String = arrCustomPunctuations.joined()
    if handlePunctuation(customPunctuation) { return true }
    /// 如果仍無匹配結果的話，看看這個輸入是否是不需要修飾鍵的那種標點鍵輸入。
    let arrPunctuations: [String] = [punctuationNamePrefix, input.text]
    let punctuation: String = arrPunctuations.joined()
    if handlePunctuation(punctuation) { return true }

    // MARK: 摁住 Shift+字母鍵 的處理 (Shift+Letter Processing)

    if input.isUpperCaseASCIILetterKey, !input.isCommandHold, !input.isControlHold {
      if input.isShiftHold {  // 這裡先不要判斷 isOptionHold。
        switch prefs.upperCaseLetterKeyBehavior {
          case 1:
            delegate.switchState(IMEState.ofEmpty())
            delegate.switchState(IMEState.ofCommitting(textToCommit: inputText.lowercased()))
            return true
          case 2:
            delegate.switchState(IMEState.ofEmpty())
            delegate.switchState(IMEState.ofCommitting(textToCommit: inputText.uppercased()))
            return true
          default:  // 包括 case 0，直接塞給組字區。
            let letter = "_letter_\(inputText)"
            if handlePunctuation(letter) {
              return true
            }
        }
      }
    }

    // MARK: - 終末處理 (Still Nothing)

    /// 對剩下的漏網之魚做攔截處理、直接將當前狀態繼續回呼給 SessionCtl。
    /// 否則的話，可能會導致輸入法行為異常：部分應用會阻止輸入法完全攔截某些按鍵訊號。
    /// 砍掉這一段會導致「F1-F12 按鍵干擾組字區」的問題。
    /// 暫時只能先恢復這段，且補上偵錯彙報機制，方便今後排查故障。
    if state.hasComposition || !isComposerOrCalligrapherEmpty {
      delegate.callError("Blocked data: charCode: \(input.charCode), keyCode: \(input.keyCode), text: \(input.text)")
      delegate.callError("A9BFF20E")
      return true
    }

    return false
  }
}
