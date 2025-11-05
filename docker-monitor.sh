#!/bin/bash

# 设置变量
PORT=${PORT:-15130}
REFRESH_INTERVAL=${REFRESH_INTERVAL:-5}
STATUS_FILE="/tmp/status.json"
LOG_FILE="/tmp/app.log"
CONFIG_FILE="/tmp/config.json"

# 默认配置
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
    fi
}

# 读取配置项
get_config_value() {
    local key=$1
    local default_value=$2
    local value=$(jq -r --arg key "$key" '.[$key] // $default_value' "$CONFIG_FILE" 2>/dev/null)
    echo "$value"
}

# 记录日志
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# 获取系统负载
get_load_average() {
    local load_avg_raw=$(cat /proc/loadavg 2>/dev/null | awk '{print $1","$2","$3}')
    if [ -n "$load_avg_raw" ]; then
        load_avg_raw=$(echo "$load_avg_raw" | tr -d '\r\n')
        echo "$load_avg_raw" | jq -R 'split(",") | map(tonumber) | {load_avg_1: .[0], load_avg_5: .[1], load_avg_15: .[2]}'
    else
        echo '{"load_avg_1": 0, "load_avg_5": 0, "load_avg_15": 0}'
    fi
}

# 获取CPU使用率
get_cpu_usage() {
    local cpu_line_raw=$(grep 'cpu ' /proc/stat 2>/dev/null)
    if [ -n "$cpu_line_raw" ]; then
        cpu_line_raw=$(echo "$cpu_line_raw" | tr -d '\r\n')
        local cpu_line=$(echo "$cpu_line_raw" | awk '{print $2","$3","$4","$5","$6","$7","$8","$9}')
        echo "$cpu_line" | jq -R 'split(",") | map(tonumber) | 
        {
            user: .[0],
            nice: .[1],
            system: .[2],
            idle: .[3],
            iowait: .[4],
            irq: .[5],
            softirq: .[6],
            steal: .[7]
        }'
    else
        echo '{"user": 0, "nice": 0, "system": 0, "idle": 0, "iowait": 0, "irq": 0, "softirq": 0, "steal": 0}'
    fi
}

# 获取内存信息
get_memory_info() {
    local mem_info=$(cat /proc/meminfo 2>/dev/null | grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached')
    if [ -n "$mem_info" ]; then
        mem_info=$(echo "$mem_info" | tr -d '\r\n')
        echo "$mem_info" | jq -R 'split("\n") | map(split(":")) | map({key: .[0], value: .[1] | sub(" kB$"; "") | tonumber}) | from_entries'
    else
        echo '{"MemTotal": 0, "MemFree": 0, "MemAvailable": 0, "Buffers": 0, "Cached": 0}'
    fi
}

# 获取温度信息
get_temperature() {
    local temp_info="[]"
    if [ -d "/sys/class/thermal" ]; then
        for thermal_zone in /sys/class/thermal/thermal_zone*; do
            if [ -f "$thermal_zone/type" ] && [ -f "$thermal_zone/temp" ]; then
                local zone_type=$(cat "$thermal_zone/type" 2>/dev/null)
                local zone_temp=$(cat "$thermal_zone/temp" 2>/dev/null)
                if [ -n "$zone_type" ] && [ -n "$zone_temp" ]; then
                    zone_type=$(echo "$zone_type" | tr -d '\r\n')
                    zone_temp=$(echo "$zone_temp" | tr -d '\r\n')
                    local temp_obj=$(jq -n \
                        --arg type "$zone_type" \
                        --arg temp "$zone_temp" \
                        '{type: $type, temp: ($temp | tonumber)}')
                    temp_info=$(echo "$temp_info" | jq --argjson obj "$temp_obj" '. + [$obj]')
                fi
            fi
        done
    fi
    echo "$temp_info"
}

# 获取网络接口信息
get_network_info() {
    # 获取默认网络接口
    local interfaces=$(ls /sys/class/net/ | grep -E 'eth|wlan|enp|wlp' | head -3)
    
    # 构建接口信息数组
    local interface_array="[]"
    for interface in $interfaces; do
        if [ -f "/sys/class/net/$interface/statistics/rx_bytes" ] && [ -f "/sys/class/net/$interface/statistics/tx_bytes" ]; then
            local rx_bytes_raw=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
            local tx_bytes_raw=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null)
            
            rx_bytes_raw=$(echo "$rx_bytes_raw" | tr -d '\r\n')
            tx_bytes_raw=$(echo "$tx_bytes_raw" | tr -d '\r\n')
            
            local interface_info=$(jq -n \
                --arg name "$interface" \
                --arg rx_bytes "$rx_bytes_raw" \
                --arg tx_bytes "$tx_bytes_raw" \
                '{name: $name, rx_bytes: ($rx_bytes | tonumber), tx_bytes: ($tx_bytes | tonumber)}')
            
            interface_array=$(echo "$interface_array" | jq --argjson info "$interface_info" '. + [$info]')
        fi
    done
    
    echo "$interface_array"
}

