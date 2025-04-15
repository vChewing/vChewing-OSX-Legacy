+.PHONY: all

# 定义日期和时间变量
DATE_DIR := $(shell date +%Y-%m-%d)
DATE_FILE := $(shell date +%Y-%-m-%-d)
TIME_FILE := $(shell date +%H.%M)
ARCHIVE_DIR := $(HOME)/Library/Developer/Xcode/Archives/$(DATE_DIR)
ARCHIVE_NAME := vChewingInstallerLegacy-$(DATE_FILE)-$(TIME_FILE).xcarchive
ARCHIVE_PATH := $(ARCHIVE_DIR)/$(ARCHIVE_NAME)

all: release
install: install-release
update:
	@git restore ./DictionaryData
	git submodule update --init --recursive --remote --force

ifdef ARCHS
BUILD_SETTINGS += ARCHS="$(ARCHS)"
BUILD_SETTINGS += ONLY_ACTIVE_ARCH=NO
endif

release:
	@echo "Creating directory: $(ARCHIVE_DIR)"
	@mkdir -p "$(ARCHIVE_DIR)"
	@echo "Archiving to: $(ARCHIVE_PATH)"
	/Applications/Xcode-15.app/Contents/Developer/usr/bin/xcodebuild archive \
	-project vChewing-OSX-Legacy.xcodeproj \
	-scheme vChewingInstallerLegacy \
	-configuration Release \
	-archivePath "$(ARCHIVE_PATH)" \
	-sdk /Applications/Xcode-15.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.1.sdk \
	-allowProvisioningUpdates \
	TOOLCHAINS=/Applications/Xcode-15.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain

debug: 
	xcodebuild -project vChewing-OSX-Legacy.xcodeproj -scheme vChewingInstaller -configuration Debug $(BUILD_SETTINGS) build

DSTROOT = /Library/Input Methods
VC_APP_ROOT = $(DSTROOT)/vChewing.app

.PHONY: lint format

format:
	@swiftformat --swiftversion 5.5 --indent 2 ./

lint:
	@git ls-files --exclude-standard | grep -E '\.swift$$' | swiftlint --fix --autocorrect

.PHONY: permission-check install-debug install-release

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(VC_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: permission-check
	open Build/Products/Debug/vChewingInstaller.app

install-release: permission-check
	open Build/Products/Release/vChewingInstaller.app

.PHONY: clean

clean:
	xcodebuild -scheme vChewingInstaller -configuration Debug $(BUILD_SETTINGS)  clean
	xcodebuild -scheme vChewingInstaller -configuration Release $(BUILD_SETTINGS) clean
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
