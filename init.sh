#!/bin/bash

clear

# 检查 ~/.bashrc 中是否已存在 yohann 函数定义
if ! grep -qxF 'yohann() { bash <(curl -LsS https://blog.jvm.us.kg/init.sh); }' ~/.bashrc; then
    echo 'yohann() { bash <(curl -LsS https://blog.jvm.us.kg/init.sh); }' >> ~/.bashrc
    source ~/.bashrc
fi

# 默认配置文件是 ~/.profile
PROFILE_FILE=~/.profile

# 检查系统是否是 CentOS
if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
    # 如果是 CentOS，使用 ~/.bash_profile
    PROFILE_FILE=~/.bash_profile
fi

# 检查 PROFILE_FILE 是否存在，不存在则创建
if [ ! -f "$PROFILE_FILE" ]; then
    touch "$PROFILE_FILE"
fi

# 检查 PROFILE_FILE 是否已包含 source ~/.bashrc
if ! grep -qxF 'source ~/.bashrc' "$PROFILE_FILE"; then
    echo 'source ~/.bashrc' >> "$PROFILE_FILE"
    source "$PROFILE_FILE"
fi

# 定义颜色
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 没有颜色

while true; do
    echo -e "${CYAN}请选择一个操作：${NC}"
    echo -e "${GREEN}1) 下载并运行 kejilion.sh${NC}"
    echo -e "${YELLOW}2) 下载并运行 XrayR 安装脚本${NC}"
    echo -e "${WHITE}3) 测速(bench.sh)${NC}"
    echo -e "${WHITE}4) 部署或更新小雅影音库${NC}"
    echo -e "${RED}0) 退出${NC}"

    read -p "请输入选项 (例: 1):" choice

    case $choice in
        1)
            echo "正在下载并运行 kejilion.sh..."
            curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
            break
            ;;
        2)
            echo "正在下载并运行 XrayR-release 安装脚本..."
            bash <(curl -Ls https://raw.githubusercontent.com/Yohann0617/XrayR-release/master/install.sh)
            break
            ;;
        3)
            wget -qO- bench.sh | bash
            break
            ;;
        4)
            echo "正在部署或更新小雅影音库..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/monlor/docker-xiaoya/main/install.sh)"
            break
            ;;
        0)
            echo -e "${RED}退出${NC}"
            exit 0
            clear
            ;;
        *)
            echo -e "${YELLOW}无效的选项，请输入有效数字${NC}"
            ;;
    esac
done
