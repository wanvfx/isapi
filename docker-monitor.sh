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
        ENABLE_TIMESTAMP=$(jq -r '.enable_timestamp // "true"' "$CONFIG_FILE")
        ENABLE_LOAD_AVG=$(jq -r '.enable_load_avg // "true"' "$CONFIG_FILE")
        ENABLE_CPU_USAGE=$(jq -r '.enable_cpu_usage // "true"' "$CONFIG_FILE")
        ENABLE_MEMORY_INFO=$(jq -r '.enable_memory_info // "true"' "$CONFIG_FILE")
        ENABLE_TEMPERATURE=$(jq -r '.enable_temperature // "true"' "$CONFIG_FILE")
        ENABLE_NETWORK_INFO=$(jq -r '.enable_network_info // "true"' "$CONFIG_FILE")
        ENABLE_DISK_INFO=$(jq -r '.enable_disk_info // "true"' "$CONFIG_FILE")
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
        # 确保timestamp不为空
        if [ -n "$timestamp" ]; then
            json_builder=$(echo "$json_builder" | jq --arg timestamp "$timestamp" '. + {timestamp: $timestamp}')
        fi
    fi
    
    # 初始化system对象
    system_builder="{}"
    
    # 获取系统负载
    if [ "$ENABLE_LOAD_AVG" = "true" ]; then
        load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1","$2","$3}' | tr -d '\r\n')
        # 确保load_avg不为空
        if [ -n "$load_avg" ]; then
            system_builder=$(echo "$system_builder" | jq --arg load_avg "$load_avg" '. + {load_avg: $load_avg}')
        fi
    fi
    
    # 获取CPU使用率
    if [ "$ENABLE_CPU_USAGE" = "true" ]; then
        cpu_usage=$(get_cpu_usage 2>/dev/null)
        # 确保cpu_usage不为空且是有效的JSON
        if [ -n "$cpu_usage" ]; then
            if echo "$cpu_usage" | jq . >/dev/null 2>&1; then
                system_builder=$(echo "$system_builder" | jq --argjson cpu_usage "$cpu_usage" '. + {cpu_usage: $cpu_usage}')
            fi
        fi
    fi
    
    # 获取内存信息
    if [ "$ENABLE_MEMORY_INFO" = "true" ]; then
        mem_info=$(get_memory_info 2>/dev/null)
        # 确保mem_info不为空且是有效的JSON
        if [ -n "$mem_info" ]; then
            if echo "$mem_info" | jq . >/dev/null 2>&1; then
                system_builder=$(echo "$system_builder" | jq --argjson mem_info "$mem_info" '. + {memory: $mem_info}')
            fi
        fi
    fi
    
    # 获取温度信息
    if [ "$ENABLE_TEMPERATURE" = "true" ]; then
        temperature=$(get_temperature 2>/dev/null)
        # 确保temperature不为空且是有效的JSON
        if [ -n "$temperature" ]; then
            if echo "$temperature" | jq . >/dev/null 2>&1; then
                system_builder=$(echo "$system_builder" | jq --argjson temperature "$temperature" '. + {temperature: $temperature}')
            fi
        fi
    fi
    
    # 获取网络接口信息
    if [ "$ENABLE_NETWORK_INFO" = "true" ]; then
        network_info=$(get_network_info 2>/dev/null)
        # 确保network_info不为空且是有效的JSON数组
        if [ -n "$network_info" ]; then
            if echo "$network_info" | jq . >/dev/null 2>&1; then
                system_builder=$(echo "$system_builder" | jq --argjson network_info "$network_info" '. + {network: $network_info}')
            fi
        fi
    fi
    
    # 获取磁盘使用情况
    if [ "$ENABLE_DISK_INFO" = "true" ]; then
        disk_info=$(get_disk_info 2>/dev/null)
        # 确保disk_info不为空且是有效的JSON
        if [ -n "$disk_info" ]; then
            if echo "$disk_info" | jq . >/dev/null 2>&1; then
                system_builder=$(echo "$system_builder" | jq --argjson disk_info "$disk_info" '. + {disk: $disk_info}')
            fi
        fi
    fi
    
    # 将system对象添加到主JSON对象
    if [ "$system_builder" != "{}" ]; then
        json_builder=$(echo "$json_builder" | jq --argjson system "$system_builder" '. + {system: $system}')
    fi
    
    # 写入状态文件
    echo "$json_builder" > "$STATUS_FILE"
}

