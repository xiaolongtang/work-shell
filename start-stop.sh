#!/bin/bash

# 检查参数
if [ $# -ne 3 ]; then
    echo "Usage: $0 <app-name> <environment> <command>"
    echo "Example: $0 a-service uat1 start"
    exit 1
fi

# 获取参数
APP_NAME=$1
ENVIRONMENT=$2
COMMAND=$3

# 加载变量配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/variables.sh"

# 获取服务进程ID
get_service_pid() {
    local app_name=$1
    local environment=$2
    local java_opts=$(get_java_opts ${environment} ${app_name})
    
    # 使用特定的环境标识来确保正确匹配进程
    pgrep -f "java.*${app_name}.*${environment}"
}

# 启动服务
start_service() {
    local app_name=$1
    local environment=$2
    
    # 检查服务是否已经在运行
    local pid=$(get_service_pid ${app_name} ${environment})
    if [ ! -z "${pid}" ]; then
        echo "Service ${app_name} is already running in ${environment} with PID ${pid}"
        return 1
    fi
    
    # 准备日志目录
    local log_dir=$(get_service_log_path ${environment} ${app_name})
    local oom_gc_dir=$(get_service_oom_gc_log_path ${environment} ${app_name})
    mkdir -p "${log_dir}" "${oom_gc_dir}"
    
    # 获取JAR包路径
    local jar_path="$(get_service_deploy_path ${environment} ${app_name})/${app_name}-*.jar"
    local jar_file=$(ls ${jar_path} 2>/dev/null | head -n 1)
    
    if [ -z "${jar_file}" ]; then
        echo "JAR file not found: ${jar_path}"
        return 1
    fi
    
    # 获取Java启动参数
    local java_opts=$(get_java_opts ${environment} ${app_name})
    
    # 启动服务
    nohup java ${java_opts} -jar "${jar_file}" > "${log_dir}/${app_name}.log" 2>&1 &
    
    # 等待服务启动
    sleep 5
    pid=$(get_service_pid ${app_name} ${environment})
    if [ -z "${pid}" ]; then
        echo "Failed to start service ${app_name} in ${environment}"
        return 1
    fi
    
    echo "Started ${app_name} in ${environment} with PID ${pid}"
    return 0
}

# 停止服务
stop_service() {
    local app_name=$1
    local environment=$2
    
    local pid=$(get_service_pid ${app_name} ${environment})
    if [ -z "${pid}" ]; then
        echo "Service ${app_name} is not running in ${environment}"
        return 0
    fi
    
    echo "Stopping ${app_name} in ${environment} with PID ${pid}"
    kill ${pid}
    
    # 等待服务停止
    local count=0
    while [ ${count} -lt 30 ]; do
        if ! kill -0 ${pid} 2>/dev/null; then
            echo "Service stopped successfully"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    # 如果服务没有停止，强制终止
    echo "Service did not stop gracefully, forcing termination"
    kill -9 ${pid}
    sleep 1
    
    if kill -0 ${pid} 2>/dev/null; then
        echo "Failed to stop service"
        return 1
    fi
    
    echo "Service terminated successfully"
    return 0
}

# 执行命令
case "${COMMAND}" in
    "start")
        start_service "${APP_NAME}" "${ENVIRONMENT}"
        exit $?
        ;;
    "stop")
        stop_service "${APP_NAME}" "${ENVIRONMENT}"
        exit $?
        ;;
    *)
        echo "Invalid command: ${COMMAND}. Use 'start' or 'stop'"
        exit 1
        ;;
esac