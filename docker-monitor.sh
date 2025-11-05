#!/bin/bash

# ISAPI - 系统监控工具
# 用于在软路由上监控系统状态并通过HTTP API提供数据

# 配置部分
PORT=${PORT:-15130}
REFRESH_INTERVAL=${REFRESH_INTERVAL:-5}
LOG_FILE="/app/isapi.log"
STATUS_FILE="/app/status.json"
CONFIG_FILE="/app/config.json"

DEFAULT_CONFIG='{
  "enable_timestamp": "true",
  "enable_load_avg": "true",
  "enable_cpu_usage": "true",
  "enable_memory_info": "true",
  "enable_temperature": "true",
  "enable_network_info": "true",
  "enable_disk_info": "true"
}'

# 初始化配置文件
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
        log_message "配置文件已初始化"
    fi
}

# 读取配置项
get_config_value() {
    local key=$1
    local default_value=$2
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$default_value"
        return
    fi
    local value=$(jq -r --arg key "$key" '.[$key] // $default_value' "$CONFIG_FILE" 2>/dev/null)
    if [ -z "$value" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# 记录日志
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="$timestamp | $message"
    
    # 确保日志文件可写
    if [ -w "$(dirname "$LOG_FILE")" ] || [ -w "$LOG_FILE" ]; then
        echo "$log_line" >> "$LOG_FILE"
    fi
    
    # 同时输出到标准错误，这样可以通过docker logs查看
    echo "$log_line" >&2
}

# 获取系统负载
get_load_average() {
    if [ -f "/proc/loadavg" ]; then
        local load_avg_raw=$(cat /proc/loadavg 2>/dev/null)
        if [ -n "$load_avg_raw" ]; then
            load_avg_raw=$(echo "$load_avg_raw" | tr -d '\r\n')
            local load1=$(echo "$load_avg_raw" | awk '{print $1}')
            local load5=$(echo "$load_avg_raw" | awk '{print $2}')
            local load15=$(echo "$load_avg_raw" | awk '{print $3}')
            
            # 确保所有值都是有效的浮点数
            if [[ -n "$load1" ]] && [[ -n "$load5" ]] && [[ -n "$load15" ]] && \
               [[ "$load1" =~ ^[0-9]+\.?[0-9]*$ ]] && [[ "$load5" =~ ^[0-9]+\.?[0-9]*$ ]] && [[ "$load15" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                
                local load_info=$(jq -n \
                    --arg load1 "$load1" \
                    --arg load5 "$load5" \
                    --arg load15 "$load15" \
                    '{
                        load_avg_1: ($load1 | tonumber),
                        load_avg_5: ($load5 | tonumber),
                        load_avg_15: ($load15 | tonumber)
                    }')
                
                echo "$load_info"
                return
            fi
        fi
    fi
    
    # 默认返回值
    echo '{"load_avg_1": 0, "load_avg_5": 0, "load_avg_15": 0}'
}

# 获取CPU使用率
get_cpu_usage() {
    local cpu_line_raw=$(grep 'cpu ' /proc/stat 2>/dev/null)
    if [ -n "$cpu_line_raw" ]; then
        cpu_line_raw=$(echo "$cpu_line_raw" | tr -d '\r\n')
        # 使用更灵活的解析方式
        local user=$(echo "$cpu_line_raw" | awk '{print $2}')
        local nice=$(echo "$cpu_line_raw" | awk '{print $3}')
        local system=$(echo "$cpu_line_raw" | awk '{print $4}')
        local idle=$(echo "$cpu_line_raw" | awk '{print $5}')
        local iowait=$(echo "$cpu_line_raw" | awk '{print $6}')
        local irq=$(echo "$cpu_line_raw" | awk '{print $7}')
        local softirq=$(echo "$cpu_line_raw" | awk '{print $8}')
        local steal=$(echo "$cpu_line_raw" | awk '{print $9}')
        
        # 检查所有值是否存在且为数字
        if [[ -n "$user" ]] && [[ -n "$nice" ]] && [[ -n "$system" ]] && [[ -n "$idle" ]] && \
           [[ -n "$iowait" ]] && [[ -n "$irq" ]] && [[ -n "$softirq" ]] && [[ -n "$steal" ]] && \
           [[ "$user" =~ ^[0-9]+$ ]] && [[ "$nice" =~ ^[0-9]+$ ]] && [[ "$system" =~ ^[0-9]+$ ]] && \
           [[ "$idle" =~ ^[0-9]+$ ]] && [[ "$iowait" =~ ^[0-9]+$ ]] && [[ "$irq" =~ ^[0-9]+$ ]] && \
           [[ "$softirq" =~ ^[0-9]+$ ]] && [[ "$steal" =~ ^[0-9]+$ ]]; then
            
            local cpu_info=$(jq -n \
                --arg user "$user" \
                --arg nice "$nice" \
                --arg system "$system" \
                --arg idle "$idle" \
                --arg iowait "$iowait" \
                --arg irq "$irq" \
                --arg softirq "$softirq" \
                --arg steal "$steal" \
                '{
                    user: ($user | tonumber),
                    nice: ($nice | tonumber),
                    system: ($system | tonumber),
                    idle: ($idle | tonumber),
                    iowait: ($iowait | tonumber),
                    irq: ($irq | tonumber),
                    softirq: ($softirq | tonumber),
                    steal: ($steal | tonumber)
                }')
            
            echo "$cpu_info"
            return
        fi
    fi
    
    # 默认返回值
    echo '{"user": 0, "nice": 0, "system": 0, "idle": 0, "iowait": 0, "irq": 0, "softirq": 0, "steal": 0}'
}

# 获取内存信息
get_memory_info() {
    if [ -f "/proc/meminfo" ]; then
        local mem_total=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
        local mem_free=$(grep '^MemFree:' /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
        local buffers=$(grep '^Buffers:' /proc/meminfo | awk '{print $2}')
        local cached=$(grep '^Cached:' /proc/meminfo | awk '{print $2}')
        
        # 检查所有值是否存在且为数字
        if [[ -n "$mem_total" ]] && [[ -n "$mem_free" ]] && [[ -n "$buffers" ]] && [[ -n "$cached" ]]; then
            # MemAvailable在较老的内核中可能不存在
            if [ -z "$mem_available" ]; then
                mem_available=$mem_free
            fi
            
            # 确保所有值都是数字
            if [[ "$mem_total" =~ ^[0-9]+$ ]] && [[ "$mem_free" =~ ^[0-9]+$ ]] && \
               [[ "$mem_available" =~ ^[0-9]+$ ]] && [[ "$buffers" =~ ^[0-9]+$ ]] && [[ "$cached" =~ ^[0-9]+$ ]]; then
                
                local mem_info=$(jq -n \
                    --arg mem_total "$mem_total" \
                    --arg mem_free "$mem_free" \
                    --arg mem_available "$mem_available" \
                    --arg buffers "$buffers" \
                    --arg cached "$cached" \
                    '{
                        MemTotal: ($mem_total | tonumber),
                        MemFree: ($mem_free | tonumber),
                        MemAvailable: ($mem_available | tonumber),
                        Buffers: ($buffers | tonumber),
                        Cached: ($cached | tonumber)
                    }')
                
                echo "$mem_info"
                return
            fi
        fi
    fi
    
    # 默认返回值
    echo '{"MemTotal": 0, "MemFree": 0, "MemAvailable": 0, "Buffers": 0, "Cached": 0}'
}

# 获取温度信息
get_temperature() {
    local temp_info="[]"
    if [ -d "/sys/class/thermal" ]; then
        for thermal_zone in /sys/class/thermal/thermal_zone*; do
            # 检查路径是否存在
            if [ -d "$thermal_zone" ]; then
                if [ -f "$thermal_zone/type" ] && [ -f "$thermal_zone/temp" ]; then
                    local zone_type=$(cat "$thermal_zone/type" 2>/dev/null)
                    local zone_temp=$(cat "$thermal_zone/temp" 2>/dev/null)
                    if [ -n "$zone_type" ] && [ -n "$zone_temp" ]; then
                        zone_type=$(echo "$zone_type" | tr -d '\r\n')
                        zone_temp=$(echo "$zone_temp" | tr -d '\r\n')
                        
                        # 确保温度值为数字
                        if [[ "$zone_temp" =~ ^-?[0-9]+$ ]]; then
                            # 处理温度值（有些系统以毫摄氏度为单位）
                            if [ "$zone_temp" -gt 10000 ]; then
                                zone_temp=$((zone_temp / 1000))
                            fi
                            
                            local temp_obj=$(jq -n \
                                --arg type "$zone_type" \
                                --arg temp "$zone_temp" \
                                '{type: $type, temp: ($temp | tonumber)}')
                            temp_info=$(echo "$temp_info" | jq --argjson obj "$temp_obj" '. + [$obj]')
                        fi
                    fi
                fi
            fi
        done
    fi
    echo "$temp_info"
}

# 获取网络接口信息
get_network_info() {
    # 获取默认网络接口，增加更多可能的接口类型以提高兼容性
    local interfaces=$(ls /sys/class/net/ 2>/dev/null | grep -E 'eth|wlan|enp|wlp|usb|ppp|br|vlan' | head -5)
    
    # 如果没有找到标准接口，尝试获取所有接口（排除loopback）
    if [ -z "$interfaces" ]; then
        interfaces=$(ls /sys/class/net/ 2>/dev/null | grep -v lo | head -5)
    fi
    
    # 构建接口信息数组
    local interface_array="[]"
    for interface in $interfaces; do
        if [ -f "/sys/class/net/$interface/statistics/rx_bytes" ] && [ -f "/sys/class/net/$interface/statistics/tx_bytes" ]; then
            local rx_bytes_raw=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null)
            local tx_bytes_raw=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null)
            
            # 处理可能的空值或错误
            if [ -n "$rx_bytes_raw" ] && [ -n "$tx_bytes_raw" ]; then
                rx_bytes_raw=$(echo "$rx_bytes_raw" | tr -d '\r\n')
                tx_bytes_raw=$(echo "$tx_bytes_raw" | tr -d '\r\n')
                
                # 确保值为数字
                if [[ "$rx_bytes_raw" =~ ^[0-9]+$ ]] && [[ "$tx_bytes_raw" =~ ^[0-9]+$ ]]; then
                    local interface_info=$(jq -n \
                        --arg name "$interface" \
                        --arg rx_bytes "$rx_bytes_raw" \
                        --arg tx_bytes "$tx_bytes_raw" \
                        '{name: $name, rx_bytes: ($rx_bytes | tonumber), tx_bytes: ($tx_bytes | tonumber)}')
                    
                    interface_array=$(echo "$interface_array" | jq --argjson info "$interface_info" '. + [$info]')
                fi
            fi
        fi
    done
    
    echo "$interface_array"
}

# 获取磁盘信息
get_disk_info() {
    # 获取根文件系统使用情况
    local disk_usage_raw=$(df / 2>/dev/null | tail -1)
    
    if [ -n "$disk_usage_raw" ]; then
        # 解析df命令输出
        local total=$(echo "$disk_usage_raw" | awk '{print $2}')
        local used=$(echo "$disk_usage_raw" | awk '{print $3}')
        local available=$(echo "$disk_usage_raw" | awk '{print $4}')
        local usage_percent=$(echo "$disk_usage_raw" | awk '{print $5}')
        
        # 确保所有值都存在且为数字
        if [[ -n "$total" ]] && [[ -n "$used" ]] && [[ -n "$available" ]] && [[ -n "$usage_percent" ]]; then
            # 移除可能的千位分隔符和百分号
            total=$(echo "$total" | sed 's/[,%]//g')
            used=$(echo "$used" | sed 's/[,%]//g')
            available=$(echo "$available" | sed 's/[,%]//g')
            usage_percent=$(echo "$usage_percent" | sed 's/[%]//g')
            
            # 确保所有值都是数字
            if [[ "$total" =~ ^[0-9]+$ ]] && [[ "$used" =~ ^[0-9]+$ ]] && [[ "$available" =~ ^[0-9]+$ ]] && [[ "$usage_percent" =~ ^[0-9]+$ ]]; then
                local disk_info=$(jq -n \
                    --arg total "$total" \
                    --arg used "$used" \
                    --arg available "$available" \
                    --arg usage "$usage_percent%" \
                    '{total: ($total | tonumber), used: ($used | tonumber), available: ($available | tonumber), usage: $usage}')
                
                echo "$disk_info"
                return
            fi
        fi
    fi
    
    # 默认返回值
    echo '{"total": 0, "used": 0, "available": 0, "usage": "0%"}'
}

# 收集系统状态
collect_status() {
    # 使用临时文件构建JSON对象，避免字符串拼接错误
    local temp_json=$(mktemp)
    trap 'rm -f "$temp_json"' EXIT
    
    # 初始化基础JSON对象
    echo '{}' > "$temp_json"
    
    # 添加时间戳
    if [ "$(get_config_value "enable_timestamp" "true")" = "true" ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        jq --arg ts "$timestamp" '. + {timestamp: $ts}' "$temp_json" > "$temp_json.tmp" && mv "$temp_json.tmp" "$temp_json"
    fi
    
    # 添加系统负载
    if [ "$(get_config_value "enable_load_avg" "true")" = "true" ]; then
        local load_avg=$(get_load_average)
        if echo "$load_avg" | jq empty >/dev/null 2>&1; then
            jq --argjson load "$load_avg" '. + {load_avg: $load}' "$temp_json" > "$temp_json.tmp" && mv "$temp_json.tmp" "$temp_json"
        fi
    fi
    
    # 添加CPU使用率
    if [ "$(get_config_value "enable_cpu_usage" "true")" = "true" ]; then
        local cpu_usage=$(get_cpu_usage)
        if echo "$cpu_usage" | jq empty >/dev/null 2>&1; then
            jq --argjson cpu "$cpu_usage" '. + {cpu_usage: $cpu}' "$temp_json" > "$temp_json.tmp" && mv "$temp_json.tmp" "$temp_json"
        fi
    fi
    
    # 添加内存信息
    if [ "$(get_config_value "enable_memory_info" "true")" = "true" ]; then
        local memory_info=$(get_memory_info)
        if echo "$memory_info" | jq empty >/dev/null 2>&1; then
            jq --argjson mem "$memory_info" '. + {memory_info: $mem}' "$temp_json" > "$temp_json.tmp" && mv "$temp_json.tmp" "$temp_json"
        fi
    fi
    
    # 添加温度信息
    if [ "$(get_config_value "enable_temperature" "true")" = "true" ]; then
        local temperature=$(get_temperature)
        if echo "$temperature" | jq empty >/dev/null 2>&1; then
            jq --argjson temp "$temperature" '. + {temperature: $temp}' "$temp_json" > "$temp_json.tmp" && mv "$temp_json.tmp" "$temp_json"
        fi
    fi
    
    # 添加网络接口信息
    if [ "$(get_config_value "enable_network_info" "true")" = "true" ]; then
        local network_info=$(get_network_info)
        if echo "$network_info" | jq empty >/dev/null 2>&1; then
            jq --argjson net "$network_info" '. + {network_info: $net}' "$temp_json" > "$temp_json.tmp" && mv "$temp_json.tmp" "$temp_json"
        fi
    fi
    
    # 添加磁盘信息
    if [ "$(get_config_value "enable_disk_info" "true")" = "true" ]; then
        local disk_info=$(get_disk_info)
        if echo "$disk_info" | jq empty >/dev/null 2>&1; then
            jq --argjson disk "$disk_info" '. + {disk_info: $disk}' "$temp_json" > "$temp_json.tmp" && mv "$temp_json.tmp" "$temp_json"
        fi
    fi
    
    # 输出最终结果
    cat "$temp_json"
}

# 处理HTTP请求
handle_request() {
    local request_method=$1
    local request_path=$2
    local content_length_header=$3

    log_message "开始处理请求: $request_method $request_path"
    
    # 处理CORS预检请求
    if [ "$request_method" = "OPTIONS" ]; then
        local response="HTTP/1.1 200 OK\r\n"
        response+="Access-Control-Allow-Origin: *\r\n"
        response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        response+="Access-Control-Allow-Headers: Content-Type\r\n"
        response+="Content-Length: 0\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        log_message "返回OPTIONS响应"
        echo -e "$response"
        return
    fi

    if [ "$request_path" = "/" ]; then
        local api_info=$(cat <<EOF
{
  "message": "ISAPI - 系统监控工具",
  "version": "1.0.0",
  "endpoints": {
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
        local content_length=$(echo -n "$api_info" | wc -c)
        local response="HTTP/1.1 200 OK\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Access-Control-Allow-Origin: *\r\n"
        response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        response+="Access-Control-Allow-Headers: Content-Type\r\n"
        response+="Content-Length: $content_length\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+="$api_info"
        log_message "返回根路径响应，长度: $content_length"
        echo -e "$response"
    elif [ "$request_path" = "/api/status" ]; then
        log_message "处理/api/status请求"
        # 返回JSON数据
        if [ -f "$STATUS_FILE" ] && [ -s "$STATUS_FILE" ]; then
            local file_content=$(cat "$STATUS_FILE")
            # 检查内容是否为有效的JSON
            if echo "$file_content" | jq . >/dev/null 2>&1; then
                local content_length=$(echo -n "$file_content" | wc -c)
                local response="HTTP/1.1 200 OK\r\n"
                response+="Content-Type: application/json; charset=utf-8\r\n"
                response+="Access-Control-Allow-Origin: *\r\n"
                response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
                response+="Access-Control-Allow-Headers: Content-Type\r\n"
                response+="Content-Length: $content_length\r\n"
                response+="Connection: close\r\n"
                response+="\r\n"
                response+="$file_content"
                log_message "返回状态数据，长度: $content_length"
                echo -e "$response"
            else
                # 内容不是有效的JSON
                local error_response='{"error": "Invalid data format"}'
                local content_length=$(echo -n "$error_response" | wc -c)
                local response="HTTP/1.1 500 Internal Server Error\r\n"
                response+="Content-Type: application/json; charset=utf-8\r\n"
                response+="Access-Control-Allow-Origin: *\r\n"
                response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
                response+="Access-Control-Allow-Headers: Content-Type\r\n"
                response+="Content-Length: $content_length\r\n"
                response+="Connection: close\r\n"
                response+="\r\n"
                response+="$error_response"
                log_message "返回状态数据格式错误，长度: $content_length"
                echo -e "$response"
            fi
        else
            local response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Access-Control-Allow-Origin: *\r\n"
            response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
            response+="Access-Control-Allow-Headers: Content-Type\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+='{"error": "No data available"}'
            log_message "状态数据文件不存在"
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/log" ]; then
        log_message "处理/api/log请求"
        # 返回日志内容
        if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
            local content=$(tail -n 50 "$LOG_FILE")
            local content_length=$(echo -n "$content" | wc -c)
            local response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: text/plain; charset=utf-8\r\n"
            response+="Access-Control-Allow-Origin: *\r\n"
            response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
            response+="Access-Control-Allow-Headers: Content-Type\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="$content"
            log_message "返回日志数据，长度: $content_length"
            echo -e "$response"
        else
            local response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: text/plain; charset=utf-8\r\n"
            response+="Access-Control-Allow-Origin: *\r\n"
            response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
            response+="Access-Control-Allow-Headers: Content-Type\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="暂无日志"
            log_message "日志文件不存在"
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "POST" ]; then
        log_message "处理POST /api/config请求"
        # 处理配置更新请求
        local post_data=""
        if [ -n "$content_length_header" ] && [ "$content_length_header" -gt 0 ]; then
            # 读取POST数据
            read -n "$content_length_header" post_data
        fi
        
        if [ -n "$post_data" ]; then
            echo "$post_data" > "$CONFIG_FILE"
            log_message "配置已更新"
        fi

        local response="HTTP/1.1 200 OK\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Access-Control-Allow-Origin: *\r\n"
        response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        response+="Access-Control-Allow-Headers: Content-Type\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+='{"status": "success", "message": "配置更新成功，将在下次数据收集时生效"}'
        log_message "返回配置更新响应"
        echo -e "$response"
    elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "GET" ]; then
        log_message "处理GET /api/config请求"
        # 返回当前配置
        if [ -f "$CONFIG_FILE" ]; then
            local config_content=$(cat "$CONFIG_FILE")
            local content_length=$(echo -n "$config_content" | wc -c)
            local response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Access-Control-Allow-Origin: *\r\n"
            response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
            response+="Access-Control-Allow-Headers: Content-Type\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="$config_content"
            log_message "返回配置数据，长度: $content_length"
            echo -e "$response"
        else
            local response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Access-Control-Allow-Origin: *\r\n"
            response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
            response+="Access-Control-Allow-Headers: Content-Type\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+='{"error": "Config file not found"}'
            log_message "配置文件不存在"
            echo -e "$response"
        fi
    else
        log_message "处理未知请求: $request_method $request_path"
        # 其他路径返回404
        local response="HTTP/1.1 404 Not Found\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Access-Control-Allow-Origin: *\r\n"
        response+="Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        response+="Access-Control-Allow-Headers: Content-Type\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+='{"error": "API endpoint not found"}'
        echo -e "$response"
    fi
}

# 启动HTTP服务器（最终版本）
start_http_server() {
    log_message "HTTP服务器开始监听端口: ${PORT}"
    
    # 采用最简单的实现方式，避免重复日志
    while true; do
        {
            # 读取请求行
            IFS= read -r request_line
            request_line=$(echo "$request_line" | tr -d '\r')
            
            if [ -n "$request_line" ]; then
                # 解析请求方法和路径
                request_method=$(echo "$request_line" | awk '{print $1}')
                request_path=$(echo "$request_line" | awk '{print $2}')
                [ -z "$request_path" ] && request_path="/"
                
                log_message "收到请求: $request_method $request_path"
                
                # 读取请求头，寻找Content-Length
                content_length=0
                while IFS= read -r header_line; do
                    header_line=$(echo "$header_line" | tr -d '\r')
                    # 检查是否为空行（请求头结束）
                    if [ -z "$header_line" ]; then
                        break
                    fi
                    # 解析Content-Length
                    if echo "$header_line" | grep -i '^Content-Length:' > /dev/null; then
                        content_length=$(echo "$header_line" | awk '{print $2}')
                    fi
                done
                
                # 处理请求并返回响应
                handle_request "$request_method" "$request_path" "$content_length"
            fi
        } | nc -l -p "$PORT" >/dev/null 2>&1
        
        # 短暂休眠避免CPU过度使用
        sleep 0.1
    done
}

# 处理传入请求的函数
handle_incoming_request() {
    # 读取并解析HTTP请求
    local request_data=""
    local request_method=""
    local request_path="/"
    local content_length=0
    
    # 读取请求的第一行以获取方法和路径
    IFS= read -r request_line
    if [ -n "$request_line" ]; then
        request_line=$(echo "$request_line" | tr -d '\r')
        request_method=$(echo "$request_line" | awk '{print $1}')
        request_path=$(echo "$request_line" | awk '{print $2}')
        [ -z "$request_path" ] && request_path="/"
        
        log_message "收到请求: $request_method $request_path"
        
        # 读取请求头
        while IFS= read -r header_line; do
            header_line=$(echo "$header_line" | tr -d '\r')
            
            # 空行表示请求头结束
            if [ -z "$header_line" ]; then
                break
            fi
            
            # 查找Content-Length头
            if echo "$header_line" | grep -i "^Content-Length:" >/dev/null 2>&1; then
                content_length=$(echo "$header_line" | awk '{print $2}')
            fi
        done
        
        # 处理请求并返回响应
        handle_request "$request_method" "$request_path" "$content_length"
    fi
}

# 从socat处理请求的辅助函数
handle_request_from_socat() {
    local request_line=""
    local request_method=""
    local request_path="/"
    local content_length=0
    
    # 读取请求行
    IFS= read -r request_line
    request_line=$(echo "$request_line" | tr -d '\r')
    
    if [ -n "$request_line" ]; then
        request_method=$(echo "$request_line" | awk '{print $1}')
        request_path=$(echo "$request_line" | awk '{print $2}')
        [ -z "$request_path" ] && request_path="/"
        
        log_message "收到请求: $request_method $request_path"
        
        # 读取请求头
        while IFS= read -r header_line; do
            header_line=$(echo "$header_line" | tr -d '\r')
            
            # 空行表示请求头结束
            if [ -z "$header_line" ]; then
                break
            fi
            
            # 查找Content-Length头
            if echo "$header_line" | grep -i "^Content-Length:" >/dev/null 2>&1; then
                content_length=$(echo "$header_line" | awk '{print $2}')
            fi
        done
    fi
    
    # 处理请求并输出响应到标准输出（socat会将其发送给客户端）
    handle_request "$request_method" "$request_path" "$content_length"
}

# 处理客户端请求的函数
handle_client_requests() {
    local content_length=0
    local request_line=""
    local request_method=""
    local request_path="/"
    
    # 读取请求行
    IFS= read -r request_line
    if [ -n "$request_line" ]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        log_message "收到请求: $request_line"
        
        # 解析请求方法和路径
        request_method=$(echo "$request_line" | awk '{print $1}')
        request_path=$(echo "$request_line" | awk '{print $2}')
        [ -z "$request_path" ] && request_path="/"
        
        # 读取请求头，寻找Content-Length
        while IFS= read -r header_line && [ -n "$header_line" ]; do
            header_line=$(echo "$header_line" | tr -d '\r')
            # 检查是否为空行（请求头结束）
            if [ -z "$header_line" ]; then
                break
            fi
            # 解析Content-Length
            if echo "$header_line" | grep -i '^Content-Length:' > /dev/null; then
                content_length=$(echo "$header_line" | awk '{print $2}')
            fi
        done
        
        # 处理请求并返回响应
        handle_request "$request_method" "$request_path" "$content_length"
    fi
    
    # 返回空行表示响应结束
    echo ""
}

# 主函数
main() {
    # 确保日志文件存在
    touch "$LOG_FILE"
    
    log_message "Starting ISAPI service on port $PORT"
    log_message "API endpoints:"
    log_message "  GET  http://localhost:$PORT/ - API说明信息"
    log_message "  GET  http://localhost:$PORT/api/status - 系统状态信息"
    log_message "  GET  http://localhost:$PORT/api/log - 运行日志"
    log_message "  GET  http://localhost:$PORT/api/config - 当前配置"
    log_message "  POST http://localhost:$PORT/api/config - 更新配置"
    log_message "Refresh interval: ${REFRESH_INTERVAL}s"

    # 初始化配置文件
    init_config

    # 启动后台数据收集任务
    {
        log_message "开始数据收集任务，刷新间隔: ${REFRESH_INTERVAL}秒"
        while true; do
            # 确保状态文件目录可写
            if [ -w "$(dirname "$STATUS_FILE")" ] || [ -w "$STATUS_FILE" ]; then
                collect_status > "$STATUS_FILE" 2>/dev/null
                log_message "系统信息已更新"
            else
                log_message "警告: 无法写入状态文件 $STATUS_FILE"
            fi
            sleep "$REFRESH_INTERVAL"
        done
    } &

    # 等待第一次数据收集完成
    sleep 2

    # 启动HTTP服务器
    start_http_server
}

# 运行主函数
main "$@"