#!/bin/bash

# 检查参数
if [ $# -ne 3 ]; then
    echo "Usage: $0 <environment> <version> <app-name>"
    echo "Example: $0 uat1 552555 a-service"
    exit 1
fi

# 获取参数
ENVIRONMENT=$1
VERSION=$2
APP_NAME=$3

# 加载变量配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/variables.sh"

# 获取目标路径
RELEASE_PATH=$(get_service_release_path ${ENVIRONMENT} ${APP_NAME} ${VERSION})
DEPLOY_PATH=$(get_service_deploy_path ${ENVIRONMENT} ${APP_NAME})

# 创建release目录
mkdir -p "${RELEASE_PATH}"
if [ $? -ne 0 ]; then
    echo "Failed to create release directory: ${RELEASE_PATH}"
    exit 1
fi

# 下载JAR包
JAR_NAME="${APP_NAME}-${VERSION}.jar"
JAR_URL="${JAR_DOWNLOAD_URL_PREFIX}/${APP_NAME}/${VERSION}/${JAR_NAME}"
JAR_PATH="${RELEASE_PATH}/${JAR_NAME}"

echo "Downloading JAR from: ${JAR_URL}"
wget -q -O "${JAR_PATH}" "${JAR_URL}"
if [ $? -ne 0 ]; then
    echo "Failed to download JAR file"
    rm -f "${JAR_PATH}"
    exit 1
fi

# 验证JAR包
if [ ! -f "${JAR_PATH}" ]; then
    echo "JAR file not found after download"
    exit 1
fi

# 创建deployment目录（如果不存在）
mkdir -p "$(dirname "${DEPLOY_PATH}")"
if [ $? -ne 0 ]; then
    echo "Failed to create deployment directory structure"
    exit 1
fi

# 更新软链接
if [ -L "${DEPLOY_PATH}" ]; then
    rm -f "${DEPLOY_PATH}"
elif [ -e "${DEPLOY_PATH}" ]; then
    echo "Error: ${DEPLOY_PATH} exists but is not a symbolic link"
    exit 1
fi

ln -s "${RELEASE_PATH}" "${DEPLOY_PATH}"
if [ $? -ne 0 ]; then
    echo "Failed to create symbolic link"
    exit 1
fi

echo "Successfully deployed ${APP_NAME} version ${VERSION} to ${ENVIRONMENT}"
exit 0