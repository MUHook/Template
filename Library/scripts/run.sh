#!/bin/bash

FRAMEWORK_NAME="MUH-FRAMEWORK-NAME"

# 定义变量
TARGET_APP_PATH="${TARGET_BUILD_DIR}/${TARGET_NAME}.app"
PROVISION_PROFILE="/Users/${USER}/Library/MobileDevice/Provisioning Profiles"
OPTOOL="${SRCROOT}/Library/bin/optool"

# 预处理指令
chmod 777 "${OPTOOL}"

# 提取 LookinServer
if [[ ${CONFIGURATION} == "Debug" ]]; then
	LOOKIN_CACHE="${TARGET_BUILD_DIR}/LookinServer.framework"
	if [[ -d "${LOOKIN_CACHE}" ]]; then
	echo "Found LookinServer.framework cache"
	else
	echo "Cache LookinServer.framework"
	cp -r "${TARGET_APP_PATH}/Frameworks/LookinServer.framework" "${LOOKIN_CACHE}"
	fi
fi

# 替换 app 文件
rm -rf "${TARGET_APP_PATH}"
cp -r "${SRCROOT}/Resources/Packages/${TARGET_NAME}.app" "${TARGET_APP_PATH}"

# 设置支持的设备
/usr/libexec/PlistBuddy -c "Add :UISupportedDevices: string ${TARGET_DEVICE_MODEL}" "${TARGET_APP_PATH}/Info.plist"

# 导入 Framework
mkdir "${TARGET_APP_PATH}/Frameworks"

# 导入 LookinServer
if [[ ${CONFIGURATION} == "Debug" ]]; then
	cp -r "${LOOKIN_CACHE}" "${TARGET_APP_PATH}/Frameworks/LookinServer.framework"
	"${OPTOOL}" install -p "@executable_path/Frameworks/LookinServer.framework/LookinServer" -t "${TARGET_APP_PATH}/${TARGET_NAME}"
fi

# 导入 AppPlugin.framework
cp -r "${TARGET_BUILD_DIR}/${FRAMEWORK_NAME}.framework" "${TARGET_APP_PATH}/Frameworks/${FRAMEWORK_NAME}.framework"
"${OPTOOL}" install -p "@executable_path/Frameworks/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" -t "${TARGET_APP_PATH}/${TARGET_NAME}"

# 设置可执行文件
chmod 777 "${TARGET_APP_PATH}/${TARGET_NAME}"

# 删除 PlugIns 文件夹
rm -rf "${TARGET_APP_PATH}/PlugIns"

# 删除 Watch 文件夹
rm -rf "${TARGET_APP_PATH}/Watch"

# 重签名 Frameworks 文件夹
if [[ ${CONFIGURATION} == "Debug" ]]; then
	Frameworks="${TARGET_APP_PATH}/Frameworks"
	for file in $Frameworks/*; do
	echo "codesign -fs $file"
	codesign -fs "${EXPANDED_CODE_SIGN_IDENTITY_NAME}" "$file"
	done
fi

# 嵌入描述文件
if [[ ${CONFIGURATION} == "Debug" ]]; then
	cp "${PROVISION_PROFILE}/${EXPANDED_PROVISIONING_PROFILE}.mobileprovision" "${TARGET_APP_PATH}/embedded.mobileprovision"
fi

# 打包文件
if [[ ${CONFIGURATION} == "Release" ]]; then
	mkdir "${SRCROOT}/Products/.temp"
	mkdir "${SRCROOT}/Products/.temp/Payload"
	cp -rf "${TARGET_APP_PATH}" "${SRCROOT}/Products/.temp/Payload/${TARGET_NAME}.app"
	cd "${SRCROOT}/Products/.temp"
	zip -qry "${TARGET_NAME}.ipa" Payload
	if [[ -f "../${TARGET_NAME}.ipa" ]]; then
		rm "../${TARGET_NAME}.ipa"
	fi
	mv "${TARGET_NAME}.ipa" "../${TARGET_NAME}.ipa"
	cd "${SRCROOT}/Products"
	rm -rf ".temp"
fi
