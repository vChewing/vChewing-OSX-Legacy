有關威注音輸入法的最新資訊，請洽產品主頁：[https://vchewing.github.io/](https://vchewing.github.io/)

# vChewing Aqua Edition 威注音輸入法 Aqua 版

⚠️**注意**：該版本主要針對 macOS 10.9 至 macOS 12 這幾版作業系統而設計。macOS 13 開始的系統的使用者請洽上文網址下載目前的主流版本的威注音輸入法。該倉庫不接受外來 PR，直接封存。有功能問題或故障的話，請在上文提到的產品主頁內尋找故障提報方式、或者直接在[主倉庫的工單區](https://github.com/vChewing/vChewing-macOS/issues)內開工單。

威注音分支專案及威注音詞庫由孫志貴（Shiki Suen）維護，其內容屬於可在 Gitee 公開展示的合法內容。小麥注音官方原始倉庫內的詞庫的內容均與孫志貴無關。

P.S.: 威注音輸入法的 Shift 按鍵監測功能僅藉由對 NSEvent 訊號資料流的上下文關係的觀測來實現，僅接觸藉由 macOS 系統內建的 InputMethodKit 當中的 IMKServer 傳來的 NSEvent 訊號資料流、而無須監聽系統全局鍵盤事件，也無須向使用者申請用以達成這類「可能會引發資安疑慮」的行為所需的輔助權限，更不會將您的電腦內的任何資料傳出去（本來就是這樣，且自威注音 2.3.0 版引入的 Sandbox 特性更杜絕了這種可能性）。請放心使用。Shift 中英模式切換功能要求至少 macOS 10.15 Catalina 才可以用。

## 系統需求

### 對二次開發者而言，建置用建議系統需求：

- 至少 Xcode 15.1 且有補過下述元件（詳見本倉庫 `./ARCLite/README.md`）：
    - LibArcLite：可以從 Xcode 14.2 取得。本倉庫隨附了一份可用於 macOS 目標建置的拷貝。
    - macOS 10.13.1 SDK：可以從 Xcode 14.2 取得。
    - 不補裝上述元件的話，您只能建置給 macOS 10.13 High Sierra 開始的系統。
        - 這樣一來還不如去用威注音主流發行版的倉庫。
- 作業系統：能運行上述建置環境的 macOS 作業系統。

### 對二次開發者而言，建置用最低系統需求：

- 任何同時支援 macOS 10.9 Mavericks 軟體建置、且支援至少 Swift 5.5 的 Xcode。
    - 例外：macOS 13 Ventura 能用的 Xcode 14.2 為止的版本其實是能給 macOS 10.9 建置軟體的，雖然會亮警告說系統建置目標「超出可建置目標的版本範圍」。
    - Xcode 14.3 開始的版本內建的 toolchain 不包含「libarclite」，需要使用者自行在 toolchain 當中補充 libarclite 相關檔案（可藉由更舊版的 Xcode 提取出來）。
    - 總之建議使用 Xcode 14.2。
    - 技術上無法支援藉由 Xcode 15 的建置（會有與部分 CoreFoundation 型別有關的無法避免的運行階段錯誤），除非放棄早於 macOS 10.13 的建置目標。但這會讓這個 Aqua 紀念版失去意義。
- 作業系統：能運行上述建置環境的 macOS 作業系統（可能至少 macOS 10.15 Catalina）。

### 編譯出的成品對應系統需求：

- 推薦 macOS 10.09 Mavericks（最後一代 Aqua macOS）。
- 我們不保證該專案在 macOS 10.10 至 macOS 10.12 系統下的可用性。這幾個版本的 macOS 很可能只會提供更糟糕的體驗。有條件的話，請升級到至少 macOS 10.13 High Sierra，總之越高越好，然後換用本文頂端產品主頁裡面給出的目前主流版本的威注音輸入法。

### 該版本無法使用的功能：

- 受制於舊版 macOS 自身對萬國碼的版本的支援程度，全字庫以及部分高碼位的簡體中文規範字可能無法正常顯示。
- Shift 按鍵判定功能只能在 macOS 10.15 開始的系統內生效。
- 不支援縱排顯示的工具提示視窗與組字窗，除非系統至少 macOS 10.14。
- 客體管理器無法藉由檔案面板來快速登記客體應用，只能手動填寫，除非系統至少 macOS 10.13。

## 建置流程

安裝 Xcode 之後，請先配置 Xcode 允許其直接構建在專案所在的資料夾下的 build 資料夾內。步驟：
```
「Xcode」->「Preferences...」->「Locations」；
「File」->「Project/WorkspaceSettings...」->「Advanced」；
選「Custom」->「Relative to Workspace」即可。不選的話，make 的過程會出錯。
```
在終端機內定位到威注音的克隆本地專案的本地倉庫的目錄之後，執行 `make update` 以獲取最新詞庫。

接下來就是直接開 Xcode 專案，Product -> Scheme 選「vChewingInstaller」，編譯即可。

第一次安裝完，日後程式碼或詞庫有任何修改，只要重覆上述流程，再次安裝威注音即可。

要注意的是 macOS 可能會限制同一次 login session 能終結同一個輸入法的執行進程的次數（安裝程式透過 kill input method process 來讓新版的輸入法生效）。如果安裝若干次後，發現程式修改的結果並沒有出現、或甚至輸入法已無法再選用，只需要登出目前的 macOS 系統帳號、再重新登入即可。

補記: 該輸入法最開始從小麥注音輸入法 2.2.2 分支而出。截至小麥注音輸入法 2.2.2 版為止的上游 Commit History 遞交歷史（不在本倉庫內單獨列出，）請洽[威注音主倉庫](https://github.com/vChewing/vChewing-macOS/)或小麥注音主倉庫。

## 應用授權

**威注音 Aqua 版**的專案目前僅用到 OpenVanilla for Mac 的下述程式組件（MIT License）：

- 僅供研發人員調試方便而使用的 App 版安裝程式 (by Lukhnos Liu & MJHsieh)。

威注音專案目前還用到如下的來自 Lukhnos Liu 的算法：

- 半衰記憶模組 MK2，被 Shiki Suen 用 Swift 重寫。
- 基於 Gramambular 2 組字引擎的算法、被 Shiki Suen 用 Swift 重寫（詳見 [Megrez 組字引擎](https://github.com/vChewing/Megrez)）。

威注音輸入法 macOS 版以 MIT-NTL License 授權釋出 (與 MIT 相容)：© 2021-2022 vChewing 專案。

- 威注音輸入法 macOS 版程式維護：Shiki Suen。特別感謝 Isaac Xen 與 Hiraku Wong 等人的技術協力。
- 鐵恨注音並擊處理引擎：Shiki Suen (MIT-NTL License)。
- 天權星語彙處理引擎：Shiki Suen (MIT-NTL License)。
- 威注音詞庫由 Shiki Suen 維護，以 3-Clause BSD License 授權釋出。其中的詞頻數據[由 NAER 授權用於非商業用途](https://twitter.com/ShikiSuen/status/1479329302713831424)。

使用者可自由使用、散播本軟體，惟散播時必須完整保留版權聲明及軟體授權、且「一旦經過修改便不可以再繼續使用威注音的產品名稱」。換言之，這條相對上游 MIT 而言新增的規定就是：你 Fork 可以，但 Fork 成單獨發行的產品名稱時就必須修改產品名稱。這條新增規定對 OpenVanilla 與威注音雙方都有益，免得各自的旗號被盜版下載販子等挪用做意外用途。

## 資料來源

原廠詞庫主要詞語資料來源：

- 《重編國語辭典修訂本 2015》的六字以內的詞語資料 (CC BY-ND 3.0)。
- 《CNS11643中文標準交換碼全字庫(簡稱全字庫)》 (OGDv1 License)。
- LibTaBE (by Pai-Hsiang Hsiao under 3-Clause BSD License)。
- [《新加坡華語資料庫》](https://www.languagecouncils.sg/mandarin/ch/learning-resources/singaporean-mandarin-database)。
- 原始詞頻資料取自 NAER，有經過換算處理與按需調整。
    - 威注音並未使用由 LibTaBE 內建的來自 Sinica 語料庫的詞頻資料。
- 威注音語彙庫作者自行維護新增的詞語資料，包括：
    - 盡可能所有字詞的陸規審音與齊鐵恨廣播讀音。
    - 中國大陸常用資訊電子術語等常用語，以確保簡體中文母語者在使用輸入法時不會受到審音差異的困擾。
- 其他使用者建議收錄的資料。

## 參與研發時的注意事項

歡迎參與威注音的研發。論及相關細則，請洽該倉庫內的「[CONTRIBUTING.md](./CONTRIBUTING.md)」檔案、以及《[常見問題解答](./FAQ.md)》。

敝專案採用了《[貢獻者品行準則承約書 v2.1](./code-of-conduct.md)》。考慮到上游鏈接給出的中文版翻譯與英文原文嚴重不符合的情況（會出現因執法與被執法雙方的認知偏差導致的矛盾，非常容易變成敵我矛盾），敝專案使用了自行翻譯的版本、且新增了一些能促進雙方共識的註解。

$ EOF.
