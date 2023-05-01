// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import InputMethodKit

extension AppDelegate {
  func removeThenInstallInputMethod() {
    // if !FileManager.default.fileExists(atPath: kTargetPartialPath) {
    //   installInputMethod(
    //     previousExists: false, previousVersionNotFullyDeactivatedWarning: false
    //   )
    //   return
    // }

    guard let window = window else { return }

    let shouldWaitForTranslocationRemoval =
      Reloc.isAppBundleTranslocated(atPath: kTargetPartialPath)
        && window.responds(to: #selector(NSWindow.beginSheet(_:completionHandler:)))

    // 將既存輸入法扔到垃圾桶內
    do {
      let sourceDir = kDestinationPartial
      let fileManager = FileManager.default
      let fileURLString = sourceDir + "/" + kTargetBundle
      let fileURL = URL(fileURLWithPath: fileURLString)

      // 檢查檔案是否存在
      if fileManager.fileExists(atPath: fileURLString) {
        // 塞入垃圾桶
        try fileManager.trashItem(at: fileURL, resultingItemURL: nil)
      } else {
        NSLog("File does not exist")
      }

    } catch let error as NSError {
      NSLog("An error took place: \(error)")
    }

    let killTask = Process()
    killTask.launchPath = "/usr/bin/killall"
    killTask.arguments = [kTargetBin]
    killTask.launch()
    killTask.waitUntilExit()

    let killTask2 = Process()
    killTask2.launchPath = "/usr/bin/killall"
    killTask2.arguments = [kTargetBinPhraseEditor]
    killTask2.launch()
    killTask2.waitUntilExit()

    if shouldWaitForTranslocationRemoval {
      progressIndicator.startAnimation(self)
      window.beginSheet(progressSheet) { returnCode in
        DispatchQueue.main.async {
          if returnCode == .continue {
            self.installInputMethod(
              previousExists: true,
              previousVersionNotFullyDeactivatedWarning: false
            )
          } else {
            self.installInputMethod(
              previousExists: true,
              previousVersionNotFullyDeactivatedWarning: true
            )
          }
        }
      }

      translocationRemovalStartTime = Date()
      Timer.scheduledTimer(
        timeInterval: kTranslocationRemovalTickInterval, target: self,
        selector: #selector(timerTick(_:)), userInfo: nil, repeats: true
      )
    } else {
      installInputMethod(
        previousExists: false, previousVersionNotFullyDeactivatedWarning: false
      )
    }
  }

  func installInputMethod(
    previousExists _: Bool, previousVersionNotFullyDeactivatedWarning warning: Bool
  ) {
    guard
      let targetBundle = Bundle.main.path(forResource: kTargetBin, ofType: kTargetType)
    else {
      return
    }
    let cpTask = Process()
    cpTask.launchPath = "/bin/cp"
    print(kDestinationPartial)
    cpTask.arguments = [
      "-R", targetBundle, kDestinationPartial,
    ]
    cpTask.launch()
    cpTask.waitUntilExit()

    if cpTask.terminationStatus != 0 {
      runAlertPanel(
        title: NSLocalizedString("Install Failed", comment: ""),
        message: NSLocalizedString("Cannot copy the file to the destination.", comment: ""),
        buttonTitle: NSLocalizedString("Cancel", comment: "")
      )
      endAppWithDelay()
    }

    _ = try? shell("/usr/bin/xattr -drs com.apple.quarantine \(kTargetPartialPath)")

    guard let theBundle = Bundle(url: imeURLInstalled),
          let imeIdentifier = theBundle.bundleIdentifier
    else {
      endAppWithDelay()
      return
    }

    let imeBundleURL = theBundle.bundleURL

    if allRegisteredInstancesOfThisInputMethod.isEmpty {
      NSLog("Registering input source \(imeIdentifier) at \(imeBundleURL.absoluteString).")
      let status = (TISRegisterInputSource(imeBundleURL as CFURL) == noErr)
      if !status {
        let message = String(
          format: NSLocalizedString(
            "Cannot find input source %@ after registration.", comment: ""
          ),
          imeIdentifier
        )
        runAlertPanel(
          title: NSLocalizedString("Fatal Error", comment: ""), message: message,
          buttonTitle: NSLocalizedString("Abort", comment: "")
        )
        endAppWithDelay()
        return
      }

      if allRegisteredInstancesOfThisInputMethod.isEmpty {
        let message = String(
          format: NSLocalizedString(
            "Cannot find input source %@ after registration.", comment: ""
          ),
          imeIdentifier
        )
        runAlertPanel(
          title: NSLocalizedString("Fatal Error", comment: ""), message: message,
          buttonTitle: NSLocalizedString("Abort", comment: "")
        )
      }
    }

    var mainInputSourceEnabled = false

    allRegisteredInstancesOfThisInputMethod.forEach { neta in
      let isActivated = neta.isActivated
      defer {
        // 如果使用者在升級安裝或再次安裝之前已經有啟用威注音任一簡繁模式的話，則標記安裝成功。
        // 這樣可以尊重某些使用者「僅使用簡體中文」或「僅使用繁體中文」的習慣。
        mainInputSourceEnabled = mainInputSourceEnabled || isActivated
      }
      if isActivated, !isMonterey { return }
      // WARNING: macOS 12 may return false positives, hence forced activation.
      if neta.activate() {
        NSLog("Input method enabled: \(imeIdentifier)")
      } else {
        NSLog("Failed to enable input method: \(imeIdentifier)")
      }
    }

    // Alert Panel
    let ntfPostInstall = NSAlert()
    if warning {
      ntfPostInstall.messageText = NSLocalizedString("Attention", comment: "")
      ntfPostInstall.informativeText = NSLocalizedString(
        "vChewing is upgraded, but please log out or reboot for the new version to be fully functional.",
        comment: ""
      )
      ntfPostInstall.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    } else {
      if !mainInputSourceEnabled, !isMonterey {
        ntfPostInstall.messageText = NSLocalizedString("Warning", comment: "")
        ntfPostInstall.informativeText = NSLocalizedString(
          "Input method may not be fully enabled. Please enable it through System Preferences > Keyboard > Input Sources.",
          comment: ""
        )
        ntfPostInstall.addButton(withTitle: NSLocalizedString("Continue", comment: ""))
      } else {
        ntfPostInstall.messageText = NSLocalizedString(
          "Installation Successful", comment: ""
        )
        ntfPostInstall.informativeText = NSLocalizedString(
          "vChewing is ready to use. \n\nPlease relogin if this is the first time you install it in this user account.",
          comment: ""
        )
        ntfPostInstall.addButton(withTitle: NSLocalizedString("OK", comment: ""))
      }
    }
    ntfPostInstall.beginSheetModal(for: window!) { _ in
      self.endAppWithDelay()
    }
  }
}
