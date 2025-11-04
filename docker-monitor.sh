#!/bin/bash

# ISAPI监控脚本，收集软路由系统信息并通过HTTP API提供

# 设置端口
PORT=${PORT:-15130}

# API路由
API_ROUTE=${API_ROUTE:-/api/status}

# 数据刷新间隔（秒）
REFRESH_INTERVAL=${REFRESH_INTERVAL:-5}

# 各项监控功能开关（默认都启用）
ENABLE_TIMESTAMP=${ENABLE_TIMESTAMP:-true}
ENABLE_LOAD_AVG=${ENABLE_LOAD_AVG:-true}
ENABLE_CPU_USAGE=${ENABLE_CPU_USAGE:-true}
ENABLE_MEMORY_INFO=${ENABLE_MEMORY_INFO:-true}
ENABLE_TEMPERATURE=${ENABLE_TEMPERATURE:-true}
ENABLE_NETWORK_INFO=${ENABLE_NETWORK_INFO:-true}
ENABLE_DISK_INFO=${ENABLE_DISK_INFO:-true}

# 存储最新系统状态的文件
STATUS_FILE="/tmp/wechatpush/status.json"
LOG_FILE="/tmp/wechatpush/app.log"
CONFIG_FILE="/tmp/wechatpush/config.json"

# 初始化
mkdir -p /tmp/wechatpush

# 创建默认配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    jq -n \
        --arg enable_timestamp "$ENABLE_TIMESTAMP" \
        --arg enable_load_avg "$ENABLE_LOAD_AVG" \
        --arg enable_cpu_usage "$ENABLE_CPU_USAGE" \
        --arg enable_memory_info "$ENABLE_MEMORY_INFO" \
        --arg enable_temperature "$ENABLE_TEMPERATURE" \
        --arg enable_network_info "$ENABLE_NETWORK_INFO" \
        --arg enable_disk_info "$ENABLE_DISK_INFO" \
        '{
            enable_timestamp: $enable_timestamp,
            enable_load_avg: $enable_load_avg,
            enable_cpu_usage: $enable_cpu_usage,
            enable_memory_info: $enable_memory_info,
            enable_temperature: $enable_temperature,
            enable_network_info: $enable_network_info,
            enable_disk_info: $enable_disk_info
        }' > "$CONFIG_FILE"
fi

# 读取配置文件
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        ENABLE_TIMESTAMP=$(jq -r '.enable_timestamp' "$CONFIG_FILE")
        ENABLE_LOAD_AVG=$(jq -r '.enable_load_avg' "$CONFIG_FILE")
        ENABLE_CPU_USAGE=$(jq -r '.enable_cpu_usage' "$CONFIG_FILE")
        ENABLE_MEMORY_INFO=$(jq -r '.enable_memory_info' "$CONFIG_FILE")
        ENABLE_TEMPERATURE=$(jq -r '.enable_temperature' "$CONFIG_FILE")
        ENABLE_NETWORK_INFO=$(jq -r '.enable_network_info' "$CONFIG_FILE")
        ENABLE_DISK_INFO=$(jq -r '.enable_disk_info' "$CONFIG_FILE")
    fi
}

# 日志记录函数
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    echo "[$timestamp] $message"
}

