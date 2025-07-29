#!/bin/bash

set -e

echo "🧹 清理 /etc/sysctl.d/ 中的所有 .conf 文件..."
find /etc/sysctl.d/ -type f -name '*.conf' -exec rm -f {} +
echo "✅ 已清理完毕"

echo "🛠️ 写入新的 TCP 优化配置..."
cat <<EOF >/etc/sysctl.conf
# 优化网络连接队列
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864

# TCP 缓冲区大小
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# 启用 TCP 窗口扩大与 Fast Open
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_fastopen = 3

# TCP 连接关闭优化
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# 启用 BBR 拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

echo "📡 应用新的 sysctl 设置..."
sysctl --system

# 加载 BBR 模块（如未启用）
if ! lsmod | grep -q bbr; then
    echo "📦 加载 tcp_bbr 模块..."
    echo "tcp_bbr" | tee /etc/modules-load.d/bbr.conf
    modprobe tcp_bbr
fi

# 状态检查
echo -e "\n🔍 当前 TCP 网络栈关键参数状态："
echo -n "📦 拥塞控制算法："
sysctl -n net.ipv4.tcp_congestion_control

echo -n "📦 默认队列规则："
sysctl -n net.core.default_qdisc

lsmod | grep bbr || echo "⚠️ 警告：tcp_bbr 模块未加载"

echo -e "\n🎉 TCP 优化完成！"
