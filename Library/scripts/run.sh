#!/bin/bash

FRAMEWORK_NAME="MUH-FRAMEWORK-NAME"

# 定义变量
LIBRARY="$SRCROOT/Library"
TARGET_APP_PATH="${TARGET_BUILD_DIR}/${TARGET_NAME}.app"
PROVISION_PROFILE="/Users/${USER}/Library/MobileDevice/Provisioning Profiles"
OPTOOL="$LIBRARY/bin/optool"

# 预处理指令
echo "================================================================"
echo "【Install optool】"
chmod 777 "${OPTOOL}"
install_optool() {
	if [[ ! -e /usr/local/bin/optool ]]; then
		echo "Install optool to this mac"
		cp ${OPTOOL} /usr/local/bin/optool
	else
		echo "This mac has installed optool"
	fi
}
install_optool

# 本地安装 Cycript
echo "================================================================"
echo "【Install Cycript】"
install_cycript() {
	if [[ ! -e /usr/local/bin/cycript ]]; then
		echo "Install cycript to this mac"
		cp ${SRCROOT}/bin/cycript /usr/local/bin/cycript
		cp -rf ${SRCROOT}/bin/Cycript.lib /usr/local/bin/Cycript.lib
	else
		echo "This mac has installed cycript"
	fi
}
install_cycript

# 导出头文件
echo "================================================================"
echo "【Dump Headers】"
dump_header() {
	local CLASS_DUMP="$LIBRARY/bin/class-dump"
	local CLASS_DUMP_LOCK=${SRCROOT}/$TARGET_NAME/Headers/class-dump.lock
	local ORIGIN_BINARY="${SRCROOT}/Resources/Packages/${TARGET_NAME}.app/$TARGET_NAME"
	local HEADER_OUTPUT="$SRCROOT/$TARGET_NAME/Headers"
	chmod 777 $CLASS_DUMP
	if [[ ! -e $CLASS_DUMP_LOCK ]]; then
		echo "Class dumping."
		$CLASS_DUMP -H "${ORIGIN_BINARY}" -o "${HEADER_OUTPUT}" && touch $CLASS_DUMP_LOCK
	else
		echo "Skip"
	fi
}
dump_header

# 恢复符号表
echo "================================================================"
echo "【Restore Symbol】"
restore_symbol() {
	local ORIGIN_BINARY="${SRCROOT}/Resources/Packages/${TARGET_NAME}.app/$TARGET_NAME"
	local RESTORE_SYMBOL_LOCK="${SRCROOT}/Resources/Packages/${TARGET_NAME}.restore_symbol_lock"
	local RESTORE_SYMBOL="${LIBRARY}/bin/restore-symbol"
	local TEMP_BINARY="${ORIGIN_BINARY}.symbol"
	chmod 777 $RESTORE_SYMBOL
	if [[ ! -e $RESTORE_SYMBOL_LOCK ]]; then
		echo "Restore symbol"
		$RESTORE_SYMBOL -o "${TEMP_BINARY}" "${ORIGIN_BINARY}"
		rm "${ORIGIN_BINARY}"
		mv "${TEMP_BINARY}" "${ORIGIN_BINARY}"
		echo "1" > "${RESTORE_SYMBOL_LOCK}"
	else
		echo "Skip"
	fi
}
restore_symbol

# 替换 app 文件
echo "================================================================"
echo "【Package Replace】"
echo "Remove origin package"
rm -rf "${TARGET_APP_PATH}"

echo "Replace real package"
cp -r "${SRCROOT}/Resources/Packages/${TARGET_NAME}.app" "${TARGET_APP_PATH}"

echo "Set executable"
chmod 777 "${TARGET_APP_PATH}/${TARGET_NAME}"

echo "Remove UISupportedDevices"
/usr/libexec/PlistBuddy -c 'Delete :UISupportedDevices' "${TARGET_APP_PATH}/Info.plist"

echo "Remove PlugIns"
rm -rf "${TARGET_APP_PATH}/PlugIns"

echo "Remove Watch"
rm -rf "${TARGET_APP_PATH}/Watch"

echo "Embed profile"
cp "${PROVISION_PROFILE}/${EXPANDED_PROVISIONING_PROFILE}.mobileprovision" "${TARGET_APP_PATH}/embedded.mobileprovision"

if [[ ! -d "${TARGET_APP_PATH}/Frameworks" ]]; then
	echo "Create Frameworks folder"
	mkdir "${TARGET_APP_PATH}/Frameworks"	
fi

# 导入 LookinServer
echo "================================================================"
echo "【Install LookinServer】"
inject_LookinServer() {
	local LOOKIN_SERVER="$LIBRARY/Frameworks/LookinServer.framework"
	if [[ ${CONFIGURATION} == "Debug" ]]; then
		echo "Embed LookinServer.framework"
		cp -r "${LOOKIN_SERVER}" "${TARGET_APP_PATH}/Frameworks/LookinServer.framework"
		"${OPTOOL}" install -p "@executable_path/Frameworks/LookinServer.framework/LookinServer" -t "${TARGET_APP_PATH}/${TARGET_NAME}"
	else
		echo "Skip"
	fi
}
inject_LookinServer

# 导入 AppPlugin.framework
echo "================================================================"
echo "【Install ${FRAMEWORK_NAME}】"
inject_plugin() {
	local BUILD_FRAMEWORK="${TARGET_BUILD_DIR}/${FRAMEWORK_NAME}.framework"
	local TARGET_FRAMEWORK="${TARGET_APP_PATH}/Frameworks/${FRAMEWORK_NAME}.framework"
	echo "Embed $FRAMEWORK_NAME"
	cp -r "${BUILD_FRAMEWORK}" "${TARGET_FRAMEWORK}"
	"${OPTOOL}" install -p "@executable_path/Frameworks/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" -t "${TARGET_APP_PATH}/${TARGET_NAME}"
}
inject_plugin

# 重签名 Frameworks 文件夹
echo "================================================================"
echo "【Code Sign】"
Frameworks="${TARGET_APP_PATH}/Frameworks"
for file in $Frameworks/*; do
	echo "CodeSign -fs $file"
	codesign -fs "${EXPANDED_CODE_SIGN_IDENTITY_NAME}" "$file"
done

# 打包文件
echo "================================================================"
echo "【Archive】"
if [[ ${CONFIGURATION} == "Release" ]]; then
	echo "Create temp folder"
	mkdir "${SRCROOT}/Products/.temp"
	mkdir "${SRCROOT}/Products/.temp/Payload"
	echo "Copy package"
	cp -rf "${TARGET_APP_PATH}" "${SRCROOT}/Products/.temp/Payload/${TARGET_NAME}.app"
	echo "Package"
	cd "${SRCROOT}/Products/.temp"
	zip -qry "${TARGET_NAME}.ipa" Payload
	if [[ -f "../${TARGET_NAME}.ipa" ]]; then
		rm "../${TARGET_NAME}.ipa"
	fi
	mv "${TARGET_NAME}.ipa" "../${TARGET_NAME}.ipa"
	cd "${SRCROOT}/Products"
	echo "Clean temp folder"
	rm -rf ".temp"
else
	echo "Skip"
fi
