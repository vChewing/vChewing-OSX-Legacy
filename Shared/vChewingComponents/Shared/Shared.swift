// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - UserDef Snapshot Manager

public enum UserDef: String, CaseIterable {
  case kIsDebugModeEnabled = "_DebugMode"
  case kFailureFlagForUOMObservation = "_FailureFlag_UOMObservation"
  case kDeltaOfCalendarYears = "DeltaOfCalendarYears"
  case kMostRecentInputMode = "MostRecentInputMode"
  case kCassettePath = "CassettePath"
  case kUserDataFolderSpecified = "UserDataFolderSpecified"
  case kCheckUpdateAutomatically = "CheckUpdateAutomatically"
  case kUseExternalFactoryDict = "UseExternalFactoryDict"
  case kKeyboardParser = "KeyboardParser"
  case kBasicKeyboardLayout = "BasicKeyboardLayout"
  case kAlphanumericalKeyboardLayout = "AlphanumericalKeyboardLayout"
  case kShowNotificationsWhenTogglingCapsLock = "ShowNotificationsWhenTogglingCapsLock"
  case kCandidateListTextSize = "CandidateListTextSize"
  case kAlwaysExpandCandidateWindow = "AlwaysExpandCandidateWindow"
  case kCandidateWindowShowOnlyOneLine = "CandidateWindowShowOnlyOneLine"
  case kAppleLanguages = "AppleLanguages"
  case kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
  case kUseRearCursorMode = "UseRearCursorMode"
  case kUseDynamicCandidateWindowOrigin = "UseDynamicCandidateWindowOrigin"
  case kUseHorizontalCandidateList = "UseHorizontalCandidateList"
  case kChooseCandidateUsingSpace = "ChooseCandidateUsingSpace"
  case kCassetteEnabled = "CassetteEnabled"
  case kCNS11643Enabled = "CNS11643Enabled"
  case kSymbolInputEnabled = "SymbolInputEnabled"
  case kChineseConversionEnabled = "ChineseConversionEnabled"
  case kShiftJISShinjitaiOutputEnabled = "ShiftJISShinjitaiOutputEnabled"
  case kCurrencyNumeralsEnabled = "CurrencyNumeralsEnabled"
  case kHalfWidthPunctuationEnabled = "HalfWidthPunctuationEnable"
  case kMoveCursorAfterSelectingCandidate = "MoveCursorAfterSelectingCandidate"
  case kEscToCleanInputBuffer = "EscToCleanInputBuffer"
  case kAcceptLeadingIntonations = "AcceptLeadingIntonations"
  case kSpecifyIntonationKeyBehavior = "SpecifyIntonationKeyBehavior"
  case kSpecifyShiftBackSpaceKeyBehavior = "SpecifyShiftBackSpaceKeyBehavior"
  case kSpecifyShiftTabKeyBehavior = "SpecifyShiftTabKeyBehavior"
  case kSpecifyShiftSpaceKeyBehavior = "SpecifyShiftSpaceKeyBehavior"
  case kAllowBoostingSingleKanjiAsUserPhrase = "AllowBoostingSingleKanjiAsUserPhrase"
  case kUseSCPCTypingMode = "UseSCPCTypingMode"
  case kMaxCandidateLength = "MaxCandidateLength"
  case kShouldNotFartInLieuOfBeep = "ShouldNotFartInLieuOfBeep"
  case kShowHanyuPinyinInCompositionBuffer = "ShowHanyuPinyinInCompositionBuffer"
  case kInlineDumpPinyinInLieuOfZhuyin = "InlineDumpPinyinInLieuOfZhuyin"
  case kFetchSuggestionsFromUserOverrideModel = "FetchSuggestionsFromUserOverrideModel"
  case kUseFixedCandidateOrderOnSelection = "UseFixedCandidateOrderOnSelection"
  case kAutoCorrectReadingCombination = "AutoCorrectReadingCombination"
  case kAlsoConfirmAssociatedCandidatesByEnter = "AlsoConfirmAssociatedCandidatesByEnter"
  case kKeepReadingUponCompositionError = "KeepReadingUponCompositionError"
  case kTogglingAlphanumericalModeWithLShift = "TogglingAlphanumericalModeWithLShift"
  case kUpperCaseLetterKeyBehavior = "UpperCaseLetterKeyBehavior"
  case kDisableShiftTogglingAlphanumericalMode = "DisableShiftTogglingAlphanumericalMode"
  case kConsolidateContextOnCandidateSelection = "ConsolidateContextOnCandidateSelection"
  case kHardenVerticalPunctuations = "HardenVerticalPunctuations"
  case kTrimUnfinishedReadingsOnCommit = "TrimUnfinishedReadingsOnCommit"
  case kAlwaysShowTooltipTextsHorizontally = "AlwaysShowTooltipTextsHorizontally"
  case kClientsIMKTextInputIncapable = "ClientsIMKTextInputIncapable"
  case kOnlyLoadFactoryLangModelsIfNeeded = "OnlyLoadFactoryLangModelsIfNeeded"
  case kShowTranslatedStrokesInCompositionBuffer = "ShowTranslatedStrokesInCompositionBuffer"
  case kForceCassetteChineseConversion = "ForceCassetteChineseConversion"
  case kShowReverseLookupInCandidateUI = "ShowReverseLookupInCandidateUI"
  case kAutoCompositeWithLongestPossibleCassetteKey = "AutoCompositeWithLongestPossibleCassetteKey"
  case kShareAlphanumericalModeStatusAcrossClients = "ShareAlphanumericalModeStatusAcrossClients"
  case kPhraseEditorAutoReloadExternalModifications = "PhraseEditorAutoReloadExternalModifications"
  case kClassicHaninKeyboardSymbolModeShortcutEnabled = "ClassicHaninKeyboardSymbolModeShortcutEnabled"

