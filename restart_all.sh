#!/bin/bash

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <environment>"
    echo "Example: $0 uat1"
    exit 1
fi

# 获取参数
ENVIRONMENT=$1

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

# 检查服务状态
check_service_status() {
    local app_name=$1
    local environment=$2
    local expected_state=$3  # 'running' or 'stopped'
    
    # 使用start-stop.sh中相同的进程检测逻辑
    local pid=$(pgrep -f "java.*${app_name}.*${environment}")
    
    if [ "${expected_state}" == "running" ]; then
        if [ ! -z "${pid}" ]; then
            return 0
        else
            return 1
        fi
    else  # expected_state == "stopped"
        if [ -z "${pid}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# 停止所有服务
echo "Stopping all services in ${ENVIRONMENT}..."
for service in "${SERVICES[@]}"; do
    echo "Stopping ${service}..."
    "${SCRIPT_DIR}/start-stop.sh" "${service}" "${ENVIRONMENT}" "stop"
    
    # 验证服务是否已停止
    max_attempts=30
    attempt=1
    while ! check_service_status "${service}" "${ENVIRONMENT}" "stopped"; do
        if [ ${attempt} -ge ${max_attempts} ]; then
            echo "Failed to stop ${service}"
            exit 1
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    echo "${service} stopped successfully"
done

# 短暂等待确保所有服务完全停止
sleep 5

# 启动所有服务（按照依赖顺序）
echo "Starting all services in ${ENVIRONMENT}..."

# 首先启动基础服务
BASE_SERVICES=("eureka-server" "config-server" "gateway-service")
for service in "${BASE_SERVICES[@]}"; do
    echo "Starting ${service}..."
    "${SCRIPT_DIR}/start-stop.sh" "${service}" "${ENVIRONMENT}" "start"
    
    # 验证服务是否已启动
    max_attempts=30
    attempt=1
    while ! check_service_status "${service}" "${ENVIRONMENT}" "running"; do
        if [ ${attempt} -ge ${max_attempts} ]; then
            echo "Failed to start ${service}"
            exit 1
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    echo "${service} started successfully"
    
    # 给基础服务额外的启动时间
    sleep 10
done

# 启动其他服务
for service in "${SERVICES[@]}"; do
    # 跳过已经启动的基础服务
    if [[ " ${BASE_SERVICES[@]} " =~ " ${service} " ]]; then
        continue
    fi
    
    echo "Starting ${service}..."
    "${SCRIPT_DIR}/start-stop.sh" "${service}" "${ENVIRONMENT}" "start"
    
    # 验证服务是否已启动
    max_attempts=30
    attempt=1
    while ! check_service_status "${service}" "${ENVIRONMENT}" "running"; do
        if [ ${attempt} -ge ${max_attempts} ]; then
            echo "Failed to start ${service}"
            exit 1
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    echo "${service} started successfully"
    
    # 给每个服务一些启动时间
    sleep 5
done

echo "All services have been successfully restarted in ${ENVIRONMENT}"
exit 0