# 获取CPU使用率
get_cpu_usage() {
    # 读取第一次CPU状态
    cpu_line=$(head -n1 /proc/stat 2>/dev/null)
    if [ -z "$cpu_line" ]; then
        # 返回默认值
        jq -n '{usage: 0}'
        return
    fi
    
    cpu_now=($(echo $cpu_line | awk '{print $2,$3,$4,$5,$6,$7,$8}'))
    
    # 计算总时间和空闲时间
    idle_now=${cpu_now[3]:-0}
    total_now=$((${cpu_now[0]:-0} + ${cpu_now[1]:-0} + ${cpu_now[2]:-0} + ${cpu_now[3]:-0} + ${cpu_now[4]:-0} + ${cpu_now[5]:-0} + ${cpu_now[6]:-0}))
    
    # 等待一段时间
    sleep 0.5
    
    # 读取第二次CPU状态
    cpu_line=$(head -n1 /proc/stat 2>/dev/null)
    if [ -z "$cpu_line" ]; then
        # 返回默认值
        jq -n '{usage: 0}'
        return
    fi
    
    cpu_next=($(echo $cpu_line | awk '{print $2,$3,$4,$5,$6,$7,$8}'))
    
    # 计算总时间和空闲时间
    idle_next=${cpu_next[3]:-0}
    total_next=$((${cpu_next[0]:-0} + ${cpu_next[1]:-0} + ${cpu_next[2]:-0} + ${cpu_next[3]:-0} + ${cpu_next[4]:-0} + ${cpu_next[5]:-0} + ${cpu_next[6]:-0}))
    
    # 计算使用率
    idle_diff=$((idle_next - idle_now))
    total_diff=$((total_next - total_now))
    
    if [ $total_diff -gt 0 ]; then
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
    else
        cpu_usage=0
    fi
    
    # 确保cpu_usage在合理范围内
    if [ $cpu_usage -lt 0 ] || [ $cpu_usage -gt 100 ]; then
        cpu_usage=0
    fi
    
    # 返回JSON
    jq -n --arg usage "$cpu_usage" '{usage: ($usage | tonumber)}'
}