  case kUseSpaceToCommitHighlightedSCPCCandidate = "UseSpaceToCommitHighlightedSCPCCandidate"
  case kEnableSwiftUIForTDKCandidates = "EnableSwiftUIForTDKCandidates"
  case kEnableMouseScrollingForTDKCandidatesCocoa = "EnableMouseScrollingForTDKCandidatesCocoa"
  case kDisableSegmentedThickUnderlineInMarkingModeForManagedClients
    = "DisableSegmentedThickUnderlineInMarkingModeForManagedClients"

  case kCandidateTextFontName = "CandidateTextFontName"
  case kCandidateKeys = "CandidateKeys"

  case kAssociatedPhrasesEnabled = "AssociatedPhrasesEnabled"
  case kPhraseReplacementEnabled = "PhraseReplacementEnabled"

  case kUsingHotKeySCPC = "UsingHotKeySCPC"
  case kUsingHotKeyAssociates = "UsingHotKeyAssociates"
  case kUsingHotKeyCNS = "UsingHotKeyCNS"
  case kUsingHotKeyKangXi = "UsingHotKeyKangXi"
  case kUsingHotKeyJIS = "UsingHotKeyJIS"
  case kUsingHotKeyHalfWidthASCII = "UsingHotKeyHalfWidthASCII"
  case kUsingHotKeyCurrencyNumerals = "UsingHotKeyCurrencyNumerals"
  case kUsingHotKeyCassette = "UsingHotKeyCassette"
  case kUsingHotKeyRevLookup = "UsingHotKeyRevLookup"
  case kUsingHotKeyInputMode = "UsingHotKeyInputMode"

  public static func resetAll() {
    UserDef.allCases.forEach {
      UserDefaults.current.removeObject(forKey: $0.rawValue)
    }
  }

  public static func load(from snapshot: Snapshot) {
    let data = snapshot.data
    guard !data.isEmpty else { return }
    UserDef.allCases.forEach {
      UserDefaults.current.set(data[$0.rawValue], forKey: $0.rawValue)
    }
  }

  public struct Snapshot {
    public var data: [String: Any] = [:]
    public init() {
      UserDef.allCases.forEach {
        data[$0.rawValue] = UserDefaults.current.object(forKey: $0.rawValue)
      }
    }
  }
}

// MARK: - Tooltip Color States

public enum TooltipColorState {
  case normal
  case redAlert
  case warning
  case denialOverflow
  case denialInsufficiency
  case prompt
  case succeeded
}

// MARK: - IMEState types.

