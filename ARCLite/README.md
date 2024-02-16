# LibARCLite

此處置放了取自 Xcode 14.2 的 LibARCLite。

如果您使用了自 Xcode 14.3 開始的新版 Xcode 的話，只有給您的 Xcode 打上 LibARCLite 修補、才可以將威注音 Aqua 紀念版建置給比 macOS 10.13 更早的系統版本。修補方法就是將這個檔案放在下述目錄：
```
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc
```
如果沒有最後的 arc 目錄的話，請自行建立。

P.S.: 如果您用的是 Xcode 15 開始的版本的話，還請另將系統 SDK 換成 macOS 13.1 或 13.3 的 SDK。
- macOS 13.1 的 SDK 可取自 Xcode 14.2，正好可以與 LibARCLite 一起取出來。
- macOS 13.3 的 SDK 可取自 Xcode 14.3.1，也可以前往此處這裡下載：
```
https://github.com/alexey-lysiuk/macos-sdk/releases/tag/13.3
```

$ EOF.