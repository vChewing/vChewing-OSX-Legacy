// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

/// 使用者辭典資料預設範例檔案名稱。
private let kTemplateNameUserPhrases = "template-userphrases"
private let kTemplateNameUserReplacements = "template-replacements"
private let kTemplateNameUserFilterList = "template-exclusions"
private let kTemplateNameUserSymbolPhrases = "template-usersymbolphrases"
private let kTemplateNameUserAssociatesCHS = "template-associatedPhrases-chs"
private let kTemplateNameUserAssociatesCHT = "template-associatedPhrases-cht"

public class LMMgr {
  public static var shared = LMMgr()
  public private(set) static var lmCHS = vChewingLM.LMInstantiator(isCHS: true)
  public private(set) static var lmCHT = vChewingLM.LMInstantiator(isCHS: false)
  public private(set) static var uomCHS = vChewingLM.LMUserOverride(
    dataURL: LMMgr.userOverrideModelDataURL(.imeModeCHS))
  public private(set) static var uomCHT = vChewingLM.LMUserOverride(
    dataURL: LMMgr.userOverrideModelDataURL(.imeModeCHT))

  public static var currentLM: vChewingLM.LMInstantiator {
    switch IMEApp.currentInputMode {
    case .imeModeCHS:
      return Self.lmCHS
    case .imeModeCHT:
      return Self.lmCHT
    case .imeModeNULL:
      return .init()
    }
  }

  public static var currentUOM: vChewingLM.LMUserOverride {
    switch IMEApp.currentInputMode {
    case .imeModeCHS:
      return Self.uomCHS
    case .imeModeCHT:
      return Self.uomCHT
    case .imeModeNULL:
      return .init(dataURL: Self.userOverrideModelDataURL(IMEApp.currentInputMode))
    }
  }

  // MARK: - Functions reacting directly with language models.

  public static func initUserLangModels() {
    Self.chkUserLMFilesExist(.imeModeCHT)
    Self.chkUserLMFilesExist(.imeModeCHS)
    // LMMgr 的 loadUserPhrases 等函式在自動讀取 dataFolderPath 時，
    // 如果發現自訂目錄不可用，則會自動抹去自訂目錄設定、改採預設目錄。
    // 所以這裡不需要特別處理。
    Self.loadUserPhrasesData()
  }

  public static func loadCoreLanguageModelFile(
    filenameSansExtension: String, langModel lm: inout vChewingLM.LMInstantiator
  ) {
    lm.loadLanguageModel(plist: Self.getDictionaryData(filenameSansExtension))
  }

