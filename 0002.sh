#!/bin/bash

echo "====================================="
echo "SOCKS5 代理安装配置"
echo "====================================="

# 交互式输入配置
echo -n "请输入SOCKS端口 (默认1080): "
read input_port
socks_port=${input_port:-1080}

echo -n "请输入用户名 (默认admin): "
read input_user
socks_user=${input_user:-admin}

echo -n "请输入密码 (默认随机生成): "
read input_pass
socks_pass=${input_pass:-$(openssl rand -base64 12)}

echo ""
echo "====================================="
echo "您的SOCKS5代理配置:"
echo "端口: $socks_port"
echo "用户名: $socks_user"
echo "密码: $socks_pass"
echo "====================================="
echo "按回车键继续安装..."
read
echo "开始安装..."

# 检查并安装 unzip
if ! command -v unzip &> /dev/null; then
    echo "unzip 未安装，正在安装..."
    apt update
    apt install -y unzip
fi

# 检查并安装 wget
if ! command -v wget &> /dev/null; then
    echo "wget 未安装，正在安装..."
    apt install -y wget
fi

# 检查是否已经下载 Xray，如果没有则下载
if [ ! -f /root/Xray-linux-64.zip ]; then
    echo "Xray-linux-64.zip 文件不存在，开始下载..."
    wget https://github.com/XTLS/Xray-core/releases/download/v1.6.1/Xray-linux-64.zip -P /root/
else
    echo "Xray-linux-64.zip 已存在，跳过下载..."
fi

# 解压文件到 /root/e1 目录
mkdir -p /root/e1
unzip -o /root/Xray-linux-64.zip -d /root/e1

# 修改执行文件路径
chmod +x /root/e1/xray

# 设置防火墙
# 对于 Debian，我们使用 ufw 或 iptables
if command -v ufw &> /dev/null; then
    ufw allow $socks_port/tcp
    ufw allow $socks_port/udp
else
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X
    iptables -A INPUT -p tcp --dport $socks_port -j ACCEPT
    iptables -A INPUT -p udp --dport $socks_port -j ACCEPT
    iptables-save
fi

# 创建 systemd 服务
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=The Xray Proxy Serve
After=network-online.target

[Service]
ExecStart=/root/e1/xray -c /etc/xray/serve.toml
ExecStop=/bin/kill -s QUIT \$MAINPID
Restart=always
RestartSec=15s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray

# Xray 配置
mkdir -p /etc/xray
mkdir -p /home/ubuntu/ip

# 获取公网IP
public_ip=$(curl -s http://checkip.amazonaws.com/ || curl -s https://api.ipify.org)
private_ip=$(hostname -I | awk '{print $1}')

filename="/home/ubuntu/ip/${public_ip}.txt"
echo "$(date '+%Y-%m-%d')" > $filename
echo "公网IP: ${public_ip}:$socks_port:$socks_user:$socks_pass" >> $filename
echo "内网IP: ${private_ip}:$socks_port:$socks_user:$socks_pass" >> $filename

# 创建Xray配置 - 监听所有接口
cat <<EOF > /etc/xray/serve.toml
[[inbounds]]
listen = "0.0.0.0"
port = $socks_port
protocol = "socks"
tag = "socks-in"

[inbounds.settings]
auth = "password"
udp = true

[[inbounds.settings.accounts]]
user = "$socks_user"
pass = "$socks_pass"

[[outbounds]]
protocol = "freedom"
tag = "direct"

[[routing.rules]]
type = "field"
inboundTag = "socks-in"
outboundTag = "direct"
EOF

# 确保防火墙服务存在并启用
if command -v ufw &> /dev/null; then
    ufw allow $socks_port/tcp
    ufw allow $socks_port/udp
    ufw reload
elif command -v firewall-cmd &> /dev/null; then
    systemctl start firewalld
    systemctl enable firewalld
    firewall-cmd --zone=public --add-port=$socks_port/tcp --add-port=$socks_port/udp --permanent
    firewall-cmd --reload
else
    # 使用 iptables
    iptables -A INPUT -p tcp --dport $socks_port -j ACCEPT
    iptables -A INPUT -p udp --dport $socks_port -j ACCEPT
fi

# 启动 Xray
systemctl stop xray
systemctl start xray

# 显示本机所有IP地址
 

# 重启 Xray
systemctl restart xray

# 添加错误检查
if [ ! -f /root/e1/xray ]; then
    echo "错误：xray执行文件不存在，安装失败"
    exit 1
fi

if [ ! -f /etc/xray/serve.toml ]; then
    echo "错误：配置文件不存在，安装失败"
    exit 1
fi

# 设置文件权限，让ubuntu用户可以读取
chown -R ubuntu:ubuntu /home/ubuntu/ip
chmod -R 755 /home/ubuntu/ip

# 显示完成信息
echo "====================================="
echo "  "
echo "==>已安装完毕，赶紧去测试一下!  "
echo "  "
echo "【SOCKS5代理配置信息】"
echo "使用以下公网IP连接:"
cat /home/ubuntu/ip/*.txt
echo "  "
echo "==>配置文件位置: /home/ubuntu/ip/"
echo "  "
echo "====================================="