/// 用以讓每個狀態自描述的 enum。
public enum StateType: String {
  /// **失活狀態 .ofDeactivated**: 使用者沒在使用輸入法、或者使用者已經切換到另一個客體應用來敲字。
  case ofDeactivated = "Deactivated"
  /// **空狀態 .ofEmpty**: 使用者剛剛切換至該輸入法、卻還沒有任何輸入行為。
  /// 抑或是剛剛敲字遞交給客體應用、準備新的輸入行為。
  /// 威注音輸入法在「組字區與組音區/組筆區同時為空」、
  /// 且客體軟體正在準備接收使用者文字輸入行為的時候，會處於空狀態。
  /// 有時，威注音會利用呼叫空狀態的方式，讓組字區內已經顯示出來的內容遞交出去。
  case ofEmpty = "Empty"
  /// **中絕狀態 .ofAbortion**: 與 .ofEmpty() 類似，但會扔掉上一個狀態的內容、
  /// 不將這些內容遞交給客體應用。該狀態在處理完畢之後會被立刻切換至 .ofEmpty()。
  case ofAbortion = "Abortion"
  /// **遞交狀態 .ofCommitting**: 該狀態會承載要遞交出去的內容，讓輸入法控制器處理時代為遞交。
  /// 該狀態在處理完畢之後會被立刻切換至 .ofEmpty()。如果直接呼叫處理該狀態的話，
  /// 在呼叫處理之前的組字區的內容會消失，除非你事先呼叫處理過 .ofEmpty()。
  case ofCommitting = "Committing"
  /// **聯想詞狀態 .ofAssociates**: 逐字選字模式內的聯想詞輸入狀態。
  case ofAssociates = "Associates"
  /// **輸入狀態 .ofInputting**: 使用者輸入了內容。此時會出現組字區（Compositor）。
  case ofInputting = "Inputting"
  /// **標記狀態 .ofMarking**: 使用者在組字區內標記某段範圍，
  /// 可以決定是添入新詞、還是將這個範圍的詞音組合放入語彙濾除清單。
  case ofMarking = "Marking"
  /// **選字狀態 .ofCandidates**: 叫出選字窗、允許使用者選字。
  case ofCandidates = "Candidates"
  /// **分類分層符號表狀態 .ofSymbolTable**: 分類分層符號表選單專用的狀態，有自身的特殊處理。
  case ofSymbolTable = "SymbolTable"
}

// MARK: - Parser for Syllable composer

public enum KeyboardParser: Int, CaseIterable {
  case ofStandard = 0
  case ofETen = 1
  case ofIBM = 4
  case ofMiTAC = 5
  case ofSeigyou = 8
  case ofFakeSeigyou = 6
  case ofDachen26 = 7
  case ofETen26 = 3
  case ofHsu = 2
  case ofStarlight = 9
  case ofAlvinLiu = 10
  case ofHanyuPinyin = 100
  case ofSecondaryPinyin = 101
  case ofYalePinyin = 102
  case ofHualuoPinyin = 103
  case ofUniversalPinyin = 104
  case ofWadeGilesPinyin = 105

  public var localizedMenuName: String {
    let rawString: String = {
      switch self {
      case .ofStandard: return "Dachen (Microsoft Standard / Wang / 01, etc.)"
      case .ofETen: return "Eten Traditional"
      case .ofIBM: return "IBM"
      case .ofMiTAC: return "MiTAC"
      case .ofSeigyou: return "Seigyou"
      case .ofFakeSeigyou: return "Fake Seigyou"
      case .ofDachen26: return "Dachen 26 (libChewing)"
      case .ofETen26: return "Eten 26"
      case .ofHsu: return "Hsu"
      case .ofStarlight: return "Starlight"
      case .ofAlvinLiu: return "Alvin Liu (Imitative)"
      case .ofHanyuPinyin: return "Hanyu Pinyin with Numeral Intonation"
      case .ofSecondaryPinyin: return "Secondary Pinyin with Numeral Intonation"
      case .ofYalePinyin: return "Yale Pinyin with Numeral Intonation"
      case .ofHualuoPinyin: return "Hualuo Pinyin with Numeral Intonation"
      case .ofUniversalPinyin: return "Universal Pinyin with Numeral Intonation"
      case .ofWadeGilesPinyin: return "Wade-Giles Pinyin with Numeral Intonation"
      }
    }()
    return NSLocalizedString(rawString, comment: "")
  }

