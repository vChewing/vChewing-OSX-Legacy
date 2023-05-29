// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - IMKCandidates 功能擴充

public extension SessionCtl {
  /// 生成 IMK 選字窗專用的候選字串陣列。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: IMK 選字窗專用的候選字串陣列。
  override func candidates(_ sender: Any!) -> [Any]! {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    var arrResult = [String]()

    // 注意：下文中的不可列印字元是用來方便在 IMEState 當中用來分割資料的。
    func handleIMKCandidatesPrepared(
      _ candidates: [(keyArray: [String], value: String)], prefix: String = ""
    ) {
      guard let separator = inputHandler?.keySeparator else { return }
      for theCandidate in candidates {
        let theConverted = ChineseConverter.kanjiConversionIfRequired(theCandidate.value)
        var result = (theCandidate.value == theConverted) ? theCandidate.value : "\(theConverted)\u{1A}(\(theCandidate.value))"
        if arrResult.contains(result) {
          let reading: String =
            PrefMgr.shared.cassetteEnabled
              ? theCandidate.keyArray.joined(separator: separator)
              : (PrefMgr.shared.showHanyuPinyinInCompositionBuffer
                ? Tekkon.cnvPhonaToHanyuPinyin(
                  targetJoined: {
                    var arr = [String]()
                    theCandidate.keyArray.forEach { key in
                      arr.append(Tekkon.restoreToneOneInPhona(target: key))
                    }
                    return arr.joined(separator: "-")
                  }()
                )
                : theCandidate.keyArray.joined(separator: separator))
          result = "\(result)\u{17}(\(reading))"
        }
        arrResult.append(prefix + result)
      }
    }

    if state.type == .ofAssociates {
      handleIMKCandidatesPrepared(state.candidates, prefix: "⇧")
    } else if state.type == .ofSymbolTable {
      // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
      arrResult = state.candidates.map(\.value)
    } else if state.type == .ofCandidates {
      guard !state.candidates.isEmpty else { return .init() }
      if state.candidates[0].keyArray.joined(separator: "-").contains("_punctuation") {
        arrResult = state.candidates.map(\.value) // 標點符號選單處理。
      } else {
        handleIMKCandidatesPrepared(state.candidates)
      }
    }

    return arrResult
  }

  /// IMK 選字窗限定函式，只要選字窗內的高亮內容選擇出現變化了、就會呼叫這個函式。
  /// - Parameter currentSelection: 已經高亮選中的候選字詞內容。
  override func candidateSelectionChanged(_ currentSelection: NSAttributedString!) {
    guard let candidateString = currentSelection?.string, !candidateString.isEmpty else { return }
    // Handle candidatePairHighlightChanged().
    var indexDeducted = 0
    fixIndexForIMKCandidates(&indexDeducted, source: candidateString)
    if state.type == .ofCandidates {
      candidatePairHighlightChanged(at: indexDeducted)
    }
    let realCandidateString = state.candidates[indexDeducted].value
    // Handle IMK Annotation... We just use this to tell Apple that this never works in IMKCandidates.
    DispatchQueue.main.async { [self] in
      let annotation = reverseLookup(for: candidateString).joined(separator: "\n")
      guard !annotation.isEmpty else { return }
      vCLog("Current Annotation: \(annotation)")
      guard let imkCandidates = candidateUI as? CtlCandidateIMK else { return }
      annotationSelected(.init(string: annotation), forCandidate: .init(string: realCandidateString))
      imkCandidates.showAnnotation(.init(string: annotation))
    }
  }

  /// IMK 選字窗限定函式，只要選字窗確認了某個候選字詞的選擇、就會呼叫這個函式。
  /// - Remark: 不要被 IMK 的 API 命名方式困惑到。這其實是 Confirm Selection 確認選字。
  /// - Parameter candidateString: 已經確認的候選字詞內容。
  override func candidateSelected(_ candidateString: NSAttributedString!) {
    let candidateString: String = candidateString?.string ?? ""
    if state.type == .ofAssociates {
      // 聯想詞的 Shift+選字鍵的處理已經在其它位置實作完成。
      if !PrefMgr.shared.alsoConfirmAssociatedCandidatesByEnter {
        switchState(IMEState.ofAbortion())
        return
      }
    }

    var indexDeducted = 0

    // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
    func fixSymbolIndexForIMKCandidates() {
      for (i, neta) in state.candidates.enumerated() {
        if candidateString == neta.value {
          indexDeducted = i
          break
        }
      }
    }

    if state.type == .ofAssociates {
      fixIndexForIMKCandidates(&indexDeducted, prefix: "⇧", source: candidateString)
    } else if state.type == .ofSymbolTable {
      fixSymbolIndexForIMKCandidates()
    } else if state.type == .ofCandidates {
      guard !state.candidates.isEmpty else { return }
      if state.candidates[0].keyArray.description.contains("_punctuation") {
        fixSymbolIndexForIMKCandidates() // 標點符號選單處理。
      } else {
        fixIndexForIMKCandidates(&indexDeducted, source: candidateString)
      }
    }
    candidatePairSelectionConfirmed(at: indexDeducted)
  }

  /// 解析 IMKCandidates 給出的資料參數，據此推算正確的被確認的候選字詞配對的編號。
  /// - Remark: 該函式當中的不可列印字元`\u{1A`是用來方便在 IMEState 當中用來分割資料的。
  /// - Parameters:
  ///   - prefix: 前綴（僅限於聯想詞模式）。
  ///   - indexToFix: 要糾正的編號變數。
  ///   - candidateString: IMKCandidates 給出的原始資料。
  private func fixIndexForIMKCandidates(
    _ indexDeducted: inout Int, prefix: String = "", source candidateString: String
  ) {
    guard let separator = inputHandler?.keySeparator else { return }
    let candidates = state.candidates
    for (i, neta) in candidates.enumerated() {
      let theConverted = ChineseConverter.kanjiConversionIfRequired(neta.value)
      let netaShown = (neta.value == theConverted)
        ? neta.value
        : "\(theConverted)\u{1A}(\(neta.value))"
      let reading: String =
        PrefMgr.shared.cassetteEnabled
          ? neta.keyArray.joined(separator: separator)
          : (PrefMgr.shared.showHanyuPinyinInCompositionBuffer
            ? Tekkon.cnvPhonaToHanyuPinyin(
              targetJoined: {
                var arr = [String]()
                neta.keyArray.forEach { key in
                  arr.append(Tekkon.restoreToneOneInPhona(target: key))
                }
                return arr.joined(separator: "-")
              }()
            )
            : neta.keyArray.joined(separator: separator))
      let netaShownWithPronunciation = "\(netaShown)\u{17}(\(reading))"
      if candidateString == prefix + netaShownWithPronunciation {
        indexDeducted = i
        break
      }
      if candidateString == prefix + netaShown {
        indexDeducted = i
        break
      }
    }
  }
}
