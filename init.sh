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

# 备份
backup_directory() {
    clear
    # 提示用户输入需要备份的目录
    read -p "请输入需要备份的目录: " source_dir

    # 检查输入的目录是否存在
    if [ ! -d "$source_dir" ]; then
        echo "目录不存在，请检查输入并重试。"
        return 1
    fi

    # 设置默认备份目录
    backup_folder="/root/backup"
    # 如果备份目录不存在，则创建它
    if [ ! -d "$backup_folder" ]; then
        mkdir -p "$backup_folder"
    fi

    # 获取当前日期和时间以用于备份文件名
    timestamp=$(date +"%Y%m%d%H%M%S")
    # 获取目录名称
    dir_name=$(basename "$source_dir")
    # 设置临时同步目录路径
    temp_sync_dir="$backup_folder/${dir_name}_sync_$timestamp"
    # 设置备份文件路径
    backup_file="$backup_folder/${dir_name}_backup_$timestamp.tar.gz"

    # 使用rsync进行同步
    rsync -a --info=progress2 "$source_dir/" "$temp_sync_dir/"

    # 检查rsync命令是否成功
    if [ $? -eq 0 ]; then
        # 创建tar包并包含目录的文件夹
        tar -czvf "$backup_file" -C "$backup_folder" "${dir_name}_sync_$timestamp" > /dev/null

        # 删除临时同步目录
        rm -rf "$temp_sync_dir"

        if [ $? -eq 0 ]; then
            echo "备份成功，文件已保存为：$backup_file"
        else
            echo "打包失败，请检查错误信息。"
        fi
    else
        echo "备份失败，请检查错误信息。"
    fi
}

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

# 使用cat命令和重定向定义多行字符串
banner=$(cat << 'EOF'
 __     __          _                             
 \ \   / /         | |                            
  \ \_/ /    ___   | |__     __ _   _ __    _ __  
   \   /    / _ \  | '_ \   / _` | | '_ \  | '_ \ 
    | |    | (_) | | | | | | (_| | | | | | | | | |
    |_|     \___/  |_| |_|  \__,_| |_| |_| |_| |_|

                © 2024 Yohann. All Rights Reserved
                
- 系统初始化快捷脚本，输入 yohann 可快速启动此脚本 -
EOF
)

while true; do
    # 打印banner
    echo -e "${GREEN}$banner${NC}"
    echo -e "${WHITE}${NC}"
    echo -e "${CYAN}请选择一个操作：${NC}"
    echo "===================================================="
    echo -e "${GREEN}1) 下载并运行 kejilion.sh${NC}"
    echo -e "${YELLOW}2) 下载并运行 XrayR 安装脚本${NC}"
    echo -e "${WHITE}3) 测速(bench.sh)${NC}"
    echo -e "${WHITE}4) 部署或更新小雅影音库${NC}"
    echo -e "${WHITE}5) 备份指定目录${NC}"
    echo -e "${PURPLE}00) 卸载此脚本${NC}"
    echo -e "${RED}0) 退出${NC}"
    echo "===================================================="
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
        5)
            backup_directory
            break
            ;;
        00)
            echo "正在卸载此脚本..."
            sed -i '/yohann() { bash <(curl -LsS https:\/\/blog.jvm.us.kg\/init.sh); }/d' ~/.bashrc
            sed -i '/source ~\/.bashrc/d' "$PROFILE_FILE"
            source ~/.bashrc
            source "$PROFILE_FILE"
            clear
            echo -e "${GREEN}脚本已成功卸载，请勿再执行 yohann 命令，重新打开终端即可${NC}"
            break
            ;;
        0)
            echo -e "${RED}退出${NC}"
            clear
            exit 0
            ;;
        *)
            clear
            echo -e "${RED}无效的选项，请输入对应的数字${NC}"
            ;;
    esac
done