  public var name: String {
    switch self {
    case .ofStandard:
      return "Standard"
    case .ofETen:
      return "ETen"
    case .ofHsu:
      return "Hsu"
    case .ofETen26:
      return "ETen26"
    case .ofIBM:
      return "IBM"
    case .ofMiTAC:
      return "MiTAC"
    case .ofFakeSeigyou:
      return "FakeSeigyou"
    case .ofDachen26:
      return "Dachen26"
    case .ofSeigyou:
      return "Seigyou"
    case .ofStarlight:
      return "Starlight"
    case .ofAlvinLiu:
      return "AlvinLiu"
    case .ofHanyuPinyin:
      return "HanyuPinyin"
    case .ofSecondaryPinyin:
      return "SecondaryPinyin"
    case .ofYalePinyin:
      return "YalePinyin"
    case .ofHualuoPinyin:
      return "HualuoPinyin"
    case .ofUniversalPinyin:
      return "UniversalPinyin"
    case .ofWadeGilesPinyin:
      return "WadeGilesPinyin"
    }
  }
}

public enum CandidateKey {
  public static var defaultKeys: String { suggestions[0] }
  public static let suggestions: [String] = [
    "123456", "123456789", "234567890", "QWERTYUIO", "QWERTASDF", "ASDFGHJKL", "ASDFZXCVB",
  ]

  /// 僅列舉那些需要專門檢查才能發現的那種無法自動排除的錯誤。
  public enum ValidationError {
    case noError
    case invalidCharacters
    case countMismatch

    public var description: String {
      switch self {
      case .invalidCharacters:
        return "- "
          + NSLocalizedString(
            "Candidate keys can only contain printable ASCII characters like alphanumericals.",
            comment: ""
          ) + "\n" + "- " + NSLocalizedString("Candidate keys cannot contain space.", comment: "")
      case .countMismatch:
        return "- "
          + NSLocalizedString(
            "Minimum 6 candidate keys allowed.", comment: ""
          ) + "\n" + "- " + NSLocalizedString("Maximum 10 candidate keys allowed.", comment: "")
      case .noError:
        return ""
      }
    }
  }

  /// 校驗選字鍵參數資料值的合法性。
  /// - Remark: 傳入的參數值得事先做過下述處理：
  /// ```
  /// .trimmingCharacters(in: .whitespacesAndNewlines).deduplicated
  /// ```
  /// - Parameter candidateKeys: 傳入的參數值
  /// - Returns: 返回 nil 的話，證明沒有錯誤；否則會返回錯誤描述訊息。
  public static func validate(keys candidateKeys: String) -> String? {
    var result = ValidationError.noError
    charValidityCheck: for neta in candidateKeys {
      if String(neta) == " " {
        result = CandidateKey.ValidationError.invalidCharacters
        break charValidityCheck
      }
      for subNeta in neta.unicodeScalars {
        if !subNeta.isPrintableASCII {
          result = CandidateKey.ValidationError.invalidCharacters
          break charValidityCheck
        }
      }
    }
    if !(6 ... 10).contains(candidateKeys.count) {
      result = CandidateKey.ValidationError.countMismatch
    }
    return result == ValidationError.noError ? nil : result.description
  }
}

public func vCLog(_ strPrint: StringLiteralType) {
  if UserDefaults.current.bool(forKey: "_DebugMode") {
    NSLog("vChewingDebug: %@", strPrint)
  }
}

public enum Shared {
  // Supported locales.
  public static let arrSupportedLocales: [String] = ["en", "zh-Hant", "zh-Hans", "ja"]

  // The type of input modes.
  public enum InputMode: String, CaseIterable, Identifiable {
    public var id: ObjectIdentifier { .init(rawValue as AnyObject) }
    case imeModeCHS = "org.atelierInmu.inputmethod.vChewing.IMECHS"
    case imeModeCHT = "org.atelierInmu.inputmethod.vChewing.IMECHT"
    case imeModeNULL = ""
    public var reversed: Shared.InputMode {
      switch self {
      case .imeModeCHS:
        return .imeModeCHT
      case .imeModeCHT:
        return .imeModeCHS
      case .imeModeNULL:
        return .imeModeNULL
      }
    }

    public var localizedDescription: String { NSLocalizedString(description, comment: "") }
    public var description: String {
      switch self {
      case .imeModeCHS:
        return "Simplified Chinese"
      case .imeModeCHT:
        return "Traditional Chinese"
      case .imeModeNULL:
        return "Please select…"
      }
    }
  }
}

// MARK: - Observable Object

@available(macOS 10.15, *)
public class FileObserveProject: ObservableObject, Equatable {
  public static let shared = FileObserveProject()
  @Published public var id = UUID().uuidString

  public static func == (lhs: FileObserveProject, rhs: FileObserveProject) -> Bool { lhs.id == rhs.id }

  public func touch() {
    id = UUID().uuidString
  }
}
