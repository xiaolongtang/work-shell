#!/bin/bash

# 检查参数
if [ $# -ne 2 ]; then
    echo "Usage: $0 <environment> <app-name>"
    echo "Example: $0 uat1 a-service"
    exit 1
fi

# 获取参数
ENVIRONMENT=$1
APP_NAME=$2

# 加载变量配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/variables.sh"

# 获取release目录路径
RELEASE_BASE_PATH="$(get_deploy_path ${ENVIRONMENT})/release/${APP_NAME}"

# 检查目录是否存在
if [ ! -d "${RELEASE_BASE_PATH}" ]; then
    echo "Release directory does not exist: ${RELEASE_BASE_PATH}"
    exit 0
fi

# 获取所有版本目录并按修改时间排序
VERSION_DIRS=($(ls -t "${RELEASE_BASE_PATH}" 2>/dev/null))

# 如果目录数量超过10个，删除旧的目录
if [ ${#VERSION_DIRS[@]} -gt 10 ]; then
    echo "Found ${#VERSION_DIRS[@]} versions, keeping only the 10 most recent ones"
    
    for ((i=10; i<${#VERSION_DIRS[@]}; i++)); do
        DIR_TO_REMOVE="${RELEASE_BASE_PATH}/${VERSION_DIRS[i]}"
        echo "Removing old version directory: ${DIR_TO_REMOVE}"
        
        # 检查目录是否被软链接引用
        LINK_COUNT=$(find "$(get_deploy_path ${ENVIRONMENT})/deployment" -type l -lname "${DIR_TO_REMOVE}*" | wc -l)
        
        if [ ${LINK_COUNT} -eq 0 ]; then
            rm -rf "${DIR_TO_REMOVE}"
            if [ $? -ne 0 ]; then
                echo "Warning: Failed to remove directory: ${DIR_TO_REMOVE}"
            fi
        else
            echo "Warning: Directory ${DIR_TO_REMOVE} is still in use by deployment, skipping removal"
        fi
    done
else
    echo "Found ${#VERSION_DIRS[@]} versions, no cleanup needed"
fi

exit 0