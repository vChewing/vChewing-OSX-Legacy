// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - SettingsPanesCocoa

public final class SettingsPanesCocoa {
  /// 視窗內容寬度：非中文/日文 UI（即英文 UI）時，因英文文字較長、額外再加寬。
  public static let windowWidth: CGFloat = {
    let isEnglishUI: Bool = {
      guard let lang = UserDefaults.current.stringArray(forKey: "AppleLanguages")?.first else {
        return true
      }
      return !(lang.hasPrefix("zh") || lang.hasPrefix("ja"))
    }()
    return 634 + (isEnglishUI ? 80 : 0)
  }()

  public static var contentWidth: CGFloat { windowWidth - 65 }
  public static var innerContentWidth: CGFloat { contentWidth - 37 }
  public static var tabContainerWidth: CGFloat { contentWidth + 20 }
  // 此值必須等於 buildSection(.horizontal, width:) 的單欄實得寬（(width−4)/2−6）；
  // 先前自訂為 contentWidth/2−4 會讓欄內 row 固定寬比欄寬多 4pt、觸發 Auto Layout 衝突。
  public static var contentHalfWidth: CGFloat { (contentWidth - 4) / 2 - 6 }

  public let ctlPageAbout = SettingsPanesCocoa.About()
  public let ctlPageGeneral = SettingsPanesCocoa.General()
  public let ctlPageCandidates = SettingsPanesCocoa.Candidates()
  public let ctlPageBehavior = SettingsPanesCocoa.Behavior()
  public let ctlPageOutput = SettingsPanesCocoa.Output()
  public let ctlPageDictionary = SettingsPanesCocoa.Dictionary()
  public let ctlPagePhrases = SettingsPanesCocoa.Phrases()
  public let ctlPageCassette = SettingsPanesCocoa.Cassette()
  public let ctlPageKeyboard = SettingsPanesCocoa.Keyboard()
  public let ctlPageClients = SettingsPanesCocoa.Clients()
  public let ctlPageServices = SettingsPanesCocoa.Services()
  public let ctlPageDevZone = SettingsPanesCocoa.DevZone()
}

extension SettingsPanesCocoa {
  public func preload() {
    ctlPageGeneral.loadView()
    ctlPageCandidates.loadView()
    ctlPageBehavior.loadView()
    ctlPageOutput.loadView()
    ctlPageDictionary.loadView()
    // Phrases 刻意不預載：開窗即全文載入詞庫文字徒增記憶體，改由首次造訪該頁才載入（與 About 同例）。
    ctlPageCassette.loadView()
    ctlPageKeyboard.loadView()
    ctlPageClients.loadView()
    ctlPageServices.loadView()
    ctlPageDevZone.loadView()
  }

  public static func warnAboutComDlg32Inavailability() {
    let title = "i18n:ClientManager.DragTargetInstruction".i18n
    let message = "i18n:InfoMessage.TechnicalReasonNSOpenPanel".i18n
    CtlSettingsCocoa.shared?.window.callAlert(title: title, text: message)
  }
}