# 获取内存信息
get_memory_info() {
    # 从/proc/meminfo获取内存信息
    mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
    mem_free=$(grep MemFree /proc/meminfo 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
    mem_available=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
    mem_buffers=$(grep Buffers /proc/meminfo 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
    mem_cached=$(grep Cached /proc/meminfo 2>/dev/null | awk '{print $2}' | grep -v SwapCached | head -1 | awk '{print $2}' | tr -d '\r\n')

    # 如果任何字段为空，则设置为0
    [ -z "$mem_total" ] && mem_total=0
    [ -z "$mem_free" ] && mem_free=0
    [ -z "$mem_available" ] && mem_available=0
    [ -z "$mem_buffers" ] && mem_buffers=0
    [ -z "$mem_cached" ] && mem_cached=0

    # 计算使用率，避免除以零
    if [ "$mem_total" -gt 0 ]; then
        mem_used=$((mem_total - mem_free))
        mem_usage=$((100 * mem_used / mem_total))
    else
        mem_used=0
        mem_usage=0
    fi

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
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | tr -d '\r\n')
        if [ -n "$temp_raw" ]; then
            # 确保temp_raw是数字
            if echo "$temp_raw" | grep -qE '^-?[0-9]+$'; then
                temp=$(echo "$temp_raw" | awk '{printf "%.1f", $1/1000}')
            fi
        fi
    fi
    
    # 方法2: 使用sensors命令
    if command -v sensors >/dev/null 2>&1 && [ -z "$temp" ]; then
        temp_raw=$(sensors 2>/dev/null | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | awk '{print $1}' | sed 's/°C//' | tr -d '\r\n')
        if [ -n "$temp_raw" ]; then
            temp="$temp_raw"
        fi
    fi
    
    # 如果获取不到温度，设为null
    if [ -z "$temp" ]; then
        echo '{"celsius": null}'
    else
        # 确保temp是有效数字
        if echo "$temp" | grep -qE '^-?[0-9]+\.?[0-9]*$'; then
            jq -n --arg temp "$temp" '{celsius: ($temp | tonumber)}'
        else
            echo '{"celsius": null}'
        fi
    fi
}

# 获取网络接口信息
get_network_info() {
    # 获取网络接口
    interfaces=$(ls /sys/class/net/ 2>/dev/null | grep -E 'eth|wlan|enp|wlp|br|docker' | head -5)
    
    # 如果没有找到接口，尝试使用ip命令
    if [ -z "$interfaces" ]; then
        interfaces=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | head -5 | tr -d '\r\n')
    fi
    
    # 构建接口信息数组
    interface_array="[]"
    for interface in $interfaces; do
        # 跳过lo接口
        if [ "$interface" = "lo" ]; then
            continue
        fi
        
        rx_bytes=0
        tx_bytes=0
        
        # 尝试从sysfs获取流量统计
        if [ -f "/sys/class/net/$interface/statistics/rx_bytes" ] && [ -f "/sys/class/net/$interface/statistics/tx_bytes" ]; then
            rx_bytes_raw=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null | tr -d '\r\n')
            tx_bytes_raw=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null | tr -d '\r\n')
            
            # 清理数据，确保是数字
            if echo "$rx_bytes_raw" | grep -qE '^[0-9]+$'; then
                rx_bytes="$rx_bytes_raw"
            fi
            
            if echo "$tx_bytes_raw" | grep -qE '^[0-9]+$'; then
                tx_bytes="$tx_bytes_raw"
            fi
        fi
        
        # 确保数值有效
        [ -z "$rx_bytes" ] && rx_bytes=0
        [ -z "$tx_bytes" ] && tx_bytes=0
        
        interface_info=$(jq -n \
            --arg name "$interface" \
            --arg rx_bytes "$rx_bytes" \
            --arg tx_bytes "$tx_bytes" \
            '{name: $name, rx_bytes: ($rx_bytes | tonumber), tx_bytes: ($tx_bytes | tonumber)}')
        
        interface_array=$(echo "$interface_array" | jq --argjson info "$interface_info" '. + [$info]')
    done
    
    echo "$interface_array"
}

# 获取磁盘信息
get_disk_info() {
    # 获取根文件系统使用情况
    df_output=$(df / 2>/dev/null | tail -1 | tr -d '\r\n')
    
    if [ -n "$df_output" ]; then
        # 解析df输出
        total=$(echo "$df_output" | awk '{print $2}' | tr -d '\r\n')
        used=$(echo "$df_output" | awk '{print $3}' | tr -d '\r\n')
        available=$(echo "$df_output" | awk '{print $4}' | tr -d '\r\n')
        usage_percent=$(echo "$df_output" | awk '{print $5}' | tr -d '\r\n')
        
        # 确保数值有效
        [ -z "$total" ] && total=0
        [ -z "$used" ] && used=0
        [ -z "$available" ] && available=0
        [ -z "$usage_percent" ] && usage_percent="0%"
        
        # 返回JSON
        jq -n \
            --arg total "$total" \
            --arg used "$used" \
            --arg available "$available" \
            --arg usage "$usage_percent" \
            '{
                total: ($total | tonumber),
                used: ($used | tonumber),
                available: ($available | tonumber),
                usage: $usage
            }'
    else
        # 如果df命令失败，返回默认值
        echo '{"total": 0, "used": 0, "available": 0, "usage": "0%"}'
    fi
}

# 启动HTTP服务器
start_http_server() {
    log_message "HTTP服务器开始监听端口: ${PORT}"
    while true; do
        # 处理HTTP请求
        handle_http_request | nc -l -p $PORT -q 1 2>/dev/null || true
        # 短暂休眠以避免过于频繁的重启
        sleep 0.1
    done
}

