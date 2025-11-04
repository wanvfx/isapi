# ISAPI - 系统监控工具

## 简介

ISAPI 是一个基于 Docker 的轻量级系统监控解决方案，专为软路由设备设计。通过在软路由上部署该 Docker 容器，可以实时监控系统的各项关键指标，包括 CPU 使用率、内存使用情况、温度、网络接口状态和磁盘使用情况等。

本工具提供了一个 Web 界面，用户可以通过浏览器方便地查看系统状态、修改配置参数以及查看运行日志。

项目地址：[https://github.com/wanvfx/isapi](https://github.com/wanvfx/isapi)

## 功能特性

- 实时监控 CPU 使用率
- 内存使用情况监控
- 系统温度监控
- 网络接口流量统计
- 磁盘使用情况监控
- 可配置的监控项（可选择启用/禁用特定监控功能）
- 通过 Web 界面查看系统状态
- 通过 Web 界面修改配置参数
- 实时查看运行日志
- 通过 HTTP API 提供 JSON 格式数据
- 轻量级容器，资源占用少

## 部署到软路由详细教程

### 准备工作

在开始部署之前，请确认您的软路由满足以下条件：

1. 已经安装 Docker 服务
2. 确保软路由可以访问互联网（用于下载基础镜像和安装依赖包）
3. 确保目标端口（默认为15130）未被其他服务占用

### 方法一：在软路由上直接构建和运行（推荐）

这是最简单的部署方式，适用于大多数情况。

1. 在软路由上克隆项目仓库：
   ```bash
   git clone https://github.com/wanvfx/isapi.git
   cd isapi
   ```

2. 构建 Docker 镜像：
   ```bash
   docker build -t isapi .
   ```
   
   构建过程会自动完成以下步骤：
   - 使用 Alpine Linux 作为基础镜像
   - 安装必要系统工具（bash, jq, curl, procps 等）
   - 复制监控脚本和 Web 界面文件
   - 设置执行权限

3. 运行容器：
   ```bash
   docker run -d \
     --name isapi \
     --privileged \
     -p 15130:15130 \
     -v /proc:/proc:ro \
     -v /sys:/sys:ro \
     -v /etc:/etc:ro \
     --restart unless-stopped \
     isapi
   ```

   参数说明：
   - `-d`: 后台运行容器
   - `--name isapi`: 给容器命名为 isapi
   - `--privileged`: 特权模式运行（必须，用于访问系统信息）
   - `-p 15130:15130`: 映射端口，主机端口:容器端口
   - `-v /proc:/proc:ro`: 挂载 /proc 目录（只读）
   - `-v /sys:/sys:ro`: 挂载 /sys 目录（只读）
   - `-v /etc:/etc:ro`: 挂载 /etc 目录（只读）
   - `--restart unless-stopped`: 自动重启策略

   或者使用 docker-compose（如果软路由上安装了 docker-compose）：
   ```bash
   docker-compose up -d
   ```

### 方法二：使用GitHub Actions自动构建并部署（推荐）

如果您在Windows系统上遇到Docker构建问题，或者希望自动化构建流程，可以使用GitHub Actions：

1. 在GitHub仓库中创建Docker Hub访问令牌：
   - 登录Docker Hub
   - 进入Account Settings → Security
   - 创建新的Access Token

2. 在GitHub仓库中配置Secrets：
   - 进入仓库Settings → Secrets and variables → Actions
   - 添加以下两个Secrets：
     - `DOCKER_USERNAME`: 您的Docker Hub用户名
     - `DOCKER_PASSWORD`: 您刚才创建的访问令牌

3. GitHub Actions会自动在每次push时构建并推送到Docker Hub

4. 在软路由上直接拉取镜像：
   ```bash
   docker pull wanvfx/isapi:latest
   ```

### 方法三：在其他设备上构建后导出导入

如果您的构建环境遇到问题，可以采用此方法：

1. 在一台能够正常运行Docker的Linux设备上克隆并构建：
   ```bash
   git clone https://github.com/wanvfx/isapi.git
   cd isapi
   docker build -t isapi:latest .
   ```

2. 导出镜像为 tar 文件：
   ```bash
   docker save -o isapi.tar isapi:latest
   ```

3. 将 isapi.tar 文件传输到软路由上（可通过 scp、U盘等方式）

4. 在软路由上导入镜像：
   - 打开 iStoreOS 的 Docker 管理界面
   - 导航到"镜像文件"页面
   - 点击"导入镜像文件"按钮
   - 选择"本地文件路径"并输入 isapi.tar 文件的完整路径
   - 点击"导入配置信息"按钮完成导入

5. 运行容器：
   ```bash
   docker run -d \
     --name isapi \
     --privileged \
     -p 15130:15130 \
     -v /proc:/proc:ro \
     -v /sys:/sys:ro \
     -v /etc:/etc:ro \
     --restart unless-stopped \
     isapi
   ```

### 方法四：使用 iStoreOS 的"解析 CLI"模式直接创建容器

如果您使用的是 iStoreOS 系统（如 EasePi R1 软路由），可以通过系统内置的"解析 CLI"功能快速部署容器：

1. 确保您已经通过以下任一方式准备好了 isapi 镜像：
   - 在软路由上直接构建
   - 从其他设备导出导入
   - 从镜像仓库拉取（如果已推送）

2. 打开 iStoreOS 的 Docker 管理界面

3. 选择"创建新的 Docker 容器"

4. 切换到"解析 CLI"标签页

5. 在命令输入框中粘贴以下命令：
   ```bash
   docker run -d \
     --name isapi \
     --privileged \
     -p 15130:15130 \
     -v /proc:/proc:ro \
     -v /sys:/sys:ro \
     -v /etc:/etc:ro \
     --restart unless-stopped \
     isapi
   ```

6. 点击"应用"按钮，系统将自动解析命令并创建容器

> **注意事项**：
> - 该方法仅适用于已存在 isapi 镜像的情况
> - 确保使用的镜像与您的设备架构兼容（如 ARMv8）
> - `--privileged` 参数是必需的，以便容器可以访问系统信息
> - 如果需要自定义环境变量，可以在命令中添加 `-e` 参数

## 验证部署结果

部署完成后，您可以通过以下方式验证：

1. 检查容器运行状态：
   ```bash
   docker ps
   ```
   应该能看到名为 isapi 的容器正在运行

2. 查看容器日志：
   ```bash
   docker logs isapi
   ```
   如果部署成功，应该能看到类似 "Starting ISAPI service on port 15130" 的日志输出

3. 通过浏览器访问 Web 界面：
   打开浏览器，访问 `http://您的软路由IP:15130`
   您应该能看到系统监控仪表板

## 使用说明

### 部署方法

### 方法一：使用 docker-compose（推荐）

```bash
# 克隆或下载项目
git clone https://github.com/wanvfx/isapi.git
cd isapi

# 启动容器
docker-compose up -d
```

### 方法二：直接使用 docker 命令

```bash
# 克隆项目
git clone https://github.com/wanvfx/isapi.git
cd isapi

# 构建镜像
docker build -t isapi .

# 启动容器
docker run -d \
  --name isapi \
  --privileged \
  --network host \
  -v /proc:/proc:ro \
  -v /sys:/sys:ro \
  -v /etc:/etc:ro \
  -e PORT=15130 \
  -e REFRESH_INTERVAL=5 \
  isapi
```

## 环境变量

| 变量名             | 默认值 | 说明                   |
|------------------|-------|------------------------|
| PORT             | 15130 | HTTP 服务监听端口        |
| REFRESH_INTERVAL | 5     | 系统信息刷新间隔（秒）    |

## Web 界面使用说明

构建并启动容器后，可以通过浏览器访问 `http://your-router-ip:15130/` 来使用 Web 界面。

Web 界面包含以下功能区域：

1. **系统状态**：显示当前启用的监控项及其数值
2. **配置参数**：
   - 端口设置
   - 刷新间隔设置
   - 监控项启用/禁用设置
3. **运行日志**：实时显示系统运行日志

### 监控项配置

默认情况下，所有监控项都处于启用状态。用户可以通过 Web 界面的复选框来启用或禁用特定的监控功能：

- 获取时间戳
- 获取系统负载
- 获取CPU使用率
- 获取内存信息
- 获取温度信息
- 获取网络接口信息
- 获取磁盘使用情况

## API 接口

### 获取系统状态

```
GET http://<router-ip>:15130/api/status
```

### 获取运行日志

```
GET http://<router-ip>:15130/api/log
```

### 获取配置

```
GET http://<router-ip>:15130/api/config
```

### 更新配置

```
POST http://<router-ip>:15130/api/config
```

## 安全注意事项

1. 本工具需要特权模式运行以获取系统信息，请确保在受信任的环境中使用
2. Web 界面默认没有身份验证机制，建议在内网环境中使用
3. 如需在公网环境中使用，建议添加反向代理和身份验证

## 性能影响

本工具设计为轻量级监控服务，对系统性能影响极小：
- 数据采集频率可配置，默认每5秒一次
- 使用 Alpine Linux 基础镜像，资源占用少
- 通过读取 `/proc` 和 `/sys` 虚拟文件系统获取信息，I/O 开销低

## 故障排除

### 容器无法启动
- 检查 Docker 是否正常运行
- 确认系统支持 Linux 容器

### 无法访问 Web 界面
- 检查防火墙设置
- 确认端口是否正确映射
- 查看容器日志：`docker logs isapi`

### 监控数据不准确
- 检查相关系统文件是否可访问
- 确认容器是否以特权模式运行