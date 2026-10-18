SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT ?= BilibiliLive.xcodeproj
SCHEME ?= BilibiliLive
CONFIGURATION ?= Release
BUILD_DIR ?= build
ARCHIVE_PATH ?= $(BUILD_DIR)/BilibiliLive.xcarchive
EXPORT_PATH ?= $(BUILD_DIR)/export
EXPORT_OPTIONS_PLIST ?= $(BUILD_DIR)/ExportOptions.plist
# Keep generated Swift sources outside the repository's SwiftFormat scan.
DERIVED_DATA_PATH ?= $(HOME)/Library/Developer/Xcode/DerivedData/BilibiliLive-Package
SOURCE_PACKAGES_DIR ?= $(DERIVED_DATA_PATH)/SourcePackages
SIGNING_ARGS ?=

.PHONY: help package resolve archive export export-options package-unsigned

help:
	@echo 'make package           签名归档并导出 build/export/BilibiliLive.ipa'
	@echo 'make archive           仅生成 build/BilibiliLive.xcarchive'
	@echo 'make resolve           按锁文件准备依赖，跳过共享仓库缓存'
	@echo 'make export            用已有归档重新导出 IPA'
	@echo 'make package-unsigned  生成 build/export/BilibiliLive-unsigned.ipa，供自行重签'
	@echo '可覆盖 ARCHIVE_PATH、EXPORT_PATH、EXPORT_OPTIONS_PLIST、SOURCE_PACKAGES_DIR 等变量。'

# Recursive targets deliberately run in sequence, including under make -j.
package:
	$(MAKE) archive
	$(MAKE) export

# Resolve before moving the previous archive. The shared SwiftPM repository
# cache can lack commits present in Package.resolved even on a fresh checkout.
resolve:
	xcodebuild -resolvePackageDependencies -project "$(PROJECT)" -scheme "$(SCHEME)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		-clonedSourcePackagesDirPath "$(SOURCE_PACKAGES_DIR)" \
		-disablePackageRepositoryCache -onlyUsePackageVersionsFromResolvedFile

archive: resolve
	@mkdir -p "$$(dirname "$(ARCHIVE_PATH)")"
	@if [ -e "$(ARCHIVE_PATH)" ]; then \
		mv "$(ARCHIVE_PATH)" "$(ARCHIVE_PATH).previous.$$(date +%Y%m%d-%H%M%S)-$$$$"; \
	fi
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" -destination 'generic/platform=tvOS' \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		-clonedSourcePackagesDirPath "$(SOURCE_PACKAGES_DIR)" \
		-skipPackageUpdates -onlyUsePackageVersionsFromResolvedFile \
		-archivePath "$(ARCHIVE_PATH)" -allowProvisioningUpdates $(SIGNING_ARGS) archive

export-options:
	@mkdir -p "$$(dirname "$(EXPORT_OPTIONS_PLIST)")"
	@if [ ! -f "$(EXPORT_OPTIONS_PLIST)" ]; then \
		cp config/ExportOptions.plist "$(EXPORT_OPTIONS_PLIST)"; \
	fi
	plutil -lint "$(EXPORT_OPTIONS_PLIST)"

export: export-options
	xcodebuild -exportArchive \
		-archivePath "$(ARCHIVE_PATH)" \
		-exportPath "$(EXPORT_PATH)" \
		-exportOptionsPlist "$(EXPORT_OPTIONS_PLIST)" \
		-allowProvisioningUpdates
	@test -f "$(EXPORT_PATH)/BilibiliLive.ipa"
	@echo "IPA: $(EXPORT_PATH)/BilibiliLive.ipa"

package-unsigned:
	$(MAKE) archive ARCHIVE_PATH="$(BUILD_DIR)/BilibiliLive-unsigned.xcarchive" \
		SIGNING_ARGS='CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='
	@set -eo pipefail; \
	stage=$$(mktemp -d "$${TMPDIR:-/tmp}/BilibiliLive-package.XXXXXX"); \
	trap 'rm -rf "$$stage"' EXIT; \
	mkdir -p "$$stage/Payload" "$(EXPORT_PATH)"; \
	ditto "$(BUILD_DIR)/BilibiliLive-unsigned.xcarchive/Products/Applications/BilibiliLive.app" "$$stage/Payload/BilibiliLive.app"; \
	ditto -c -k --keepParent "$$stage/Payload" "$(EXPORT_PATH)/BilibiliLive-unsigned.ipa"; \
	unzip -t "$(EXPORT_PATH)/BilibiliLive-unsigned.ipa" | tail -n 1; \
	echo "IPA: $(EXPORT_PATH)/BilibiliLive-unsigned.ipa"
