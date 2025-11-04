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
    util-linux

# 创建工作目录
WORKDIR /app

# 复制ISAPI监控脚本
COPY docker-monitor.sh .

# 复制Web界面文件
COPY index.html .

# 复制API文件
COPY root/usr/share/wechatpush/api/ ./api/

# 创建必要的目录
RUN mkdir -p /tmp/wechatpush

# 设置权限
RUN chmod +x ./docker-monitor.sh

# 暴露端口
EXPOSE 15130

# 启动监控服务
CMD ["./docker-monitor.sh"]