  public static func loadDataModelsOnAppDelegate() {
    let globalQueue = DispatchQueue.main
    var showFinishNotification = false
    let group = DispatchGroup()
    group.enter()
    globalQueue.async {
      if !Self.lmCHT.isCNSDataLoaded {
        Self.lmCHT.loadCNSData(plist: Self.getDictionaryData("data-cns"))
      }
      if !Self.lmCHT.isMiscDataLoaded {
        Self.lmCHT.loadMiscData(plist: Self.getDictionaryData("data-zhuyinwen"))
      }
      if !Self.lmCHT.isSymbolDataLoaded {
        Self.lmCHT.loadSymbolData(plist: Self.getDictionaryData("data-symbols"))
      }
      if !Self.lmCHS.isCNSDataLoaded {
        Self.lmCHS.loadCNSData(plist: Self.getDictionaryData("data-cns"))
      }
      if !Self.lmCHS.isMiscDataLoaded {
        Self.lmCHS.loadMiscData(plist: Self.getDictionaryData("data-zhuyinwen"))
      }
      if !Self.lmCHS.isSymbolDataLoaded {
        Self.lmCHS.loadSymbolData(plist: Self.getDictionaryData("data-symbols"))
      }
      group.leave()
    }
    if !Self.lmCHT.isCoreLMLoaded {
      showFinishNotification = true
      Notifier.notify(
        message: NSLocalizedString("Loading CHT Core Dict...", comment: "")
      )
      group.enter()
      globalQueue.async {
        loadCoreLanguageModelFile(filenameSansExtension: "data-cht", langModel: &Self.lmCHT)
        group.leave()
      }
    }
    if !Self.lmCHS.isCoreLMLoaded {
      showFinishNotification = true
      Notifier.notify(
        message: NSLocalizedString("Loading CHS Core Dict...", comment: "")
      )
      group.enter()
      globalQueue.async {
        loadCoreLanguageModelFile(filenameSansExtension: "data-chs", langModel: &Self.lmCHS)
        group.leave()
      }
    }
    group.notify(queue: DispatchQueue.main) {
      if showFinishNotification {
        Notifier.notify(
          message: NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      }
    }
  }

  public static func loadDataModel(_ mode: Shared.InputMode) {
    let globalQueue = DispatchQueue.main
    var showFinishNotification = false
    let group = DispatchGroup()
    group.enter()
    globalQueue.async {
      switch mode {
      case .imeModeCHS:
        if !Self.lmCHS.isCNSDataLoaded {
          Self.lmCHS.loadCNSData(plist: Self.getDictionaryData("data-cns"))
        }
        if !Self.lmCHS.isMiscDataLoaded {
          Self.lmCHS.loadMiscData(plist: Self.getDictionaryData("data-zhuyinwen"))
        }
        if !Self.lmCHS.isSymbolDataLoaded {
          Self.lmCHS.loadSymbolData(plist: Self.getDictionaryData("data-symbols"))
        }
      case .imeModeCHT:
        if !Self.lmCHT.isCNSDataLoaded {
          Self.lmCHT.loadCNSData(plist: Self.getDictionaryData("data-cns"))
        }
        if !Self.lmCHT.isMiscDataLoaded {
          Self.lmCHT.loadMiscData(plist: Self.getDictionaryData("data-zhuyinwen"))
        }
        if !Self.lmCHT.isSymbolDataLoaded {
          Self.lmCHT.loadSymbolData(plist: Self.getDictionaryData("data-symbols"))
        }
      default: break
      }
      group.leave()
    }
    switch mode {
    case .imeModeCHS:
      if !Self.lmCHS.isCoreLMLoaded {
        showFinishNotification = true
        Notifier.notify(
          message: NSLocalizedString("Loading CHS Core Dict...", comment: "")
        )
        group.enter()
        globalQueue.async {
          loadCoreLanguageModelFile(filenameSansExtension: "data-chs", langModel: &Self.lmCHS)
          group.leave()
        }
      }
    case .imeModeCHT:
      if !Self.lmCHT.isCoreLMLoaded {
        showFinishNotification = true
        Notifier.notify(
          message: NSLocalizedString("Loading CHT Core Dict...", comment: "")
        )
        group.enter()
        globalQueue.async {
          loadCoreLanguageModelFile(filenameSansExtension: "data-cht", langModel: &Self.lmCHT)
          group.leave()
        }
      }
    default: break
    }
    group.notify(queue: DispatchQueue.main) {
      if showFinishNotification {
        Notifier.notify(
          message: NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      }
    }
  }

  public static func reloadFactoryDictionaryPlists() {
    FrmRevLookupWindow.reloadData()
    LMMgr.lmCHS.resetFactoryPlistModels()
    LMMgr.lmCHT.resetFactoryPlistModels()
    if PrefMgr.shared.onlyLoadFactoryLangModelsIfNeeded {
      LMMgr.loadDataModel(IMEApp.currentInputMode)
    } else {
      LMMgr.loadDataModelsOnAppDelegate()
    }
  }

  /// 載入磁帶資料。
  /// - Remark: cassettePath() 會在輸入法停用磁帶時直接返回
  public static func loadCassetteData() {
    vChewingLM.LMInstantiator.loadCassetteData(path: cassettePath())
  }

  public static func loadUserPhrasesData(type: vChewingLM.ReplacableUserDataType? = nil) {
    guard let type = type else {
      Self.lmCHT.loadUserPhrasesData(
        path: userDictDataURL(mode: .imeModeCHT, type: .thePhrases).path,
        filterPath: userDictDataURL(mode: .imeModeCHT, type: .theFilter).path
      )
      Self.lmCHS.loadUserPhrasesData(
        path: userDictDataURL(mode: .imeModeCHS, type: .thePhrases).path,
        filterPath: userDictDataURL(mode: .imeModeCHS, type: .theFilter).path
      )
      Self.lmCHT.loadUserSymbolData(path: userDictDataURL(mode: .imeModeCHT, type: .theSymbols).path)
      Self.lmCHS.loadUserSymbolData(path: userDictDataURL(mode: .imeModeCHS, type: .theSymbols).path)

      if PrefMgr.shared.associatedPhrasesEnabled { Self.loadUserAssociatesData() }
      if PrefMgr.shared.phraseReplacementEnabled { Self.loadUserPhraseReplacement() }
      if PrefMgr.shared.useSCPCTypingMode { Self.loadUserSCPCSequencesData() }

      Self.uomCHT.loadData(fromURL: userOverrideModelDataURL(.imeModeCHT))
      Self.uomCHS.loadData(fromURL: userOverrideModelDataURL(.imeModeCHS))

      CandidateNode.load(url: Self.userSymbolMenuDataURL())
      return
    }
    switch type {
    case .thePhrases, .theFilter:
      Self.lmCHT.loadUserPhrasesData(
        path: userDictDataURL(mode: .imeModeCHT, type: .thePhrases).path,
        filterPath: userDictDataURL(mode: .imeModeCHT, type: .theFilter).path
      )
      Self.lmCHS.loadUserPhrasesData(
        path: userDictDataURL(mode: .imeModeCHS, type: .thePhrases).path,
        filterPath: userDictDataURL(mode: .imeModeCHS, type: .theFilter).path
      )
    case .theReplacements:
      if PrefMgr.shared.phraseReplacementEnabled { Self.loadUserPhraseReplacement() }
    case .theAssociates:
      if PrefMgr.shared.associatedPhrasesEnabled { Self.loadUserAssociatesData() }
    case .theSymbols:
      Self.lmCHT.loadUserSymbolData(
        path: Self.userDictDataURL(mode: .imeModeCHT, type: .theSymbols).path
      )
      Self.lmCHS.loadUserSymbolData(
        path: Self.userDictDataURL(mode: .imeModeCHS, type: .theSymbols).path
      )
    }
  }

  public static func loadUserAssociatesData() {
    Self.lmCHT.loadUserAssociatesData(
      path: Self.userDictDataURL(mode: .imeModeCHT, type: .theAssociates).path
    )
    Self.lmCHS.loadUserAssociatesData(
      path: Self.userDictDataURL(mode: .imeModeCHS, type: .theAssociates).path
    )
  }

  public static func loadUserPhraseReplacement() {
    Self.lmCHT.loadReplacementsData(
      path: Self.userDictDataURL(mode: .imeModeCHT, type: .theReplacements).path
    )
    Self.lmCHS.loadReplacementsData(
      path: Self.userDictDataURL(mode: .imeModeCHS, type: .theReplacements).path
    )
  }

  public static func loadUserSCPCSequencesData() {
    Self.lmCHT.loadUserSCPCSequencesData(
      path: Self.userSCPCSequencesURL(.imeModeCHT).path
    )
    Self.lmCHS.loadUserSCPCSequencesData(
      path: Self.userSCPCSequencesURL(.imeModeCHS).path
    )
  }

  public static func checkIfUserPhraseExist(
    userPhrase: String,
    mode: Shared.InputMode,
    key unigramKey: String,
    factoryDictionaryOnly: Bool = false
  ) -> Bool {
    switch mode {
    case .imeModeCHS:
      return lmCHS.hasKeyValuePairFor(
        keyArray: [unigramKey], value: userPhrase, factoryDictionaryOnly: factoryDictionaryOnly
      )
    case .imeModeCHT:
      return lmCHT.hasKeyValuePairFor(
        keyArray: [unigramKey], value: userPhrase, factoryDictionaryOnly: factoryDictionaryOnly
      )
    case .imeModeNULL: return false
    }
  }

  public static func setPhraseReplacementEnabled(_ state: Bool) {
    Self.lmCHT.isPhraseReplacementEnabled = state
    Self.lmCHS.isPhraseReplacementEnabled = state
  }

  public static func setCNSEnabled(_ state: Bool) {
    Self.lmCHT.isCNSEnabled = state
    Self.lmCHS.isCNSEnabled = state
  }

  public static func setSymbolEnabled(_ state: Bool) {
    Self.lmCHT.isSymbolEnabled = state
    Self.lmCHS.isSymbolEnabled = state
  }

  public static func setSCPCEnabled(_ state: Bool) {
    Self.lmCHT.isSCPCEnabled = state
    Self.lmCHS.isSCPCEnabled = state
  }

  public static func setCassetteEnabled(_ state: Bool) {
    Self.lmCHT.isCassetteEnabled = state
    Self.lmCHS.isCassetteEnabled = state
  }

  public static func setDeltaOfCalendarYears(_ delta: Int) {
    Self.lmCHT.deltaOfCalendarYears = delta
    Self.lmCHS.deltaOfCalendarYears = delta
  }

  // MARK: - 獲取原廠核心語彙檔案資料所在路徑（優先獲取 Containers 下的資料檔案）。

  // 該函式目前僅供步天歌繁簡轉換引擎使用，並不會檢查目標檔案格式的實際可用性。

  public static func getBundleDataPath(_ filenameSansExt: String, factory: Bool = false) -> String {
    let factory = PrefMgr.shared.useExternalFactoryDict ? factory : true
    let factoryPath = Bundle.main.path(forResource: filenameSansExt, ofType: "plist")!
    let containerPath = Self.appSupportURL.appendingPathComponent("vChewingFactoryData/\(filenameSansExt).plist").path
      .expandingTildeInPath
    var isFailed = false
    if !factory {
      var isFolder = ObjCBool(false)
      if !FileManager.default.fileExists(atPath: containerPath, isDirectory: &isFolder) { isFailed = true }
      if !isFailed, !FileManager.default.isReadableFile(atPath: containerPath) { isFailed = true }
    }
    let result = (factory || isFailed) ? factoryPath : containerPath
    return result
  }

  // MARK: - 獲取原廠核心語彙檔案資料本身（優先獲取 Containers 下的資料檔案），可能會出 nil。

  public static func getDictionaryData(_ filenameSansExt: String, factory: Bool = false) -> (
    dict: [String: [Data]]?, path: String
  ) {
    let factory = PrefMgr.shared.useExternalFactoryDict ? factory : true
    let factoryResultURL = Bundle.main.url(forResource: filenameSansExt, withExtension: "plist")
    let containerResultURL = Self.appSupportURL.appendingPathComponent("vChewingFactoryData/\(filenameSansExt).plist")
    var lastReadPath = factoryResultURL?.path ?? "Factory file missing: \(filenameSansExt).plist"

    func getPlistData(url: URL?) -> [String: [Data]]? {
      var isFailed = false
      var isFolder = ObjCBool(false)
      guard let url = url else {
        vCLog("URL Invalid.")
        return nil
      }
      defer { lastReadPath = url.path }
      if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) { isFailed = true }
      if !isFailed, !FileManager.default.isReadableFile(atPath: url.path) { isFailed = true }
      if isFailed {
        vCLog("↑ Exception happened when reading plist file at: \(url.path).")
        return nil
      }
      do {
        let rawData = try Data(contentsOf: url)
        return try PropertyListSerialization.propertyList(from: rawData, format: nil) as? [String: [Data]] ?? nil
      } catch {
        return nil
      }
    }

    let result =
      factory
        ? getPlistData(url: factoryResultURL)
        : getPlistData(url: containerResultURL) ?? getPlistData(url: factoryResultURL)
    if result == nil {
      vCLog("↑ Exception happened when reading plist file at: \(lastReadPath).")
    }
    return (dict: result, path: lastReadPath)
  }

  // MARK: - 使用者語彙檔案的具體檔案名稱路徑定義

  // Swift 的 appendingPathComponent 需要藉由 URL 完成。

  /// 指定的使用者辭典資料路徑。
  /// - Parameters:
  ///   - mode: 繁簡模式。
  ///   - type: 辭典資料類型
  /// - Returns: 資料路徑（URL）。
  public static func userDictDataURL(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType) -> URL {
    var fileName: String = {
      switch type {
      case .thePhrases: return "userdata"
      case .theFilter: return "exclude-phrases"
      case .theReplacements: return "phrases-replacement"
      case .theAssociates: return "associatedPhrases"
      case .theSymbols: return "usersymbolphrases"
      }
    }()
    fileName.append((mode == .imeModeCHT) ? "-cht.txt" : "-chs.txt")
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者逐字選字模式候選字詞順序資料路徑。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  public static func userSCPCSequencesURL(_ mode: Shared.InputMode) -> URL {
    let fileName = (mode == .imeModeCHT) ? "data-plain-bpmf-cht.plist" : "data-plain-bpmf-chs.plist"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者波浪符號選單資料路徑。
  /// - Returns: 資料路徑（URL）。
  public static func userSymbolMenuDataURL() -> URL {
    let fileName = "symbols.dat"
    return URL(fileURLWithPath: dataFolderPath(isDefaultFolder: false)).appendingPathComponent(fileName)
  }

  /// 使用者半衰記憶模組資料的存取頻次特別高，且資料新陳代謝速度快，所以只適合放在預設的使用者資料目錄下。
  /// 也就是「~/Library/Application Support/vChewing/」目錄下，且不會隨著使用者辭典目錄的改變而改變。
  /// - Parameter mode: 簡繁體輸入模式。
  /// - Returns: 資料路徑（URL）。
  public static func userOverrideModelDataURL(_ mode: Shared.InputMode) -> URL {
    let fileName: String = {
      switch mode {
      case .imeModeCHS: return "vChewing_override-model-data-chs.dat"
      case .imeModeCHT: return "vChewing_override-model-data-cht.dat"
      case .imeModeNULL: return "vChewing_override-model-data-dummy.dat"
      }
    }()

    return URL(
      fileURLWithPath: dataFolderPath(isDefaultFolder: true)
    ).deletingLastPathComponent().appendingPathComponent(fileName)
  }

  // MARK: - 檢查具體的使用者語彙檔案是否存在

  public static func ensureFileExists(
    _ fileURL: URL, deployTemplate templateBasename: String = "1145141919810",
    extension ext: String = "txt"
  ) -> Bool {
    let filePath = fileURL.path
    if !FileManager.default.fileExists(atPath: filePath) {
      let templateURL = Bundle.main.url(forResource: templateBasename, withExtension: ext)
      var templateData = Data("".utf8)
      if templateBasename != "" {
        do {
          try templateData = Data(contentsOf: templateURL ?? URL(fileURLWithPath: ""))
        } catch {
          templateData = Data("".utf8)
        }
        do {
          try templateData.write(to: URL(fileURLWithPath: filePath))
        } catch {
          vCLog("Failed to write template data to: \(filePath)")
          return false
        }
      }
    }
    return true
  }

  @discardableResult public static func chkUserLMFilesExist(_ mode: Shared.InputMode) -> Bool {
    if !userDataFolderExists {
      return false
    }
    /// CandidateNode 資料與 UserOverrideModel 半衰模組資料檔案不需要強行確保存在。
    /// 前者的話，需要該檔案存在的人自己會建立。
    /// 後者的話，你在敲字時自己就會建立。
    var failed = false
    caseCheck: for type in vChewingLM.ReplacableUserDataType.allCases {
      let templateName = Self.templateName(for: type, mode: mode)
      if !ensureFileExists(userDictDataURL(mode: mode, type: type), deployTemplate: templateName) {
        failed = true
        break caseCheck
      }
    }
    failed = failed || !ensureFileExists(userSCPCSequencesURL(mode))
    return !failed
  }

  private static func templateName(for type: vChewingLM.ReplacableUserDataType, mode: Shared.InputMode) -> String {
    switch type {
    case .thePhrases: return kTemplateNameUserPhrases
    case .theFilter: return kTemplateNameUserFilterList
    case .theReplacements: return kTemplateNameUserReplacements
    case .theSymbols: return kTemplateNameUserSymbolPhrases
    case .theAssociates:
      return mode == .imeModeCHS ? kTemplateNameUserAssociatesCHS : kTemplateNameUserAssociatesCHT
    }
  }

  // MARK: - 使用者語彙檔案專用目錄的合規性檢查

  // 一次性檢查給定的目錄是否存在寫入合規性（僅用於偏好設定檢查等初步檢查場合，不做任何糾偏行為）
  public static func checkIfSpecifiedUserDataFolderValid(_ folderPath: String?) -> Bool {
    var isFolder = ObjCBool(false)
    let folderExist = FileManager.default.fileExists(atPath: folderPath ?? "", isDirectory: &isFolder)
    // The above "&" mutates the "isFolder" value to the real one received by the "folderExist".

    // 路徑沒有結尾斜槓的話，會導致目錄合規性判定失準。
    // 出於每個型別每個函式的自我責任原則，這裡多檢查一遍也不壞。
    var folderPath = folderPath // Convert the incoming constant to a variable.
    if isFolder.boolValue {
      folderPath?.ensureTrailingSlash()
    }
    let isFolderWritable = FileManager.default.isWritableFile(atPath: folderPath ?? "")
    // vCLog("mgrLM: Exist: \(folderExist), IsFolder: \(isFolder.boolValue), isWritable: \(isFolderWritable)")
    if ((folderExist && !isFolder.boolValue) || !folderExist) || !isFolderWritable {
      return false
    }
    return true
  }

  // 檢查給定的磁帶目錄是否存在讀入合規性、且是否為指定格式。
  public static func checkCassettePathValidity(_ cassettePath: String?) -> Bool {
    var isFolder = ObjCBool(true)
    let isExist = FileManager.default.fileExists(atPath: cassettePath ?? "", isDirectory: &isFolder)
    // The above "&" mutates the "isFolder" value to the real one received by the "isExist".
    let isReadable = FileManager.default.isReadableFile(atPath: cassettePath ?? "")
    return !isFolder.boolValue && isExist && isReadable
  }

  // 檢查給定的目錄是否存在寫入合規性、且糾偏，不接受任何傳入變數。
  public static var userDataFolderExists: Bool {
    let folderPath = Self.dataFolderPath(isDefaultFolder: false)
    var isFolder = ObjCBool(false)
    var folderExist = FileManager.default.fileExists(atPath: folderPath, isDirectory: &isFolder)
    // The above "&" mutates the "isFolder" value to the real one received by the "folderExist".
    // 發現目標路徑不是目錄的話：
    // 如果要找的目標路徑是原廠目標路徑的話，先將這個路徑的所指對象更名、再認為目錄不存在。
    // 如果要找的目標路徑不是原廠目標路徑的話，則直接報錯。
    if folderExist, !isFolder.boolValue {
      do {
        if dataFolderPath(isDefaultFolder: false)
          == dataFolderPath(isDefaultFolder: true)
        {
          let formatter = DateFormatter()
          formatter.dateFormat = "YYYYMMDD-HHMM'Hrs'-ss's'"
          let dirAlternative = folderPath + formatter.string(from: Date())
          try FileManager.default.moveItem(atPath: folderPath, toPath: dirAlternative)
        } else {
          throw folderPath
        }
      } catch {
        print("Failed to make path available at: \(error)")
        return false
      }
      folderExist = false
    }
    if !folderExist {
      do {
        try FileManager.default.createDirectory(
          atPath: folderPath,
          withIntermediateDirectories: true,
          attributes: nil
        )
      } catch {
        print("Failed to create folder: \(error)")
        return false
      }
    }
    return true
  }

  // MARK: - 用以讀取使用者語彙檔案目錄的函式，會自動對 PrefMgr 當中的參數糾偏。

  // 當且僅當 PrefMgr 當中的參數不合規（比如非實在路徑、或者無權限寫入）時，才會糾偏。

  public static let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

  public static func dataFolderPath(isDefaultFolder _: Bool) -> String {
    Self.appSupportURL.appendingPathComponent("vChewing").path.expandingTildeInPath
  }

  public static func cassettePath() -> String {
    let rawCassettePath = PrefMgr.shared.cassettePath
    if UserDefaults.standard.object(forKey: UserDef.kCassettePath.rawValue) != nil {
      if Self.checkCassettePathValidity(rawCassettePath) { return rawCassettePath }
      UserDefaults.standard.removeObject(forKey: UserDef.kCassettePath.rawValue)
    }
    return ""
  }

  // MARK: - 重設使用者語彙檔案目錄

  public static func resetSpecifiedUserDataFolder() {
    UserDefaults.standard.removeObject(forKey: UserDef.kUserDataFolderSpecified.rawValue)
    Self.initUserLangModels()
  }

  public static func resetCassettePath() {
    UserDefaults.standard.removeObject(forKey: UserDef.kCassettePath.rawValue)
    Self.loadCassetteData()
  }

  // MARK: - 寫入使用者檔案

  public static func writeUserPhrase(
    _ userPhrase: String, inputMode mode: Shared.InputMode, areWeDeleting: Bool
  ) -> Bool {
    var userPhraseOutput: String = userPhrase
    if !chkUserLMFilesExist(.imeModeCHS)
      || !chkUserLMFilesExist(.imeModeCHT)
    {
      return false
    }

    let theType: vChewingLM.ReplacableUserDataType = areWeDeleting ? .theFilter : .thePhrases
    let theURL = userDictDataURL(mode: mode, type: theType)

    let arr = userPhraseOutput.split(separator: " ")
    var areWeDuplicating = false
    if arr.count >= 2 {
      areWeDuplicating = Self.checkIfUserPhraseExist(
        userPhrase: arr[0].description, mode: mode, key: arr[1].description, factoryDictionaryOnly: true
      )
    }

    if areWeDuplicating, !areWeDeleting {
      // Do not use ASCII characters to comment here.
      userPhraseOutput += " #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎"
    }

    if let writeFile = FileHandle(forUpdatingAtPath: theURL.path),
       let data = userPhraseOutput.data(using: .utf8),
       let endl = "\n".data(using: .utf8)
    {
      writeFile.seekToEndOfFile()
      writeFile.write(endl)
      writeFile.write(data)
      writeFile.write(endl)
      writeFile.closeFile()
    } else {
      return false
    }

    // We enforce the format consolidation here, since the pragma header
    // will let the UserPhraseLM bypasses the consolidating process on load.
    if !vChewingLM.LMConsolidator.consolidate(path: theURL.path, pragma: false) {
      return false
    }

    // The new FolderMonitor module does NOT monitor cases that files are modified
    // by the current application itself, requiring additional manual loading process here.
    if #available(macOS 10.15, *) { FileObserveProject.shared.touch() }
    if PrefMgr.shared.phraseEditorAutoReloadExternalModifications {
      CtlPrefWindow.shared?.updatePhraseEditor()
    }
    loadUserPhrasesData(type: .thePhrases)
    return true
  }

  // MARK: - 藉由語彙編輯器開啟使用者檔案

  public static func checkIfUserFilesExistBeforeOpening() -> Bool {
    if !Self.chkUserLMFilesExist(.imeModeCHS)
      || !Self.chkUserLMFilesExist(.imeModeCHT)
    {
      let content = String(
        format: NSLocalizedString(
          "Please check the permission at \"%@\".", comment: ""
        ),
        Self.dataFolderPath(isDefaultFolder: false)
      )
      DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Unable to create the user phrase file.", comment: "")
        alert.informativeText = content
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
        NSApp.activate(ignoringOtherApps: true)
      }
      return false
    }
    return true
  }

  public static func openUserDictFile(type: vChewingLM.ReplacableUserDataType, dual: Bool = false, alt: Bool) {
    let app: String = alt ? "" : "Finder"
    openPhraseFile(fromURL: userDictDataURL(mode: IMEApp.currentInputMode, type: type), app: app)
    guard dual else { return }
    openPhraseFile(fromURL: userDictDataURL(mode: IMEApp.currentInputMode.reversed, type: type), app: app)
  }

  /// 用指定應用開啟指定檔案。
  /// - Remark: 如果你的 App 有 Sandbox 處理過的話，請勿給 app 傳入 "vim" 參數，因為 Sandbox 會阻止之。
  /// - Parameters:
  ///   - url: 檔案 URL。
  ///   - app: 指定 App 應用的 binary 檔案名稱。
  public static func openPhraseFile(fromURL url: URL, app: String = "") {
    if !Self.checkIfUserFilesExistBeforeOpening() { return }
    DispatchQueue.main.async {
      switch app {
      case "Finder":
        NSWorkspace.shared.activateFileViewerSelecting([url])
      default:
        if !NSWorkspace.shared.openFile(url.path, withApplication: app) {
          NSWorkspace.shared.openFile(url.path, withApplication: "TextEdit")
        }
      }
    }
  }

  // MARK: UOM

  public static func saveUserOverrideModelData() {
    let globalQueue = DispatchQueue.main
    let group = DispatchGroup()
    group.enter()
    globalQueue.async {
      Self.uomCHT.saveData(toURL: userOverrideModelDataURL(.imeModeCHT))
      group.leave()
    }
    group.enter()
    globalQueue.async {
      Self.uomCHS.saveData(toURL: userOverrideModelDataURL(.imeModeCHS))
      group.leave()
    }
    _ = group.wait(timeout: .distantFuture)
    group.notify(queue: DispatchQueue.main) {}
  }

  public static func bleachSpecifiedSuggestions(targets: [String], mode: Shared.InputMode) {
    switch mode {
    case .imeModeCHS:
      Self.uomCHT.bleachSpecifiedSuggestions(targets: targets, saveCallback: { Self.uomCHT.saveData() })
    case .imeModeCHT:
      Self.uomCHS.bleachSpecifiedSuggestions(targets: targets, saveCallback: { Self.uomCHS.saveData() })
    case .imeModeNULL:
      break
    }
  }

  public static func removeUnigramsFromUserOverrideModel(_ mode: Shared.InputMode) {
    switch mode {
    case .imeModeCHS:
      Self.uomCHT.bleachUnigrams(saveCallback: { Self.uomCHT.saveData() })
    case .imeModeCHT:
      Self.uomCHS.bleachUnigrams(saveCallback: { Self.uomCHS.saveData() })
    case .imeModeNULL:
      break
    }
  }

  public static func clearUserOverrideModelData(_ mode: Shared.InputMode = .imeModeNULL) {
    switch mode {
    case .imeModeCHS:
      Self.uomCHS.clearData(withURL: userOverrideModelDataURL(.imeModeCHS))
    case .imeModeCHT:
      Self.uomCHT.clearData(withURL: userOverrideModelDataURL(.imeModeCHT))
    case .imeModeNULL:
      break
    }
  }
}

extension LMMgr: PhraseEditorDelegate {
  public var currentInputMode: Shared.InputMode { IMEApp.currentInputMode }

  public func openPhraseFile(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, app: String) {
    Self.openPhraseFile(fromURL: Self.userDictDataURL(mode: mode, type: type), app: app)
  }

  public func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool) {
    vChewingLM.LMConsolidator.consolidate(text: &strProcessed, pragma: shouldCheckPragma)
  }

  public func checkIfUserPhraseExist(userPhrase: String, mode: Shared.InputMode, key unigramKey: String) -> Bool {
    Self.checkIfUserPhraseExist(userPhrase: userPhrase, mode: mode, key: unigramKey)
  }

  public func retrieveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType) -> String {
    Self.retrieveData(mode: mode, type: type)
  }