# 收集系统信息的函数
collect_system_info() {
    # 读取最新配置
    read_config
    
    # 初始化JSON对象
    json_builder="{}"
    
    # 获取时间戳
    if [ "$ENABLE_TIMESTAMP" = "true" ]; then
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        json_builder=$(echo "$json_builder" | jq --arg timestamp "$timestamp" '. + {timestamp: $timestamp}')
    fi
    
    # 初始化system对象
    system_builder="{}"
    
    # 获取系统负载
    if [ "$ENABLE_LOAD_AVG" = "true" ]; then
        load_avg=$(cat /proc/loadavg | awk '{print $1","$2","$3}')
        system_builder=$(echo "$system_builder" | jq --arg load_avg "$load_avg" '. + {load_avg: $load_avg}')
    fi
    
    # 获取CPU使用率
    if [ "$ENABLE_CPU_USAGE" = "true" ]; then
        cpu_usage=$(get_cpu_usage)
        system_builder=$(echo "$system_builder" | jq --argjson cpu_usage "$cpu_usage" '. + {cpu_usage: $cpu_usage}')
    fi
    
    # 获取内存信息
    if [ "$ENABLE_MEMORY_INFO" = "true" ]; then
        mem_info=$(get_memory_info)
        system_builder=$(echo "$system_builder" | jq --argjson mem_info "$mem_info" '. + {memory: $mem_info}')
    fi
    
    # 获取温度信息
    if [ "$ENABLE_TEMPERATURE" = "true" ]; then
        temperature=$(get_temperature)
        system_builder=$(echo "$system_builder" | jq --argjson temperature "$temperature" '. + {temperature: $temperature}')
    fi
    
    # 获取网络接口信息
    if [ "$ENABLE_NETWORK_INFO" = "true" ]; then
        network_info=$(get_network_info)
        system_builder=$(echo "$system_builder" | jq --argjson network_info "$network_info" '. + {network: $network_info}')
    fi
    
    # 获取磁盘使用情况
    if [ "$ENABLE_DISK_INFO" = "true" ]; then
        disk_info=$(get_disk_info)
        system_builder=$(echo "$system_builder" | jq --argjson disk_info "$disk_info" '. + {disk: $disk_info}')
    fi
    
    # 将system对象添加到主JSON对象
    json_builder=$(echo "$json_builder" | jq --argjson system "$system_builder" '. + {system: $system}')
    
    # 写入状态文件
    echo "$json_builder" > "$STATUS_FILE"
}

# 获取CPU使用率
get_cpu_usage() {
    # 读取第一次CPU状态
    cpu_line=$(head -n1 /proc/stat)
    cpu_now=($(echo $cpu_line | awk '{print $2,$3,$4,$5,$6,$7,$8}'))
    
    # 计算总时间和空闲时间
    idle_now=${cpu_now[3]}
    total_now=$((${cpu_now[0]} + ${cpu_now[1]} + ${cpu_now[2]} + ${cpu_now[3]} + ${cpu_now[4]} + ${cpu_now[5]} + ${cpu_now[6]}))
    
    # 等待一段时间
    sleep 0.5
    
    # 读取第二次CPU状态
    cpu_line=$(head -n1 /proc/stat)
    cpu_next=($(echo $cpu_line | awk '{print $2,$3,$4,$5,$6,$7,$8}'))
    
    # 计算总时间和空闲时间
    idle_next=${cpu_next[3]}
    total_next=$((${cpu_next[0]} + ${cpu_next[1]} + ${cpu_next[2]} + ${cpu_next[3]} + ${cpu_next[4]} + ${cpu_next[5]} + ${cpu_next[6]}))
    
    # 计算使用率
    idle_diff=$((idle_next - idle_now))
    total_diff=$((total_next - total_now))
    cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
    
    # 返回JSON
    jq -n --arg usage "$cpu_usage" '{usage: $usage}'
}

# 获取内存信息
get_memory_info() {
    # 从/proc/meminfo获取内存信息
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
    mem_cached=$(grep Cached /proc/meminfo | awk '{print $2}')
    
    # 计算使用率
    mem_used=$((mem_total - mem_free))
    mem_usage=$((100 * mem_used / mem_total))
    
    # 返回JSON
    jq -n \
        --arg total "$mem_total" \
        --arg free "$mem_free" \
        --arg available "$mem_available" \
        --arg buffers "$mem_buffers" \
        --arg cached "$mem_cached" \
        --arg used "$mem_used" \
        --arg usage "$mem_usage" \
        '{
            total: ($total | tonumber),
            free: ($free | tonumber),
            available: ($available | tonumber),
            buffers: ($buffers | tonumber),
            cached: ($cached | tonumber),
            used: ($used | tonumber),
            usage: ($usage | tonumber)
        }'
}