# 获取磁盘信息
get_disk_info() {
    # 获取根文件系统使用情况
    local disk_usage_raw=$(df / 2>/dev/null | tail -1 | awk '{print "{\"total\": "$2", \"used\": "$3", \"available\": "$4", \"usage\": \""$5"\"}"}')
    
    if [ -n "$disk_usage_raw" ]; then
        echo "$disk_usage_raw" | tr -d '\r\n' | jq .
    else
        echo '{"total": 0, "used": 0, "available": 0, "usage": "0%"}'
    fi
}

# 收集系统状态
collect_status() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local status="{"
    
    # 添加时间戳
    if [ "$(get_config_value "enable_timestamp" "true")" = "true" ]; then
        status+="\"timestamp\": \"$timestamp\","
    fi
    
    # 添加系统负载
    if [ "$(get_config_value "enable_load_avg" "true")" = "true" ]; then
        local load_avg=$(get_load_average)
        status+="\"load_avg\": $load_avg,"
    fi
    
    # 添加CPU使用率
    if [ "$(get_config_value "enable_cpu_usage" "true")" = "true" ]; then
        local cpu_usage=$(get_cpu_usage)
        status+="\"cpu_usage\": $cpu_usage,"
    fi
    
    # 添加内存信息
    if [ "$(get_config_value "enable_memory_info" "true")" = "true" ]; then
        local memory_info=$(get_memory_info)
        status+="\"memory_info\": $memory_info,"
    fi
    
    # 添加温度信息
    if [ "$(get_config_value "enable_temperature" "true")" = "true" ]; then
        local temperature=$(get_temperature)
        status+="\"temperature\": $temperature,"
    fi
    
    # 添加网络接口信息
    if [ "$(get_config_value "enable_network_info" "true")" = "true" ]; then
        local network_info=$(get_network_info)
        status+="\"network_info\": $network_info,"
    fi
    
    # 添加磁盘信息
    if [ "$(get_config_value "enable_disk_info" "true")" = "true" ]; then
        local disk_info=$(get_disk_info)
        status+="\"disk_info\": $disk_info,"
    fi
    
    # 移除最后一个逗号并关闭JSON对象
    status=$(echo "$status" | sed 's/,$//')
    status+="}"
    
    echo "$status" | jq .
}

