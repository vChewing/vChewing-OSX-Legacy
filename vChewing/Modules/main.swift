// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Carbon
import InputMethodKit

let cmdParameters = CommandLine.arguments.dropFirst(1)

switch cmdParameters.count {
case 0: break
case 1:
  switch cmdParameters.first?.lowercased() {
  case "--dump-prefs":
    if let strDumpedPrefs = PrefMgr.shared.dumpShellScriptBackup() {
      print(strDumpedPrefs)
    }
    exit(0)
  case "install":
    let exitCode = IMKHelper.registerInputMethod()
    exit(exitCode)
  case "uninstall":
    let exitCode = Uninstaller.uninstall(
      defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true),
      removeAll: false
    )
    exit(exitCode)
  default: break
  }
  exit(0)
case 2:
  switch cmdParameters.first?.lowercased() {
  case "uninstall" where cmdParameters.last?.lowercased() == "--all":
    let exitCode = Uninstaller.uninstall(
      defaultDataFolderPath: LMMgr.dataFolderPath(isDefaultFolder: true),
      removeAll: true
    )
    exit(exitCode)
  case "--import-kimo":
    guard let path = cmdParameters.last else {
      exit(1)
    }
    let url = URL(fileURLWithPath: path)
    guard var rawString = try? String(contentsOf: url) else {
      print("[Kimo Import] Given file path is either invalid or not accessible. Read access is needed for this operation.")
      exit(1)
    }
    let count = LMMgr.importYahooKeyKeyUserDictionary(text: &rawString)
    let msg = String(format: "i18n:settings.importFromKimoTxt.finishedCount:%@".localized, count.description)
    print("[Kimo Import] \(msg)")
    exit(0)
  default: break
  }
default: exit(0)
}

guard let mainNibName = Bundle.main.infoDictionary?["NSMainNibFile"] as? String else {
  NSLog("vChewingDebug: Fatal error: NSMainNibFile key not defined in Info.plist.")
  exit(-1)
}

let loaded = Bundle.main.loadNibNamed(mainNibName, owner: NSApp, topLevelObjects: nil)
if !loaded {
  NSLog("vChewingDebug: Fatal error: Cannot load \(mainNibName).")
  exit(-1)
}

let kConnectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "org.atelierInmu.inputmethod.vChewing_Connection"

guard let bundleID = Bundle.main.bundleIdentifier,
      let server = IMKServer(name: kConnectionName, bundleIdentifier: bundleID)
else {
  NSLog(
    "vChewingDebug: Fatal error: Cannot initialize input method server with connection name retrieved from the plist, nor there's no connection name in the plist."
  )
  exit(-1)
}

public let theServer = server

NSApplication.shared.delegate = AppDelegate.shared
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

// MARK: - Top-level Enums relating to Input Mode and Language Supports.

public enum IMEApp {
  // MARK: - 獲取輸入法的版本以及建置編號

  public static let appVersionLabel: String = {
    [appMainVersionLabel.joined(separator: " Build "), appSignedDateLabel].joined(separator: " - ")
  }()

  public static let appMainVersionLabel: [String] = {
    guard
      let intBuild = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String,
      let strVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    else {
      return ["1.14.514", "19190810"]
    }

    return [strVer, intBuild]
  }()

  public static let appSignedDateLabel: String = {
    let maybeDateModified: Date? = {
      guard let executableURL = Bundle.main.executableURL,
            let infoDate = (try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      else {
        return nil
      }
      return infoDate
    }()

    if let theDate = Bundle.main.getCodeSignedDate() {
      return theDate.stringTag
    } else if let theDate = maybeDateModified {
      return "\(theDate.stringTag) Unsigned"
    } else {
      return "Unsigned"
    }
  }()

  // MARK: - 輸入法的當前的簡繁體中文模式

  public static var currentInputMode: Shared.InputMode {
    .init(rawValue: PrefMgr.shared.mostRecentInputMode) ?? .imeModeNULL
  }

  /// 當前鍵盤是否是 JIS 佈局
  public static var isKeyboardJIS: Bool {
    KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS
  }

  /// Fart or Beep?
  static func buzz() {
    if PrefMgr.shared.isDebugModeEnabled {
      NSSound.buzz(fart: !PrefMgr.shared.shouldNotFartInLieuOfBeep)
    } else if !PrefMgr.shared.shouldNotFartInLieuOfBeep {
      NSSound.buzz(fart: true)
    } else {
      NSSound.beep()
    }
  }
}

public extension Date {
  var stringTag: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd.HHmm"
    dateFormatter.timeZone = .init(secondsFromGMT: +28800) ?? .current
    let strDate = dateFormatter.string(from: self)
    return strDate
  }
}
