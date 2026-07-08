+.PHONY: all

# 定义共享常量
XCODEBUILD := /Applications/Xcode-15.app/Contents/Developer/usr/bin/xcodebuild
SDK := /Applications/Xcode-15.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.3.sdk
TOOLCHAIN := /Applications/Xcode-15.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain

# LibARCLite 路徑
ARC_LIB_SRC := $(PWD)/ARCLite/libarclite_macosx.a
ARC_LIB_DIR := $(TOOLCHAIN)/usr/lib/arc
ARC_LIB_DEST := $(ARC_LIB_DIR)/libarclite_macosx.a

# 定义日期和时间变量
DATE_DIR := $(shell date +%Y-%m-%d)
DATE_FILE := $(shell date +%Y-%-m-%-d)
TIME_FILE := $(shell date +%H.%M)
ARCHIVE_DIR := $(HOME)/Library/Developer/Xcode/Archives/$(DATE_DIR)
ARCHIVE_NAME := vChewingInstallerLegacy-$(DATE_FILE)-$(TIME_FILE).xcarchive
ARCHIVE_PATH := $(ARCHIVE_DIR)/$(ARCHIVE_NAME)

all: archive
install: install-release
update:
	@git restore ./DictionaryData
	git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 submodule update --init --recursive --remote --force

ifdef ARCHS
BUILD_SETTINGS += ARCHS="$(ARCHS)"
BUILD_SETTINGS += ONLY_ACTIVE_ARCH=NO
endif

# 確認 LibARCLite 已在 toolchain 內就位（x86_64 建置需要）
setup-arc:
	@if [ ! -f "$(ARC_LIB_DEST)" ]; then \
		echo "→ 設定 LibARCLite 符號連結至 toolchain …"; \
		sudo mkdir -p "$(ARC_LIB_DIR)" && \
		sudo ln -sf "$(ARC_LIB_SRC)" "$(ARC_LIB_DEST)" && \
		echo "  LibARCLite 符號連結已建立。"; \
	fi

archive: setup-arc release

release: setup-arc
	@echo "Creating directory: $(ARCHIVE_DIR)"
	@mkdir -p "$(ARCHIVE_DIR)"
	@echo "Archiving to: $(ARCHIVE_PATH)"
	$(XCODEBUILD) archive \
	-project vChewing-OSX-Legacy.xcodeproj \
	-scheme vChewingInstallerLegacy \
	-configuration Release \
	-archivePath "$(ARCHIVE_PATH)" \
	-sdk $(SDK) \
	-allowProvisioningUpdates \
	TOOLCHAINS=$(TOOLCHAIN)

debug: setup-arc
	@echo "Building debug configuration"
	$(XCODEBUILD) build \
	-project vChewing-OSX-Legacy.xcodeproj \
	-scheme vChewingInstallerLegacy \
	-configuration Debug \
	-sdk $(SDK) \
	TOOLCHAINS=$(TOOLCHAIN)

debug-core:
	@echo "Building debug configuration"
	$(XCODEBUILD) build \
	-project vChewing-OSX-Legacy.xcodeproj \
	-scheme vChewing \
	-configuration Debug \
	-sdk $(SDK) \
	TOOLCHAINS=$(TOOLCHAIN)

DSTROOT = /Library/Input Methods
VC_APP_ROOT = $(DSTROOT)/vChewing.app

.PHONY: lint format

format:
	@swiftformat --swiftversion 5.5 --indent 2 ./

lint:
	@echo "Running SwiftLint on tracked Swift files..."
	@files="$$(git ls-files -- '*.swift' ':!Build/**' ':!Packages/Build/**' ':!Packages/**/.build/')"; \
	if [ -z "$$files" ]; then \
		echo "No Swift files tracked by git."; \
	else \
		printf '%s\n' "$$files" | tr '\n' '\0' | \
		xargs -0 swiftlint lint --fix --autocorrect --config .swiftlint.yml --; \
	fi

.PHONY: permission-check install-debug install-release

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(VC_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: permission-check
	open Build/Products/Debug/vChewingInstallerLegacy.app

install-release: permission-check
	open Build/Products/Release/vChewingInstallerLegacy.app

.PHONY: clean

clean:
	$(XCODEBUILD) -scheme vChewingInstallerLegacy -configuration Debug $(BUILD_SETTINGS) clean
	$(XCODEBUILD) -scheme vChewingInstallerLegacy -configuration Release $(BUILD_SETTINGS) clean
	make clean --file=./Source/Data/Makefile || true

clean-spm:
	find . -name ".build" -exec rm -rf {} \;
	rm -rf ./Packages/Build

.PHONY: gc

gc:
	git reflog expire --expire=now --all && git gc --prune=now --aggressive

.PHONY: test

test:
	xcodebuild -project vChewing-OSX-Legacy.xcodeproj -scheme vChewing -configuration Debug test

.PHONY: gitrelease

gitrelease:
	@echo "Running git release script for vChewing-OSX-legacy..."
	@chmod +x ./Scripts/vchewing-update.swift || true
	@if [ "$(DRY_RUN)" = "true" ]; then \
		./Scripts/vchewing-update.swift --path . --dry-run; \
	else \
		./Scripts/vchewing-update.swift --path .; \
	fi
