// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: -

public class PrefMgr: PrefMgrProtocol {
  public static let shared = PrefMgr()
  public static let kDefaultCandidateKeys = "123456"
  public static let kDefaultBasicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
  public static let kDefaultAlphanumericalKeyboardLayout = {
    if #available(macOS 10.13, *) {
      return "com.apple.keylayout.ABC"
    }
    return "com.apple.keylayout.US"
  }()

  public static let kDefaultClientsIMKTextInputIncapable: [String: Bool] = [
    "com.valvesoftware.steam": true, "jp.naver.line.mac": true,
  ]

  // MARK: - Settings (Tier 1)

  @AppProperty(key: UserDef.kIsDebugModeEnabled.rawValue, defaultValue: false)
  public var isDebugModeEnabled: Bool

  @AppProperty(key: UserDef.kFailureFlagForUOMObservation.rawValue, defaultValue: false)
  public var failureFlagForUOMObservation: Bool

  @AppProperty(key: UserDef.kFailureFlagForIMKCandidates.rawValue, defaultValue: false)
  public var failureFlagForIMKCandidates: Bool

  @AppProperty(key: UserDef.kDeltaOfCalendarYears.rawValue, defaultValue: -2000)
  public var deltaOfCalendarYears: Int

  @AppProperty(key: UserDef.kMostRecentInputMode.rawValue, defaultValue: "")
  public var mostRecentInputMode: String

  @AppProperty(key: UserDef.kCheckUpdateAutomatically.rawValue, defaultValue: false)
  public var checkUpdateAutomatically: Bool

  @AppProperty(key: UserDef.kUseExternalFactoryDict.rawValue, defaultValue: false)
  public var useExternalFactoryDict: Bool

  @AppProperty(key: UserDef.kCassettePath.rawValue, defaultValue: "")
  public var cassettePath: String

  @AppProperty(key: UserDef.kUserDataFolderSpecified.rawValue, defaultValue: "")
  public var userDataFolderSpecified: String

  @AppProperty(key: UserDef.kAppleLanguages.rawValue, defaultValue: [])
  public var appleLanguages: [String]

  @AppProperty(key: UserDef.kKeyboardParser.rawValue, defaultValue: 0)
  public var keyboardParser: Int

  @AppProperty(
    key: UserDef.kBasicKeyboardLayout.rawValue, defaultValue: kDefaultBasicKeyboardLayout
  )
  public var basicKeyboardLayout: String

  @AppProperty(
    key: UserDef.kAlphanumericalKeyboardLayout.rawValue, defaultValue: kDefaultAlphanumericalKeyboardLayout
  )
  public var alphanumericalKeyboardLayout: String

  @AppProperty(key: UserDef.kShowNotificationsWhenTogglingCapsLock.rawValue, defaultValue: true)
  public var showNotificationsWhenTogglingCapsLock: Bool

  @AppProperty(key: UserDef.kCandidateListTextSize.rawValue, defaultValue: 16)
  public var candidateListTextSize: Double {
    didSet {
      // 必須確立條件，否則就會是無限迴圈。
      if !(12 ... 196).contains(candidateListTextSize) {
        candidateListTextSize = max(12, min(candidateListTextSize, 196))
      }
    }
  }

  @AppProperty(key: UserDef.kCandidateWindowShowOnlyOneLine.rawValue, defaultValue: false)
  public var candidateWindowShowOnlyOneLine: Bool

  @AppProperty(key: UserDef.kShouldAutoReloadUserDataFiles.rawValue, defaultValue: true)
  public var shouldAutoReloadUserDataFiles: Bool

  @AppProperty(key: UserDef.kUseRearCursorMode.rawValue, defaultValue: false)
  public var useRearCursorMode: Bool

  @AppProperty(key: UserDef.kMoveCursorAfterSelectingCandidate.rawValue, defaultValue: true)
  public var moveCursorAfterSelectingCandidate: Bool

  @AppProperty(key: UserDef.kUseHorizontalCandidateList.rawValue, defaultValue: true)
  public var useHorizontalCandidateList: Bool

  @AppProperty(key: UserDef.kChooseCandidateUsingSpace.rawValue, defaultValue: true)
  public var chooseCandidateUsingSpace: Bool

  @AppProperty(key: UserDef.kAllowBoostingSingleKanjiAsUserPhrase.rawValue, defaultValue: false)
  public var allowBoostingSingleKanjiAsUserPhrase: Bool

  @AppProperty(key: UserDef.kFetchSuggestionsFromUserOverrideModel.rawValue, defaultValue: true)
  public var fetchSuggestionsFromUserOverrideModel: Bool

  @AppProperty(key: UserDef.kUseFixecCandidateOrderOnSelection.rawValue, defaultValue: false)
  public var useFixecCandidateOrderOnSelection: Bool

  @AppProperty(key: UserDef.kAutoCorrectReadingCombination.rawValue, defaultValue: true)
  public var autoCorrectReadingCombination: Bool

  @AppProperty(key: UserDef.kAlsoConfirmAssociatedCandidatesByEnter.rawValue, defaultValue: true)
  public var alsoConfirmAssociatedCandidatesByEnter: Bool

  @AppProperty(key: UserDef.kKeepReadingUponCompositionError.rawValue, defaultValue: false)
  public var keepReadingUponCompositionError: Bool

  @AppProperty(key: UserDef.kUpperCaseLetterKeyBehavior.rawValue, defaultValue: 0)
  public var upperCaseLetterKeyBehavior: Int

  /// Not available in this legacy version.
  @AppProperty(key: UserDef.kTogglingAlphanumericalModeWithLShift.rawValue, defaultValue: true)
  public var togglingAlphanumericalModeWithLShift: Bool

  @AppProperty(key: UserDef.kDisableShiftTogglingAlphanumericalMode.rawValue, defaultValue: false)
  public var disableShiftTogglingAlphanumericalMode: Bool

  @AppProperty(key: UserDef.kConsolidateContextOnCandidateSelection.rawValue, defaultValue: true)
  public var consolidateContextOnCandidateSelection: Bool

  @AppProperty(key: UserDef.kHardenVerticalPunctuations.rawValue, defaultValue: false)
  public var hardenVerticalPunctuations: Bool

  @AppProperty(key: UserDef.kTrimUnfinishedReadingsOnCommit.rawValue, defaultValue: true)
  public var trimUnfinishedReadingsOnCommit: Bool

  @AppProperty(key: UserDef.kAlwaysShowTooltipTextsHorizontally.rawValue, defaultValue: false)
  public var alwaysShowTooltipTextsHorizontally: Bool

  @AppProperty(key: UserDef.kClientsIMKTextInputIncapable.rawValue, defaultValue: kDefaultClientsIMKTextInputIncapable)
  public var clientsIMKTextInputIncapable: [String: Bool]

  @AppProperty(key: UserDef.kOnlyLoadFactoryLangModelsIfNeeded.rawValue, defaultValue: true)
  public var onlyLoadFactoryLangModelsIfNeeded: Bool {
    didSet {
      if !onlyLoadFactoryLangModelsIfNeeded { LMMgr.loadDataModelsOnAppDelegate() }
    }
  }

  @AppProperty(key: UserDef.kShowTranslatedStrokesInCompositionBuffer.rawValue, defaultValue: true)
  public var showTranslatedStrokesInCompositionBuffer: Bool

  @AppProperty(key: UserDef.kForceCassetteChineseConversion.rawValue, defaultValue: 0)
  public var forceCassetteChineseConversion: Int

  @AppProperty(key: UserDef.kShowReverseLookupInCandidateUI.rawValue, defaultValue: true)
  public var showReverseLookupInCandidateUI: Bool

  @AppProperty(key: UserDef.kAutoCompositeWithLongestPossibleCassetteKey.rawValue, defaultValue: true)
  public var autoCompositeWithLongestPossibleCassetteKey: Bool

  @AppProperty(key: UserDef.kShareAlphanumericalModeStatusAcrossClients.rawValue, defaultValue: false)
  public var shareAlphanumericalModeStatusAcrossClients: Bool

  @AppProperty(key: UserDef.kPhraseEditorAutoReloadExternalModifications.rawValue, defaultValue: true)
  public var phraseEditorAutoReloadExternalModifications: Bool

  @AppProperty(key: UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.rawValue, defaultValue: false)
  public var classicHaninKeyboardSymbolModeShortcutEnabled: Bool

  // MARK: - Settings (Tier 2)

  @AppProperty(key: UserDef.kUseIMKCandidateWindow.rawValue, defaultValue: false)
  public var useIMKCandidateWindow: Bool

  @AppProperty(key: UserDef.kEnableSwiftUIForTDKCandidates.rawValue, defaultValue: false)
  public var enableSwiftUIForTDKCandidates: Bool

  @AppProperty(key: UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.rawValue, defaultValue: false)
  public var enableMouseScrollingForTDKCandidatesCocoa: Bool

  @AppProperty(
    key: UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients.rawValue,
    defaultValue: false
  )
  public var disableSegmentedThickUnderlineInMarkingModeForManagedClients: Bool

  // MARK: - Settings (Tier 3)

  @AppProperty(key: UserDef.kMaxCandidateLength.rawValue, defaultValue: 10)
  public var maxCandidateLength: Int

  @AppProperty(key: UserDef.kShouldNotFartInLieuOfBeep.rawValue, defaultValue: true)
  public var shouldNotFartInLieuOfBeep: Bool

  @AppProperty(key: UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue, defaultValue: false)
  public var showHanyuPinyinInCompositionBuffer: Bool

  @AppProperty(key: UserDef.kInlineDumpPinyinInLieuOfZhuyin.rawValue, defaultValue: false)
  public var inlineDumpPinyinInLieuOfZhuyin: Bool

  @AppProperty(key: UserDef.kCNS11643Enabled.rawValue, defaultValue: false)
  public var cns11643Enabled: Bool {
    didSet {
      LMMgr.setCNSEnabled(cns11643Enabled) // 很重要
    }
  }

  @AppProperty(key: UserDef.kSymbolInputEnabled.rawValue, defaultValue: true)
  public var symbolInputEnabled: Bool {
    didSet {
      LMMgr.setSymbolEnabled(symbolInputEnabled) // 很重要
    }
  }

  @AppProperty(key: UserDef.kCassetteEnabled.rawValue, defaultValue: false)
  public var cassetteEnabled: Bool {
    didSet {
      LMMgr.setCassetteEnabled(cassetteEnabled) // 很重要
    }
  }

  @AppProperty(key: UserDef.kChineseConversionEnabled.rawValue, defaultValue: false)
  public var chineseConversionEnabled: Bool {
    didSet {
      // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
      if chineseConversionEnabled, shiftJISShinjitaiOutputEnabled {
        shiftJISShinjitaiOutputEnabled.toggle()
        UserDefaults.standard.set(
          shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
        )
      }
      UserDefaults.standard.set(
        chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue
      )
    }
  }

  @AppProperty(key: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue, defaultValue: false)
  public var shiftJISShinjitaiOutputEnabled: Bool {
    didSet {
      // 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
      if shiftJISShinjitaiOutputEnabled, chineseConversionEnabled {
        chineseConversionEnabled.toggle()
        UserDefaults.standard.set(
          chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled.rawValue
        )
      }
      UserDefaults.standard.set(
        shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled.rawValue
      )
    }
  }

  @AppProperty(key: UserDef.kCurrencyNumeralsEnabled.rawValue, defaultValue: false)
  public var currencyNumeralsEnabled: Bool

  @AppProperty(key: UserDef.kHalfWidthPunctuationEnabled.rawValue, defaultValue: false)
  public var halfWidthPunctuationEnabled: Bool

  @AppProperty(key: UserDef.kEscToCleanInputBuffer.rawValue, defaultValue: true)
  public var escToCleanInputBuffer: Bool

  @AppProperty(key: UserDef.kAcceptLeadingIntonations.rawValue, defaultValue: true)
  public var acceptLeadingIntonations: Bool

  @AppProperty(key: UserDef.kSpecifyIntonationKeyBehavior.rawValue, defaultValue: 0)
  public var specifyIntonationKeyBehavior: Int

  @AppProperty(key: UserDef.kSpecifyShiftBackSpaceKeyBehavior.rawValue, defaultValue: 0)
  public var specifyShiftBackSpaceKeyBehavior: Int

  @AppProperty(key: UserDef.kSpecifyShiftTabKeyBehavior.rawValue, defaultValue: false)
  public var specifyShiftTabKeyBehavior: Bool

  @AppProperty(key: UserDef.kSpecifyShiftSpaceKeyBehavior.rawValue, defaultValue: false)
  public var specifyShiftSpaceKeyBehavior: Bool

  // MARK: - Optional settings

  @AppProperty(key: UserDef.kCandidateTextFontName.rawValue, defaultValue: "")
  public var candidateTextFontName: String

  @AppProperty(key: UserDef.kCandidateKeys.rawValue, defaultValue: kDefaultCandidateKeys)
  public var candidateKeys: String {
    didSet {
      let optimized = candidateKeys.lowercased().deduplicated
      if candidateKeys != optimized { candidateKeys = optimized }
      if CandidateKey.validate(keys: candidateKeys) != nil {
        candidateKeys = Self.kDefaultCandidateKeys
      }
    }
  }

  @AppProperty(key: UserDef.kUseSCPCTypingMode.rawValue, defaultValue: false)
  public var useSCPCTypingMode: Bool {
    willSet {
      if newValue {
        LMMgr.loadUserSCPCSequencesData()
      }
    }
  }

  @AppProperty(key: UserDef.kPhraseReplacementEnabled.rawValue, defaultValue: false)
  public var phraseReplacementEnabled: Bool {
    willSet {
      LMMgr.setPhraseReplacementEnabled(newValue)
      if newValue {
        LMMgr.loadUserPhraseReplacement()
      }
    }
  }

  @AppProperty(key: UserDef.kAssociatedPhrasesEnabled.rawValue, defaultValue: false)
  public var associatedPhrasesEnabled: Bool {
    willSet {
      if newValue {
        LMMgr.loadUserAssociatesData()
      }
    }
  }

  // MARK: - Keyboard HotKey Enable / Disable

  @AppProperty(key: UserDef.kUsingHotKeySCPC.rawValue, defaultValue: true)
  public var usingHotKeySCPC: Bool

  @AppProperty(key: UserDef.kUsingHotKeyAssociates.rawValue, defaultValue: true)
  public var usingHotKeyAssociates: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCNS.rawValue, defaultValue: true)
  public var usingHotKeyCNS: Bool

  @AppProperty(key: UserDef.kUsingHotKeyKangXi.rawValue, defaultValue: true)
  public var usingHotKeyKangXi: Bool

  @AppProperty(key: UserDef.kUsingHotKeyJIS.rawValue, defaultValue: true)
  public var usingHotKeyJIS: Bool

  @AppProperty(key: UserDef.kUsingHotKeyHalfWidthASCII.rawValue, defaultValue: true)
  public var usingHotKeyHalfWidthASCII: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCurrencyNumerals.rawValue, defaultValue: true)
  public var usingHotKeyCurrencyNumerals: Bool

  @AppProperty(key: UserDef.kUsingHotKeyCassette.rawValue, defaultValue: true)
  public var usingHotKeyCassette: Bool

  @AppProperty(key: UserDef.kUsingHotKeyRevLookup.rawValue, defaultValue: true)
  public var usingHotKeyRevLookup: Bool

  @AppProperty(key: UserDef.kUsingHotKeyInputMode.rawValue, defaultValue: true)
  public var usingHotKeyInputMode: Bool
}
