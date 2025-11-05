# 使用轻量级基础镜像
FROM alpine:latest

# 安装必要的工具
RUN apk add --no-cache \
    bash \
    jq \
    curl \
    procps \
    lm-sensors \
    iproute2 \
    util-linux \
    netcat-openbsd

# 创建工作目录
WORKDIR /app

# 复制ISAPI监控脚本和诊断脚本
COPY docker-monitor.sh .
COPY container-healthcheck.sh .

# 设置脚本可执行权限
RUN chmod +x docker-monitor.sh container-healthcheck.sh

# 创建日志和状态文件
RUN touch /app/isapi.log /app/status.json /app/config.json

# 暴露端口
EXPOSE 15130

# 启动服务
CMD ["./docker-monitor.sh"]