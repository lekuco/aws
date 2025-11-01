# 亚马逊 EC2 搭建 SOCKS5 代理（基于 Xray）

本教程配合仓库内脚本 `0001.sh`，在 EC2 上一键安装并开启 SOCKS5 代理，可设定端口/用户名/密码。

## 适用环境
- **系统**：Debian/Ubuntu（使用 `apt` 与 `systemd`）。Amazon Linux/CentOS 请勿使用此脚本。
- **权限**：`root` 或 `sudo` 权限。
- **网络**：EC2 安全组需放行你设定的 SOCKS5 端口（默认 1080，TCP/UDP）。

## 准备工作
- 生成或下载 **SSH 公钥**，将其添加到 EC2（创建实例时或事后在控制台里添加）。
- 连接工具：例如 FinalShell（https://www.hostbuf.com/）。
  - EC2 默认只支持公钥登录，FinalShell 选择“公钥”方式连接。

## 安装与启动（使用脚本）
1) 将 `0001.sh` 上传到服务器（SFTP/FinalShell 均可）。
2) 在服务器执行：
```bash
chmod +x 0001.sh
sudo ./0001.sh [端口] [用户名] [密码]
# 示例：sudo ./0001.sh 1080 admin myPass123
# 不传参数时：端口=1080，用户=admin，密码为随机生成
```

脚本会自动：
- 安装 `unzip`、`wget`（如缺失）。
- 下载并安装 Xray 到 `/root/e1/`，生成配置 `/etc/xray/serve.toml`。
- 开放防火墙端口（尝试 `ufw` 或 `iptables`）。
- 写入并启用 systemd 服务 `xray.service`。
- 生成访问信息到：`/home/ubuntu/ip/<公网IP>.txt`。

完成后输出类似：
```
【SOCKS5代理配置信息】
公网IP: <ip>:<端口>:<用户名>:<密码>
```

## 客户端连接
- 代理类型：`SOCKS5`
- 服务器：你的 EC2 公网 IP
- 端口：安装时设定的端口（默认 1080）
- 认证：用户名/密码（脚本参数或随机生成）

## 常用运维命令
```bash
# 查看服务状态
sudo systemctl status xray

# 查看日志
sudo journalctl -u xray -e --no-pager

# 重启服务（修改配置后）
sudo systemctl restart xray

# 配置文件位置
cat /etc/xray/serve.toml

# 重新设置端口/账号（直接重新运行脚本即可）
sudo ./0001.sh 1080 admin newPass
```

## 安全组与防火墙说明
- 在 **AWS 控制台 → EC2 → 安全组** 中，添加入站规则放行你的端口（TCP 与 UDP）。
- 如果使用 `ufw`，可执行：
```bash
sudo ufw allow 1080/tcp
sudo ufw allow 1080/udp
sudo ufw reload
```
（上述端口替换为你设置的端口）

## 常见问题
- 端口不通：优先检查 AWS 安全组入站规则，其次查看系统防火墙、服务状态与日志。
- 日志报错：使用 `journalctl -u xray -e` 查看详细错误。
- 不是 Debian/Ubuntu：脚本使用 `apt`，请更换为 Debian/Ubuntu 系统后再执行。
- 无法下载文件：确认服务器可访问 GitHub 相关地址，或手动上传所需文件后重试。

## 可选：卸载/清理
```bash
sudo systemctl stop xray
sudo systemctl disable xray
sudo rm -f /etc/systemd/system/xray.service
sudo systemctl daemon-reload

sudo rm -rf /etc/xray /root/e1 /root/Xray-linux-64.zip /home/ubuntu/ip
```

—— 完 ——