# 获取温度信息
get_temperature() {
    # 尝试多种方式获取温度
    temp=""
    
    # 方法1: 从thermal_zone获取
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp | awk '{printf "%.1f", $1/1000}')
    fi
    
    # 方法2: 使用sensors命令
    if command -v sensors >/dev/null 2>&1 && [ -z "$temp" ]; then
        temp=$(sensors 2>/dev/null | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | awk '{print $1}' | sed 's/°C//')
    fi
    
    # 如果获取不到温度，设为null
    if [ -z "$temp" ]; then
        temp="null"
    fi
    
    # 返回JSON
    if [ "$temp" = "null" ]; then
        echo '{"celsius": null}'
    else
        jq -n --arg temp "$temp" '{celsius: ($temp | tonumber)}'
    fi
}

# 获取网络接口信息
get_network_info() {
    # 获取默认网络接口
    interfaces=$(ls /sys/class/net/ | grep -E 'eth|wlan|enp|wlp' | head -3)
    
    # 构建接口信息数组
    interface_array="[]"
    for interface in $interfaces; do
        if [ -f "/sys/class/net/$interface/statistics/rx_bytes" ] && [ -f "/sys/class/net/$interface/statistics/tx_bytes" ]; then
            rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
            tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)
            
            interface_info=$(jq -n \
                --arg name "$interface" \
                --arg rx_bytes "$rx_bytes" \
                --arg tx_bytes "$tx_bytes" \
                '{name: $name, rx_bytes: ($rx_bytes | tonumber), tx_bytes: ($tx_bytes | tonumber)}')
            
            interface_array=$(echo "$interface_array" | jq --argjson info "$interface_info" '. + [$info]')
        fi
    done
    
    echo "$interface_array"
}

# 获取磁盘信息
get_disk_info() {
    # 获取根文件系统使用情况
    disk_usage=$(df / 2>/dev/null | tail -1 | awk '{print "{\"total\": "$2", \"used\": "$3", \"available\": "$4", \"usage\": "$5"}"}')
    
    if [ -n "$disk_usage" ]; then
        echo "$disk_usage" | jq .
    else
        echo '{"total": 0, "used": 0, "available": 0, "usage": "0%"}'
    fi
}