# 启动HTTP服务器
start_http_server() {
    log_message "HTTP服务器开始监听端口: ${PORT}"
    while true; do
        {
            # 读取请求行
            if ! read -r request_line; then
                continue
            fi
            log_message "收到请求: $request_line"

            # 临时变量存储 Content-Length
            local content_length=""
            local header_line

            # 读取所有请求头
            while IFS= read -r header_line; do
                # 移除可能的 \r 字符
                header_line=$(echo "$header_line" | tr -d '\r')
                # 检查是否为空行（请求头结束）
                if [ -z "$header_line" ]; then
                    break
                fi
                # 记录请求头（可选）
                log_message "请求头: $header_line"
                # 提取 Content-Length
                if echo "$header_line" | grep -iq "content-length"; then
                    content_length=$(echo "$header_line" | awk '{print $2}')
                fi
            done

            # 解析请求方法和路径
            local request_method=$(echo "$request_line" | awk '{print $1}')
            local request_path=$(echo "$request_line" | awk '{print $2}')
            [ -z "$request_path" ] && request_path="/"

            log_message "处理请求: $request_method $request_path"

            # 处理请求并传入 content_length（用于POST）
            handle_request "$request_method" "$request_path" "$content_length"
        } | nc -l -p "$PORT" -q 1 2>/dev/null || true
        sleep 0.1
    done
}


# 处理HTTP请求
handle_request() {
    local request_method=$1
    local request_path=$2
    local content_length_header=$3

    if [ "$request_path" = "/" ]; then
        # 返回API说明信息
        local api_info=$(cat <<'EOF'
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
        local content_length=$(echo -n "$api_info" | wc -c)
        local response="HTTP/1.1 200 OK\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Content-Length: $content_length\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+="$api_info"
        echo -e "$response"
    elif [ "$request_path" = "/api/status" ]; then
        # 返回JSON数据
        if [ -f "$STATUS_FILE" ]; then
            local file_content=$(cat "$STATUS_FILE")
            local content_length=$(echo -n "$file_content" | wc -c)
            local response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Access-Control-Allow-Origin: *\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="$file_content"
            echo -e "$response"
        else
            local response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+='{"error": "No data available"}'
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/log" ]; then
        # 返回日志内容
        if [ -f "$LOG_FILE" ]; then
            local content=$(tail -n 50 "$LOG_FILE")
            local content_length=$(echo -n "$content" | wc -c)
            local response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: text/plain; charset=utf-8\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="$content"
            echo -e "$response"
        else
            local response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: text/plain; charset=utf-8\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="暂无日志"
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "GET" ]; then
        # 返回当前配置
        if [ -f "$CONFIG_FILE" ]; then
            local config_content=$(cat "$CONFIG_FILE")
            local content_length=$(echo -n "$config_content" | wc -c)
            local response="HTTP/1.1 200 OK\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Content-Length: $content_length\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+="$config_content"
            echo -e "$response"
        else
            local response="HTTP/1.1 404 Not Found\r\n"
            response+="Content-Type: application/json; charset=utf-8\r\n"
            response+="Connection: close\r\n"
            response+="\r\n"
            response+='{"error": "Config file not found"}'
            echo -e "$response"
        fi
    elif [ "$request_path" = "/api/config" ] && [ "$request_method" = "POST" ]; then
        # 处理配置更新请求
        if [ -n "$content_length_header" ] && [ "$content_length_header" -gt 0 ]; then
            local post_data
            read -n "$content_length_header" post_data
            echo "$post_data" > "$CONFIG_FILE"
            log_message "配置已更新"
        fi

        local response="HTTP/1.1 200 OK\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+='{"status": "success", "message": "配置更新成功，将在下次数据收集时生效"}'
        echo -e "$response"
    else
        # 其他路径返回404
        local response="HTTP/1.1 404 Not Found\r\n"
        response+="Content-Type: application/json; charset=utf-8\r\n"
        response+="Connection: close\r\n"
        response+="\r\n"
        response+='{"error": "API endpoint not found"}'
        echo -e "$response"
    fi
}

# 主函数
main() {
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
            collect_status > "$STATUS_FILE"
            log_message "系统信息已更新"
            sleep "$REFRESH_INTERVAL"
        done
    } &

    # 启动HTTP服务器
    start_http_server
}

# 运行主函数
main "$@"
