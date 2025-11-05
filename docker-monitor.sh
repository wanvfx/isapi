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
        load_avg=$(cat /proc/loadavg | awk '{print $1","$2","$3}' | tr -d '\r\n')
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
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}' | tr -d '\r\n')
    mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}' | tr -d '\r\n')
    mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}' | tr -d '\r\n')
    mem_buffers=$(grep Buffers /proc/meminfo | awk '{print $2}' | tr -d '\r\n')
    mem_cached=$(grep Cached /proc/meminfo | awk '{print $2}' | grep -v SwapCached | head -1 | awk '{print $2}' | tr -d '\r\n')

    # 如果任何字段为空，则设置为0
    [ -z "$mem_total" ] && mem_total=0
    [ -z "$mem_free" ] && mem_free=0
    [ -z "$mem_available" ] && mem_available=0
    [ -z "$mem_buffers" ] && mem_buffers=0
    [ -z "$mem_cached" ] && mem_cached=0

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
    # 尝试从不同的温度传感器文件读取数据
    local temp_files=(
        "/sys/class/thermal/thermal_zone*/temp"
        "/sys/devices/virtual/thermal/thermal_zone*/temp"
        "/sys/class/hwmon/hwmon*/temp1_input"
    )
    
    for file in "${temp_files[@]}"; do
        if [ -f "$file" ]; then
            # 读取温度值（单位为毫摄氏度）
            temp=$(cat "$file" 2>/dev/null)
            if [ -n "$temp" ]; then
                # 转换为摄氏度并返回JSON
                celsius=$(echo "$temp" | awk '{print $1/1000}')
                jq -n --argjson celsius "$celsius" '{celsius: $celsius}'
                return 0
            fi
        fi
    done
    
    # 如果没有找到温度传感器，返回null
    jq -n 'null'
}

