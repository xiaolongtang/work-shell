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

# 验证环境参数
valid_env=false
for env in "${ENVIRONMENTS[@]}"; do
    if [ "${env}" == "${ENVIRONMENT}" ]; then
        valid_env=true
        break
    fi
done

if [ "${valid_env}" != "true" ]; then
    echo "Error: Invalid environment '${ENVIRONMENT}'"
    exit 1
fi

# 验证服务名称
valid_service=false
for service in "${SERVICES[@]}"; do
    if [ "${service}" == "${APP_NAME}" ]; then
        valid_service=true
        break
    fi
done

if [ "${valid_service}" != "true" ]; then
    echo "Error: Invalid service name '${APP_NAME}'"
    exit 1
fi

# 执行部署流程
echo "Starting deployment process for ${APP_NAME} version ${VERSION} in ${ENVIRONMENT} environment"

# 1. 停止服务
echo "Stopping service..."
"${SCRIPT_DIR}/start-stop.sh" "${APP_NAME}" "${ENVIRONMENT}" "stop"
if [ $? -ne 0 ]; then
    echo "Failed to stop service"
    exit 1
fi

# 2. 复制应用包
echo "Copying application package..."
"${SCRIPT_DIR}/copy_app_script_deployment.sh" "${ENVIRONMENT}" "${VERSION}" "${APP_NAME}"
if [ $? -ne 0 ]; then
    echo "Failed to copy application package"
    exit 1
fi

# 3. 执行清理
echo "Performing housekeeping..."
"${SCRIPT_DIR}/housekeeping.sh" "${ENVIRONMENT}" "${APP_NAME}"
if [ $? -ne 0 ]; then
    echo "Warning: Housekeeping failed but continuing with deployment"
fi

# 4. 启动服务
echo "Starting service..."
"${SCRIPT_DIR}/start-stop.sh" "${APP_NAME}" "${ENVIRONMENT}" "start"
if [ $? -ne 0 ]; then
    echo "Failed to start service"
    exit 1
fi

echo "Deployment completed successfully"
exit 0