# 启动HTTP服务器
start_http_server() {
    # 使用ncat或简单的bash TCP服务器
    {
        while true; do
            # 读取请求行
            read -r request_line
            # 读取请求头，直到遇到空行
            while read -r header_line && [ -n "$header_line" ]; do
                # 忽略请求头
                :
            done
            
            # 解析请求路径和方法
            request_method=$(echo "$request_line" | awk '{print $1}')
            request_path=$(echo "$request_line" | awk '{print $2}')
            
            # 根据路径返回不同内容
            if [ "$request_path" = "/" ]; then
                # 返回Web界面
                if [ -f "/app/index.html" ]; then
                    content_length=$(stat -c %s /app/index.html)
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: text/html\r"
                    echo -e "Content-Length: $content_length\r"
                    echo -e "\r"
                    cat /app/index.html
                else
                    echo -e "HTTP/1.1 404 Not Found\r"
                    echo -e "Content-Type: text/plain\r"
                    echo -e "\r"
                    echo "Web界面文件未找到"
                fi
            elif [ "$request_path" = "/api/status" ]; then
                # 返回JSON数据
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: application/json\r"
                echo -e "Access-Control-Allow-Origin: *\r"
                echo -e "\r"
                if [ -f "$STATUS_FILE" ]; then
                    cat "$STATUS_FILE"
                else
                    echo '{"error": "No data available"}'
                fi
            elif [ "$request_path" = "/api/log" ]; then
                # 返回日志内容
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: text/plain\r"
                echo -e "\r"
                if [ -f "$LOG_FILE" ]; then
                    tail -n 50 "$LOG_FILE"
                else
                    echo "暂无日志"
                fi
            elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "GET" ]; then
                # 返回当前配置
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: application/json\r"
                echo -e "\r"
                if [ -f "$CONFIG_FILE" ]; then
                    cat "$CONFIG_FILE"
                else
                    echo '{"error": "Config file not found"}'
                fi
            elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "POST" ]; then
                # 处理配置更新请求
                # 读取POST数据
                content_length=$(echo "$header_line" | grep -i "content-length" | awk '{print $2}')
                if [ -n "$content_length" ]; then
                    read -n "$content_length" post_data
                    echo "$post_data" > "$CONFIG_FILE"
                fi
                
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: application/json\r"
                echo -e "\r"
                echo '{"status": "success", "message": "配置更新成功，将在下次数据收集时生效"}'
            else
                # 其他路径返回404
                echo -e "HTTP/1.1 404 Not Found\r"
                echo -e "Content-Type: text/plain\r"
                echo -e "\r"
                echo "页面未找到"
            fi
        done
    } | nc -l -p $PORT 2>/dev/null || {
        # 如果nc不可用，使用bash实现简单的HTTP服务器
        while true; do
            {
                # 读取请求行
                read -r request_line
                # 读取请求头，直到遇到空行
                while read -r header_line && [ -n "$header_line" ]; do
                    # 忽略请求头
                    :
                done
                
                # 解析请求路径和方法
                request_method=$(echo "$request_line" | awk '{print $1}')
                request_path=$(echo "$request_line" | awk '{print $2}')
                
                # 根据路径返回不同内容
                if [ "$request_path" = "/" ]; then
                    # 返回Web界面
                    if [ -f "/app/index.html" ]; then
                        content_length=$(stat -c %s /app/index.html)
                        echo -e "HTTP/1.1 200 OK\r"
                        echo -e "Content-Type: text/html\r"
                        echo -e "Content-Length: $content_length\r"
                        echo -e "\r"
                        cat /app/index.html
                    else
                        echo -e "HTTP/1.1 404 Not Found\r"
                        echo -e "Content-Type: text/plain\r"
                        echo -e "\r"
                        echo "Web界面文件未找到"
                    fi
                elif [ "$request_path" = "/api/status" ]; then
                    # 返回JSON数据
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: application/json\r"
                    echo -e "Access-Control-Allow-Origin: *\r"
                    echo -e "\r"
                    if [ -f "$STATUS_FILE" ]; then
                        cat "$STATUS_FILE"
                    else
                        echo '{"error": "No data available"}'
                    fi
                elif [ "$request_path" = "/api/log" ]; then
                    # 返回日志内容
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: text/plain\r"
                    echo -e "\r"
                    if [ -f "$LOG_FILE" ]; then
                        tail -n 50 "$LOG_FILE"
                    else
                        echo "暂无日志"
                    fi
                elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "GET" ]; then
                    # 返回当前配置
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: application/json\r"
                    echo -e "\r"
                    if [ -f "$CONFIG_FILE" ]; then
                        cat "$CONFIG_FILE"
                    else
                        echo '{"error": "Config file not found"}'
                    fi
                elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "POST" ]; then
                    # 处理配置更新请求
                    # 读取POST数据
                    content_length=$(echo "$header_line" | grep -i "content-length" | awk '{print $2}')
                    if [ -n "$content_length" ]; then
                        read -n "$content_length" post_data
                        echo "$post_data" > "$CONFIG_FILE"
                    fi
                    
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: application/json\r"
                    echo -e "\r"
                    echo '{"status": "success", "message": "配置更新成功，将在下次数据收集时生效"}'
                else
                    # 其他路径返回404
                    echo -e "HTTP/1.1 404 Not Found\r"
                    echo -e "Content-Type: text/plain\r"
                    echo -e "\r"
                    echo "页面未找到"
                fi
            } | nc -l -p $PORT 2>/dev/null || sleep 1
        done
    }
}

# 后台定期更新数据
{
    log_message "开始数据收集任务，刷新间隔: ${REFRESH_INTERVAL}秒"
    while true; do
        collect_system_info
        log_message "系统信息已更新"
        sleep $REFRESH_INTERVAL
    done
} &

# 启动HTTP服务器
log_message "启动HTTP服务器，监听端口: ${PORT}"
start_http_server