# 获取网络接口信息
get_network_info() {
    # 使用ip命令获取网络接口信息
    if command -v ip >/dev/null 2>&1; then
        # 获取所有活动的网络接口
        interfaces=$(ip link show up | grep -o '^[0-9]*:' | cut -d':' -f1)
        
        # 初始化JSON数组
        network_array="[]"
        
        # 遍历每个接口
        for interface in $interfaces; do
            # 获取接口名称
            name=$(ip link show "$interface" | grep -o '^[^:]*:' | cut -d':' -f1)
            
            # 获取IP地址
            ip_addr=$(ip addr show "$interface" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
            
            # 获取流量统计
            rx_bytes=$(cat /sys/class/net/$name/statistics/rx_bytes 2>/dev/null || echo "0")
            tx_bytes=$(cat /sys/class/net/$name/statistics/tx_bytes 2>/dev/null || echo "0")
            
            # 构建接口信息
            interface_json=$(jq -n \
                --arg name "$name" \
                --arg ip_addr "$ip_addr" \
                --argjson rx_bytes "$rx_bytes" \
                --argjson tx_bytes "$tx_bytes" \
                '{
                    name: $name,
                    ip_address: $ip_addr,
                    rx_bytes: $rx_bytes,
                    tx_bytes: $tx_bytes
                }')
            
            # 添加到数组
            network_array=$(echo "$network_array" | jq --argjson interface "$interface_json" '. + [$interface]')
        done
        
        echo "$network_array"
    else
        # 如果ip命令不可用，尝试使用ifconfig
        if command -v ifconfig >/dev/null 2>&1; then
            # 使用ifconfig获取网络接口信息
            ifconfig | grep -A 5 "^[a-zA-Z]" | grep -E "(inet|RX packets|TX packets)" | awk '
            /inet/ && !/127.0.0.1/ {ip = $2}
            /RX packets/ {rx_packets = $2}
            /TX packets/ {tx_packets = $2}
            END {print "{\"name\": \""$1"\", \"ip_address\": \""ip"\", \"rx_packets\": "rx_packets", \"tx_packets\": "tx_packets"}"}
            '
        else
            # 如果都没有可用，返回空数组
            jq -n '[]'
        fi
    fi
}

# 获取磁盘信息
get_disk_info() {
    # 获取根文件系统使用情况
    disk_usage_raw=$(df / 2>/dev/null | tail -1 | awk '{print "{\"total\": "$2", \"used\": "$3", \"available\": "$4", \"usage\": \""$5"\"}"}')

    if [ -n "$disk_usage_raw" ]; then
        # 移除可能的\r字符
        disk_usage_raw=$(echo "$disk_usage_raw" | tr -d '\r\n')
        echo "$disk_usage_raw" | jq .
    else
        # 如果df命令失败，返回默认值
        echo '{"total": 0, "used": 0, "available": 0, "usage": "0%"}'
    fi
}

# 启动HTTP服务器
start_http_server() {
    # 使用ncat或简单的bash TCP服务器
    {
        while true; do
            read -r request_line
            # 读取请求头，直到遇到空行
            # 处理Windows可能发送的CRLF换行符
            while read -r header_line; do
                # 移除可能的\r字符
                header_line=$(echo "$header_line" | tr -d '\r')
                # 检查是否为空行
                if [ -z "$header_line" ]; then
                    break
                fi
            done
            
            # 解析请求路径和方法
            request_method=$(echo "$request_line" | awk '{print $1}')
            request_path=$(echo "$request_line" | awk '{print $2}')

            if [ "$request_path" = "/" ]; then
                # 检查index.html是否存在，否则返回404
                if [ -f "/index.html" ]; then
                    content_length=$(stat -c %s /index.html)
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: text/html; charset=utf-8\r"
                    echo -e "Content-Length: $content_length\r"
                    echo -e "\r"
                    cat /index.html
                else
                    echo -e "HTTP/1.1 404 Not Found\r"
                    echo -e "Content-Type: text/plain; charset=utf-8\r"
                    echo -e "\r"
                    echo "Web界面文件未找到"
                fi
            elif [ "$request_path" = "/api/status" ]; then
                # 返回JSON数据
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: application/json; charset=utf-8\r"
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
                echo -e "Content-Type: text/plain; charset=utf-8\r"
                echo -e "\r"
                if [ -f "$LOG_FILE" ]; then
                    tail -n 50 "$LOG_FILE"
                else
                    echo "暂无日志"
                fi
            elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "GET" ]; then
                # 返回当前配置
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: application/json; charset=utf-8\r"
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
                echo -e "Content-Type: application/json; charset=utf-8\r"
                echo -e "\r"
                echo '{"status": "success", "message": "配置更新成功，将在下次数据收集时生效"}'
            else
                # 其他路径返回404
                echo -e "HTTP/1.1 404 Not Found\r"
                echo -e "Content-Type: text/plain; charset=utf-8\r"
                echo -e "\r"
                echo "页面未找到"
            fi
        done
    } | nc -l -p $PORT 2>/dev/null || {
        # 如果nc不可用，使用bash实现简单的HTTP服务器
        while true; do
            {
                read -r request_line
                # 读取请求头，直到遇到空行
                # 处理Windows可能发送的CRLF换行符
                while read -r header_line; do
                    # 移除可能的\r字符
                    header_line=$(echo "$header_line" | tr -d '\r')
                    # 检查是否为空行
                    if [ -z "$header_line" ]; then
                        break
                    fi
                done
                
                # 解析请求路径和方法
                request_method=$(echo "$request_line" | awk '{print $1}')
                request_path=$(echo "$request_line" | awk '{print $2}')

                if [ "$request_path" = "/" ]; then
                    # 检查index.html是否存在，否则返回404
                    if [ -f "/index.html" ]; then
                        content_length=$(stat -c %s /index.html)
                        echo -e "HTTP/1.1 200 OK\r"
                        echo -e "Content-Type: text/html; charset=utf-8\r"
                        echo -e "Content-Length: $content_length\r"
                        echo -e "\r"
                        cat /index.html
                    else
                        echo -e "HTTP/1.1 404 Not Found\r"
                        echo -e "Content-Type: text/plain; charset=utf-8\r"
                        echo -e "\r"
                        echo "Web界面文件未找到"
                    fi
                elif [ "$request_path" = "/api/status" ]; then
                    # 返回JSON数据
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: application/json; charset=utf-8\r"
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
                    echo -e "Content-Type: text/plain; charset=utf-8\r"
                    echo -e "\r"
                    if [ -f "$LOG_FILE" ]; then
                        tail -n 50 "$LOG_FILE"
                    else
                        echo "暂无日志"
                    fi
                elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "GET" ]; then
                    # 返回当前配置
                    echo -e "HTTP/1.1 200 OK\r"
                    echo -e "Content-Type: application/json; charset=utf-8\r"
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
                    echo -e "Content-Type: application/json; charset=utf-8\r"
                    echo -e "\r"
                    echo '{"status": "success", "message": "配置更新成功，将在下次数据收集时生效"}'
                else
                    # 其他路径返回404
                    echo -e "HTTP/1.1 404 Not Found\r"
                    echo -e "Content-Type: text/plain; charset=utf-8\r"
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