  public static func retrieveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType) -> String {
    vCLog("Retrieving data. Mode: \(mode.localizedDescription), type: \(type.localizedDescription)")
    let theURL = Self.userDictDataURL(mode: mode, type: type)
    do {
      return try .init(contentsOf: theURL, encoding: .utf8)
    } catch {
      vCLog("Error reading: \(theURL.absoluteString)")
      return ""
    }
  }

  public func saveData(mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, data: String) -> String {
    Self.saveData(mode: mode, type: type, data: data)
  }

  @discardableResult public static func saveData(
    mode: Shared.InputMode, type: vChewingLM.ReplacableUserDataType, data: String
  ) -> String {
    DispatchQueue.main.async {
      let theURL = Self.userDictDataURL(mode: mode, type: type)
      do {
        try data.write(to: theURL, atomically: true, encoding: .utf8)
        Self.loadUserPhrasesData(type: type)
      } catch {
        vCLog("Failed to save current database to: \(theURL.absoluteString)")
      }
    }
    return data
  }

  public func tagOverrides(in strProcessed: inout String, mode: Shared.InputMode) {
    let outputStack: NSMutableString = .init()
    switch mode {
    case .imeModeCHT:
      if !Self.lmCHT.isCoreLMLoaded {
        Notifier.notify(
          message: NSLocalizedString("Loading CHT Core Dict...", comment: "")
        )
        Self.loadCoreLanguageModelFile(
          filenameSansExtension: "data-cht", langModel: &Self.lmCHT
        )
        Notifier.notify(
          message: NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      }
    case .imeModeCHS:
      if !Self.lmCHS.isCoreLMLoaded {
        Notifier.notify(
          message: NSLocalizedString("Loading CHS Core Dict...", comment: "")
        )
        Self.loadCoreLanguageModelFile(
          filenameSansExtension: "data-chs", langModel: &Self.lmCHS
        )
        Notifier.notify(
          message: NSLocalizedString("Core Dict loading complete.", comment: "")
        )
      }
    case .imeModeNULL: return
    }
    for currentLine in strProcessed.split(separator: "\n") {
      let arr = currentLine.split(separator: " ")
      guard arr.count >= 2 else { continue }
      let exists = Self.checkIfUserPhraseExist(
        userPhrase: arr[0].description, mode: mode, key: arr[1].description, factoryDictionaryOnly: true
      )
      outputStack.append(currentLine.description)
      let replace = !currentLine.contains(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎") && exists
      if replace { outputStack.append(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎") }
      outputStack.append("\n")
    }
    strProcessed = outputStack.description
  }
}
