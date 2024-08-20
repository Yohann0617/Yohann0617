#!/bin/bash

clear

# 检查 ~/.bashrc 中是否已存在 yohann 函数定义
if ! grep -qxF 'yohann() { bash <(curl -LsS https://blog.jvm.us.kg/init.sh); }' ~/.bashrc; then
    echo 'yohann() { bash <(curl -LsS https://blog.jvm.us.kg/init.sh); }' >> ~/.bashrc
    source ~/.bashrc
fi

# 默认配置文件是 ~/.profile
PROFILE_FILE=~/.profile

# centos等系统
os_files=(
    "/etc/centos-release"
    "/etc/redhat-release"
    "/etc/kylin-release"
)

# 遍历数组，检查系统是否为支持的发行版
for os_file in "${os_files[@]}"; do
    if [ -f "$os_file" ]; then
        # 如果找到匹配的发行版文件，使用 ~/.bash_profile
        PROFILE_FILE=~/.bash_profile
        break
    fi
done

# 检查 PROFILE_FILE 是否存在，不存在则创建
if [ ! -f "$PROFILE_FILE" ]; then
    touch "$PROFILE_FILE"
fi

# 检查 PROFILE_FILE 是否已包含 source ~/.bashrc
if ! grep -qxF 'source ~/.bashrc' "$PROFILE_FILE"; then
    echo 'source ~/.bashrc' >> "$PROFILE_FILE"
    source "$PROFILE_FILE"
fi

# Detect the OS type
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
elif [ -f /etc/debian_version ]; then
    OS=debian
elif [ -f /etc/redhat-release ]; then
    OS=centos
else
    OS=$(uname -s)
fi

# Define the install command based on the OS type
case "$OS" in
    ubuntu|debian)
        INSTALL_CMD="apt-get install -y"
        UPDATE_CMD="apt-get update"
        ;;
    centos|rhel|fedora)
        INSTALL_CMD="yum install -y"
        UPDATE_CMD="yum update"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

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

# 上传文件
upload_file() {
    clear

    echo "tgNetDisc项目地址：https://github.com/Yohann0617/tgNetDisc"

    # 提示用户输入文件的名称
    read -p "请输入文件的名称（包括路径）: " tar_filename

    # 提示用户输入API URL
    read -p "请输入API URL: " api_url

    # 提示用户输入cookie参数
    read -p "请输入密码，如未设置按回车跳过（例如：p=123456）: " cookie

    # 执行curl命令并将响应保存到变量response中
    response=$(curl -X POST -F "image=@$tar_filename;type=application/octet-stream" -b "$cookie" "$api_url")

    # 提取返回的JSON中的code值
    code=$(echo $response | grep -o '"code":[0-9]*' | grep -o '[0-9]*')

    # 判断上传是否成功
    if [ "$code" -eq 1 ]; then
        url=$(echo $response | grep -o '"url":"[^"]*' | grep -o 'http[^"]*')
        echo "上传成功！文件可通过以下链接访问：$url"
    else
        message=$(echo $response | grep -o '"message":"[^"]*' | grep -o ':[^"]*' | cut -c 2-)
        echo "上传失败！错误信息：$message"
    fi
}

# tab补全
install_tab(){
    clear
    # 安装bash-complete
    $INSTALL_CMD bash-completion
    install_docker
    # 刷新文件
    source /usr/share/bash-completion/completions/docker
    # 刷新文件
    source /usr/share/bash-completion/bash_completion
}

# oce保活
install_oci_alive(){
    clear
    install_docker
    # Check if the container 'lookbusy' exists
    if [ "$(docker ps -a -q -f name=lookbusy)" ]; then
        echo "Container 'lookbusy' already exists. Removing it..."
        docker rm -f lookbusy
    fi

    read -p "请输入CPU占用百分比(例：10-20): " CPU_UTIL
    read -p "请输入内存占用百分比(例：15): " MEM_UTIL
    docker run -itd --name=lookbusy --restart=always \
    -e TZ=Asia/Shanghai \
    -e CPU_UTIL=$CPU_UTIL \
    -e MEM_UTIL=$MEM_UTIL \
    -e SPEEDTEST_INTERVAL=120 \
    fogforest/lookbusy
}

