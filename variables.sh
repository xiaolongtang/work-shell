#!/bin/bash

# 基础路径配置
DMR_BASE_PATH="/apps/workspace/DMR"

# 环境列表
ENVIRONMENTS=("prod1" "prod2" "uat1" "uat2" "uat3" "sit" "dev")

# 服务列表（用于restart_all.sh）
SERVICES=(
    "eureka-server"
    "config-server"
    "gateway-service"
    "a-service"
    "b-service"
    "c-service"
    "d-service"
    "e-service"
    "f-service"
    "g-service"
    "h-service"
)

# 基础服务端口配置（从yaml中读取的服务端口在config-server中配置）
EUREKA_PORT_UAT1=8761
EUREKA_PORT_UAT3=8861
CONFIG_PORT_UAT1=8888
CONFIG_PORT_UAT3=8988
GATEWAY_PORT_UAT1=8080
GATEWAY_PORT_UAT3=8180

# 配置中心地址配置
CONFIG_SERVER_URL_UAT1="http://localhost:8888"
CONFIG_SERVER_URL_UAT3="http://localhost:18888"

# 获取环境对应的部署路径
get_deploy_path() {
    local env=$1
    echo "${DMR_BASE_PATH}/${env}"
}

# 获取环境对应的日志路径
get_log_path() {
    local env=$1
    echo "${DMR_BASE_PATH}/logs"
}

# 获取服务部署路径
get_service_deploy_path() {
    local env=$1
    local service=$2
    echo "$(get_deploy_path ${env})/deployment/${service}/package"
}

# 获取服务发布路径
get_service_release_path() {
    local env=$1
    local service=$2
    local version=$3
    echo "$(get_deploy_path ${env})/release/${service}/${version}"
}

# 获取服务日志路径
get_service_log_path() {
    local env=$1
    local service=$2
    echo "$(get_log_path ${env})/${service}"
}

# 获取服务OOM和GC日志路径
get_service_oom_gc_log_path() {
    local env=$1
    local service=$2
    echo "$(get_service_log_path ${env} ${service})/oom_gc_log"
}

# JAR包下载URL前缀
JAR_DOWNLOAD_URL_PREFIX="http://artifact-repository.example.com/repository"

# 获取服务对应的端口号
get_service_port() {
    local env=$1
    local service=$2
    
    case "${service}" in
        "eureka-server")
            if [ "${env}" == "uat1" ]; then
                echo ${EUREKA_PORT_UAT1}
            elif [ "${env}" == "uat3" ]; then
                echo ${EUREKA_PORT_UAT3}
            fi
            ;;
        "config-server")
            if [ "${env}" == "uat1" ]; then
                echo ${CONFIG_PORT_UAT1}
            elif [ "${env}" == "uat3" ]; then
                echo ${CONFIG_PORT_UAT3}
            fi
            ;;
        "gateway-service")
            if [ "${env}" == "uat1" ]; then
                echo ${GATEWAY_PORT_UAT1}
            elif [ "${env}" == "uat3" ]; then
                echo ${GATEWAY_PORT_UAT3}
            fi
            ;;
    esac
}

# 获取Java启动参数
get_java_opts() {
    local env=$1
    local service=$2
    
    # 基础JVM参数
    local JAVA_OPTS="-Xms512m -Xmx1024m"
    
    # GC日志配置
    local GC_LOG_PATH=$(get_service_oom_gc_log_path ${env} ${service})
    JAVA_OPTS="${JAVA_OPTS} -XX:+HeapDumpOnOutOfMemoryError"
    JAVA_OPTS="${JAVA_OPTS} -XX:HeapDumpPath=${GC_LOG_PATH}"
    JAVA_OPTS="${JAVA_OPTS} -Xloggc:${GC_LOG_PATH}/gc.log"
    
    # 环境配置
    JAVA_OPTS="${JAVA_OPTS} -Dspring.profiles.active=${env}"
    
    # 服务端口配置（仅针对基础服务）
    local port=$(get_service_port ${env} ${service})
    if [ ! -z "${port}" ]; then
        JAVA_OPTS="${JAVA_OPTS} -Dserver.port=${port}"
    fi
    
    # 配置中心地址配置（除了eureka-server和config-server外的服务）
    if [ "${service}" != "eureka-server" ] && [ "${service}" != "config-server" ]; then
        if [ "${env}" == "uat1" ]; then
            JAVA_OPTS="${JAVA_OPTS} -Dspring.cloud.config.uri=${CONFIG_SERVER_URL_UAT1}"
        elif [ "${env}" == "uat3" ]; then
            JAVA_OPTS="${JAVA_OPTS} -Dspring.cloud.config.uri=${CONFIG_SERVER_URL_UAT3}"
        fi
    fi

    # Eureka服务器地址配置（除了eureka-server外的所有服务）
    if [ "${service}" != "eureka-server" ]; then
        if [ "${env}" == "uat1" ]; then
            JAVA_OPTS="${JAVA_OPTS} -Deureka.client.serviceUrl.defaultZone=http://localhost:${EUREKA_PORT_UAT1}/eureka/"
        elif [ "${env}" == "uat3" ]; then
            JAVA_OPTS="${JAVA_OPTS} -Deureka.client.serviceUrl.defaultZone=http://localhost:18761/eureka/"
        fi
    fi
    
    echo ${JAVA_OPTS}
}