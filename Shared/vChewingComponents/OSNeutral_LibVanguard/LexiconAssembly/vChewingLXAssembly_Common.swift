// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - LXAssembly

public enum LXAssembly {
  // MARK: Public

  public enum ReplacableUserDataType: String, CaseIterable, Identifiable {
    case thePhrases
    case theFilter
    case theReplacements
    case theAssociates
    case theSymbols

    // MARK: Public

    public var id: String { rawValue }

    public var localizedDescription: String {
      switch self {
      case .thePhrases: return "i18n:PhraseEditor.TabPhrases".i18n
      case .theFilter: return "i18n:PhraseEditor.TabFilter".i18n
      case .theReplacements: return "i18n:PhraseEditor.TabReplacements".i18n
      case .theAssociates: return "i18n:PhraseEditor.TabAssociates".i18n
      case .theSymbols: return "i18n:PhraseEditor.TabSymbols".i18n
      }
    }
  }

  public static let fileHandleQueue: DispatchQueue = {
    let queue = DispatchQueue(
      label: "org.vChewing.LXMgr.unitedUserFileIOQueue"
    )
    queue.setSpecific(key: fileHandleQueueKey, value: fileHandleQueueIdentifier)
    return queue
  }()

  /// 經 fileHandleQueue 調度、同步執行閉包（可重入）。
  /// - Note: 呼叫方若已身處 fileHandleQueue 之上，則就地執行——再 `sync` 同一條序列佇列即構成
  ///   遞迴 sync，libdispatch 會視為用戶端錯誤而直接崩潰（Darwin 上編成 SIGTRAP）。
  /// - Important: 本倉之任務本體**不 hop 回主佇列**（`vChewing-macOS` 側會內嵌一層 `mainSync`），
  ///   故本倉不需要、也不應加掛「已在主佇列則就地執行」那一關——`fileHandleQueue.sync` 於未受競爭時
  ///   就地在呼叫端執行，本倉之呼叫端皆在主執行緒上，任務本體自然就在主執行緒上跑。
  @discardableResult
  public static func withFileHandleQueueSync<T>(_ execute: () throws -> T) rethrows -> T {
    if DispatchQueue.getSpecific(key: fileHandleQueueKey) == fileHandleQueueIdentifier {
      return try execute()
    }
    return try fileHandleQueue.sync(execute: execute)
  }

  /// 在 fileHandleQueue 上非同步執行閉包，不阻塞呼叫方。
  public static func withFileHandleQueueAsync(_ execute: @escaping @Sendable () -> ()) {
    fileHandleQueue.async(execute: execute)
  }

  /// 在 fileHandleQueue 上非同步讀取檔案內容（含可選的 consolidation），
  /// 完成後在 MainActor 上回呼結果。不阻塞呼叫方（通常是 MainActor）。
  nonisolated public static func readFileContentAsync(
    path: String,
    shouldConsolidate: Bool,
    completion: @escaping (String) -> ()
  ) {
    fileHandleQueue.async {
      do {
        if shouldConsolidate {
          LXConsolidator.fixEOF(path: path)
          LXConsolidator.consolidate(path: path, pragma: true)
        }
        let rawStrData = try String(contentsOfFile: path, encoding: .utf8)
        asyncOnMain { completion(rawStrData) }
      } catch {
        vCLMLog("readFileContentAsync failed at: \(path). Details: \(error)")
      }
    }
  }

  // MARK: Internal

  enum FileErrors: Error {
    case fileHandleError(String)
  }

  // MARK: Private

  private static let fileHandleQueueKey = DispatchSpecificKey<UUID>()
  private static let fileHandleQueueIdentifier = UUID()
}

func vCLMLog(_ strPrint: StringLiteralType) {
  // 測試模式下僅於指定過濾參數（如 swift test --filter ...）時輸出，
  // 以免 mixedAlnum 等大量觸發 POM 儲存路徑的案例在完整測試時刷屏。
  if UserDefaults.pendingUnitTests, !hasTestFilterArguments() {
    return
  }
  let toLog = UserDefaults.standard.object(forKey: "_DebugMode") as? Bool ?? true
  if toLog {
    Process.consoleLog("vChewingDebug: \(strPrint)")
  }
}

/// 偵測目前程序是否帶有測試過濾參數（例如 `swift test --filter ...`、`--skip ...` 或 XCTest 的 `-XCTest ...`）。
private func hasTestFilterArguments() -> Bool {
  ProcessInfo.processInfo.arguments.contains {
    $0.hasPrefix("--filter") || $0.hasPrefix("--skip") || $0.hasPrefix("-XCTest")
  }
}

// MARK: - Runtime Context Management

extension LXAssembly {
  public static func applyEnvironmentDefaults() {
    LXAssembly.LXFacade.asyncLoadingUserData = !UserDefaults.pendingUnitTests
  }

  public static func resetSharedState(restoreAsyncLoadingStrategy: Bool = true) {
    LXAssembly.LXFacade.resetSharedResources(
      restoreAsyncLoadingStrategy: restoreAsyncLoadingStrategy
    )
  }
}