# 处理HTTP请求
handle_http_request() {
    # 读取请求行
    if read -r request_line; then
        log_message "收到请求: $request_line"
    else
        # 如果无法读取请求行，返回空响应
        return
    fi
    
    # 读取请求头，直到遇到空行
    while read -r header_line; do
        # 移除可能的\r字符
        header_line=$(echo "$header_line" | tr -d '\r')
        # 检查是否为空行（表示请求头结束）
        if [ -z "$header_line" ]; then
            break
        fi
        # 记录请求头（可选）
        log_message "请求头: $header_line"
    done
    
    # 解析请求路径和方法
    request_method=$(echo "$request_line" | awk '{print $1}' | tr -d '\r\n')
    request_path=$(echo "$request_line" | awk '{print $2}' | tr -d '\r\n')
    
    # 确保请求路径存在，默认为根路径
    [ -z "$request_path" ] && request_path="/"
    
    log_message "处理请求: $request_method $request_path"
    
    # 处理不同的请求路径
    handle_request "$request_method" "$request_path"
}

# 处理HTTP请求
handle_request() {
    local request_method=$1
    local request_path=$2
    
    if [ "$request_path" = "/" ]; then
        # 返回API说明信息
        api_info=$(cat <<EOF
{
  "message": "ISAPI系统监控服务",
  "description": "提供系统监控数据的API接口",
  "api_endpoints": {
    "get_status": {
      "method": "GET",
      "path": "/api/status",
      "description": "获取系统状态信息"
    },
    "get_log": {
      "method": "GET",
      "path": "/api/log",
      "description": "获取运行日志"
    },
    "get_config": {
      "method": "GET",
      "path": "/api/config",
      "description": "获取当前配置"
    },
    "update_config": {
      "method": "POST",
      "path": "/api/config",
      "description": "更新配置信息"
    }
  },
  "usage": "请使用上述API端点获取系统监控数据"
}
EOF
)
        content_length=$(echo -n "$api_info" | wc -c)
        response="HTTP/1.1 200 OK\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Content-Length: $content_length\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+="$api_info"
        echo -e "$response"
    elif [ "$request_path" = "/api/status" ]; then
        # 返回JSON数据
        if [ -f "$STATUS_FILE" ]; then
            content_length=$(stat -c %s "$STATUS_FILE" 2>/dev/null || echo "0")
            response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Access-Control-Allow-Origin: *\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+=$(cat "$STATUS_FILE")
            echo -e "$response"
        else
            response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+='{"error": "No data available"}'
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/log" ]; then
        # 返回日志内容
        if [ -f "$LOG_FILE" ]; then
            content=$(tail -n 50 "$LOG_FILE")
            content_length=$(echo -n "$content" | wc -c)
            response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: text/plain; charset=utf-8\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="$content"
            echo -e "$response"
        else
            response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: text/plain; charset=utf-8\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="暂无日志"
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "GET" ]; then
        # 返回当前配置
        if [ -f "$CONFIG_FILE" ]; then
            content_length=$(stat -c %s "$CONFIG_FILE" 2>/dev/null || echo "0")
            response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+=$(cat "$CONFIG_FILE")
            echo -e "$response"
        else
            response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+='{"error": "Config file not found"}'
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "POST" ]; then
        # 处理配置更新请求
        # 读取POST数据
        content_length=$(echo "$header_line" | grep -i "content-length" | awk '{print $2}' | tr -d '\r\n')
        if [ -n "$content_length" ] && [ "$content_length" -gt 0 ]; then
            read -n "$content_length" post_data
            echo "$post_data" > "$CONFIG_FILE"
        fi
        
        response="HTTP/1.1 200 OK\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+='{"status": "success", "message": "配置更新成功，将在下次数据收集时生效"}'
        echo -e "$response"
    else
        # 其他路径返回404
        response="HTTP/1.1 404 Not Found\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+='{"error": "Endpoint not found"}'
        echo -e "$response"
    fi
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
log_message "可用API接口:"
log_message "  - 获取系统状态: http://localhost:${PORT}/api/status"
log_message "  - 获取运行日志: http://localhost:${PORT}/api/log"
log_message "  - 获取配置信息: http://localhost:${PORT}/api/config"
log_message "  - 更新配置信息: POST http://localhost:${PORT}/api/config"

# 使用while循环确保脚本持续运行
while true; do
    start_http_server
    # 如果HTTP服务器退出，等待一段时间后重新启动
    log_message "HTTP服务器退出，5秒后重新启动"
    sleep 5
done
