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

## 快速部署（推荐）

由于项目已通过 GitHub Actions 自动构建并发布到 Docker Hub，您可以直接从 Docker Hub 拉取镜像进行部署：

```bash
docker pull zoyayaayaya/isapi:latest
```

然后运行容器：

```bash
docker run -d \
  --name isapi \
  --privileged \
  -p 15130:15130 \
  -v /proc:/proc:ro \
  -v /sys:/sys:ro \
  -v /etc:/etc:ro \
  --restart unless-stopped \
  zoyayaayaya/isapi:latest
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

部署完成后，通过浏览器访问 `http://您的软路由IP:15130` 即可使用 Web 界面。

## 在 iStoreOS 上部署

如果您使用的是 iStoreOS 系统（如 EasePi R1 软路由），可以通过系统内置的"解析 CLI"功能快速部署容器：

1. 确保已拉取镜像：
   ```bash
   docker pull zoyayaayaya/isapi:latest
   ```

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
     zoyayaayaya/isapi:latest
   ```

6. 点击"应用"按钮，系统将自动解析命令并创建容器

> **注意事项**：
> - `--privileged` 参数是必需的，以便容器可以访问系统信息
> - 确保使用的镜像与您的设备架构兼容（如 ARMv8）

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

## 特别说明：在Windows Docker Desktop环境下运行

如果在Windows Docker Desktop中运行本项目时遇到以下问题：
- 页面显示乱码
- 出现jq相关错误日志，如：
  ```
  jq: error (at <unknown>): string ("1051660\n0") cannot be parsed as a number
  jq: invalid JSON text passed to --argjson
  ```

这是因为Windows和Linux系统的换行符不一致导致的。脚本已经针对此问题进行了优化处理，
在最新版本中通过移除字符串中的`\r`和`\n`字符来解决此问题。

请确保使用最新版本的脚本运行项目。

## 配置说明

```
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

## 快速部署（推荐）

由于项目已通过 GitHub Actions 自动构建并发布到 Docker Hub，您可以直接从 Docker Hub 拉取镜像进行部署：

```bash
docker pull zoyayaayaya/isapi:latest
```

然后运行容器：

```bash
docker run -d \
  --name isapi \
  --privileged \
  -p 15130:15130 \
  -v /proc:/proc:ro \
  -v /sys:/sys:ro \
  -v /etc:/etc:ro \
  --restart unless-stopped \
  zoyayaayaya/isapi:latest
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

部署完成后，通过浏览器访问 `http://您的软路由IP:15130` 即可使用 Web 界面。

## 在 iStoreOS 上部署

如果您使用的是 iStoreOS 系统（如 EasePi R1 软路由），可以通过系统内置的"解析 CLI"功能快速部署容器：

1. 确保已拉取镜像：
   ```bash
   docker pull zoyayaayaya/isapi:latest
   ```

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
     zoyayaayaya/isapi:latest
   ```

6. 点击"应用"按钮，系统将自动解析命令并创建容器

> **注意事项**：
> - `--privileged` 参数是必需的，以便容器可以访问系统信息
> - 确保使用的镜像与您的设备架构兼容（如 ARMv8）

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
