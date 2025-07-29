#!/bin/bash

set -e

# 常见且适用于 default_qdisc 的队列规则及备注
declare -A QDISC_REMARKS=(
  [fq]="现代高性能调度器，支持 pacing（推荐）"
  [cake]="智能队列，适合高延迟网络（推荐⭐）"
  [fq_codel]="控制延迟，减缓 bufferbloat 问题"
  [pfifo]="简单的 FIFO 队列"
  [pfifo_fast]="旧默认值，3-band 优先队列"
  [sfq]="老式公平队列"
  [codel]="只控制延迟，不分流"
)

# 检测系统支持的 qdisc 模块
echo "🔍 正在检测当前系统支持的队列规则模块..."
AVAILABLE_QDISCS=()

for qdisc in "${!QDISC_REMARKS[@]}"; do
  if modprobe -n "sch_$qdisc" &>/dev/null || lsmod | grep -q "sch_$qdisc"; then
    AVAILABLE_QDISCS+=("$qdisc")
  fi
done

if [ ${#AVAILABLE_QDISCS[@]} -eq 0 ]; then
  echo "❌ 未检测到支持的默认队列规则模块，请检查内核模块或系统版本。"
  exit 1
fi

echo -e "\n📌 请选择默认队列规则（default_qdisc）："
# 显示选项 + 备注
index=1
declare -a MENU_OPTIONS
for q in "${AVAILABLE_QDISCS[@]}"; do
    printf "%2d) %-10s %s\n" "$index" "$q" "${QDISC_REMARKS[$q]}"
    MENU_OPTIONS+=("$q")
    index=$((index + 1))
done
printf "%2d) quit\n" "$index"
MENU_OPTIONS+=("quit")

# 用户选择
while true; do
    read -rp "#?（直接回车默认选择 cake） " choice
    if [[ -z "$choice" ]]; then
        if [[ " ${AVAILABLE_QDISCS[*]} " == *" cake "* ]]; then
            qdisc="cake"
            echo "✅ 默认选择：cake"
            echo "📘 说明：${QDISC_REMARKS[$qdisc]}"
            break
        else
            echo "⚠️ 系统不支持 cake，不能默认选择，请手动选择"
            continue
        fi
    elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#MENU_OPTIONS[@]})); then
        selected="${MENU_OPTIONS[$((choice - 1))]}"
        if [[ "$selected" == "quit" ]]; then
            echo "❌ 已取消操作"
            exit 0
        else
            qdisc="$selected"
            echo "✅ 已选择队列规则：$qdisc"
            echo "📘 说明：${QDISC_REMARKS[$qdisc]}"
            break
        fi
    else
        echo "⚠️ 无效输入，请输入编号（1-${#MENU_OPTIONS[@]}）"
    fi
done

echo -e "\n🧹 清理 /etc/sysctl.d/ 中的所有 .conf 文件..."
find /etc/sysctl.d/ -type f -name '*.conf' -exec rm -f {} +
echo "✅ 已清理完毕"

echo "🛠️ 写入新的 TCP 优化配置..."
cat <<EOF >/etc/sysctl.conf
# 优化网络连接队列
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864

# TCP 缓冲区大小 - IPv4
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# TCP 缓冲区大小 - IPv6
net.ipv6.tcp_rmem = 4096 87380 67108864
net.ipv6.tcp_wmem = 4096 65536 67108864

# 启用 TCP 窗口扩大与 Fast Open
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_fastopen = 3
net.ipv6.tcp_window_scaling = 1
net.ipv6.tcp_fastopen = 3

# TCP 连接关闭优化
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1

# 启用 BBR 拥塞控制
net.core.default_qdisc = $qdisc
net.ipv4.tcp_congestion_control = bbr
net.ipv6.tcp_congestion_control = bbr
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
# IPv4 拥塞控制算法
if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
    echo -n "📦 拥塞控制算法（IPv4）："
    sysctl -n net.ipv4.tcp_congestion_control
fi

# IPv6 拥塞控制算法（如果系统支持 IPv6）
if [ -f /proc/sys/net/ipv6/tcp_congestion_control ]; then
    echo -n "📦 拥塞控制算法（IPv6）："
    sysctl -n net.ipv6/tcp_congestion_control
fi

if sysctl -n net.core.default_qdisc >/dev/null; then
    echo -n "📦 默认队列规则："
    sysctl -n net.core.default_qdisc
fi

lsmod | grep bbr || echo "⚠️ 警告：tcp_bbr 模块未加载"

echo -e "\n🎉 TCP 双栈优化完成！"
