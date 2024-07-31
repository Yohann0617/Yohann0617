#!/bin/bash

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

echo -e "${CYAN}请选择一个操作：${NC}"
echo -e "${GREEN}1) 下载并运行 kejilion.sh${NC}"
echo -e "${YELLOW}2) 下载并运行 XrayR 安装脚本${NC}"
echo -e "${RED}0) 退出${NC}"

read -p "请输入选项 (例: 1):" choice

case $choice in
    1)
        echo "正在下载并运行 kejilion.sh..."
        curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
        ;;
    2)
        echo "正在下载并运行 XrayR-release 安装脚本..."
        bash <(curl -Ls https://raw.githubusercontent.com/Yohann0617/XrayR-release/master/install.sh)
        ;;
    0)
        echo -e "${RED}退出${NC}"
        exit 0
        ;;
    *)
        echo -e "${YELLOW}无效的选项，请输入 0, 1 或 2${NC}"
        ;;
esac
