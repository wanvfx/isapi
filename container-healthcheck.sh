#!/bin/bash

echo "=================================="
echo "   容器健康诊断工具 v1.0"
echo "=================================="

echo ""
echo "1. 📋 系统基本信息:"
echo "   主机名: $(hostname)"
echo "   当前时间: $(date)"
echo "   系统架构: $(uname -m)"
echo "   Alpine版本: $(cat /etc/alpine-release 2>/dev/null || echo '未知')"

echo ""
echo "2. 🔍 进程检查:"
echo "   docker-monitor.sh 进程:"
ps aux | grep -v grep | grep docker-monitor.sh || echo "   未找到相关进程"

echo ""
echo "3. 🌐 网络检查:"
echo "   端口监听状态:"
netstat -tuln | grep :15130 || echo "   端口15130未监听"

echo ""
echo "4. 📁 文件检查:"
echo "   /app 目录内容:"
ls -la /app/

echo ""
echo "5. 📊 日志检查:"
if [ -f "/app/isapi.log" ]; then
    echo "   最近5条日志:"
    tail -5 /app/isapi.log
else
    echo "   日志文件不存在"
fi

echo ""
echo "6. 🧪 API测试:"
echo "   测试本地API访问..."
curl -s -o /dev/null -w "   状态码: %{http_code}\n" http://localhost:15130/ || echo "   API访问失败"

echo ""
echo "7. 🔧 配置检查:"
if [ -f "/app/config.json" ]; then
    echo "   当前配置:"
    cat /app/config.json
else
    echo "   配置文件不存在"
fi

echo ""
echo "=================================="
echo "   诊断完成 - 检查上方输出"
echo "=================================="