# 定时日志清理
log_clean(){
    clear
    install_docker
    mkdir -p /root/shell
    echo '#!/bin/bash
    cd /var/log
    find . -type f -name "*20[0-9][0-9]*" -exec rm {} \;
    find . -type f \( -name ".*[0-9]" -o -name "*.gz" \) -exec rm {} \;
    find . -type f -exec truncate -s 0 {} \;
    echo "✔✔✔ /var/log 目录下日志已清空✔✔✔"
    echo "==================== start clean docker containers logs =========================="
    logs=$(find /var/lib/docker/containers/ -name *-json.log)
    for log in $logs
    do
        echo "clean logs : $log"
        cat /dev/null > $log
    done
    echo "==================== end clean docker containers logs   =========================="' > /root/shell/clean_log.sh
    
    chmod +x /root/shell/clean_log.sh
    echo "0 0 * * * /root/shell/clean_log.sh" > /root/shell/cron.conf
    crontab /root/shell/cron.conf && crontab -l
}

# 安装docker & docker-compose
install_docker() {
    if ! command -v docker &>/dev/null; then
        clear
        echo -e "${YELLOW}正在安装 Docker 环境...${NC}"
        
        curl -fsSL https://get.docker.com | bash -s docker
        echo -e "${GREEN}Docker 安装成功！${NC}"
    else
        echo -e "${GREEN}Docker 环境已经安装${NC}"
    fi
    
    if ! command -v docker-compose &>/dev/null; then
        echo -e "${YELLOW}正在安装 Docker Compose...${NC}"
        
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose 安装成功！${NC}"
    else
        echo -e "${GREEN}Docker Compose 已经安装${NC}"
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
                
- 系统初始化快捷脚本，输入 yohann 可快速启动此脚本
- 部分工具安装完之后需 重新打开终端 才生效哦~
EOF
)

while true; do
    # 打印banner
    echo -e "${GREEN}$banner${NC}"
    echo -e "${WHITE}${NC}"
    echo -e "${CYAN}请选择一个操作：${NC}"
    echo "==========================================================="
    echo -e "${GREEN}1)\t下载并运行 kejilion.sh${NC}"
    echo -e "${YELLOW}2)\t下载并运行 XrayR 安装脚本${NC}"
    echo -e "${WHITE}3)\t测速(bench.sh)${NC}"
    echo -e "${WHITE}4)\t部署或更新小雅影音库${NC}"
    echo -e "${WHITE}5)\t备份指定目录${NC}"
    echo -e "${WHITE}6)\t上传文件到个人网盘(tgNetDisc)${NC}"
    echo -e "${WHITE}7)\t安装Tab命令补全工具(bash-completion)${NC}"
    echo -e "${WHITE}8)\tdocker安装甲骨文保活工具(lookbusy)${NC}"
    echo -e "${WHITE}9)\t设置定时日志清理任务${NC}"
    echo -e "${WHITE}10)\t安装docker和docker-compose${NC}"
    echo -e "${PURPLE}00)\t卸载此脚本${NC}"
    echo -e "${RED}0)\t退出${NC}"
    echo "==========================================================="
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
        6)
            upload_file
            break
            ;;
        7)
            echo "正在安装Tab命令补全工具(bash-completion)..."
            install_tab
            break
            ;;
        8)
            echo "正在安装甲骨文保活工具(lookbusy)..."
            install_oci_alive
            break
            ;;
        9)
            echo "正在设置定时日志清理任务..."
            log_clean
            echo "定时日志清理任务设置成功！"
            break
            ;;
        10)
            install_docker
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
