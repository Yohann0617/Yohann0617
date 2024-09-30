#!/bin/bash

clear

# 检查 ~/.bashrc 中是否已存在 yohann 函数定义
if ! grep -qxF 'yohann() { bash <(curl -LsS https://init.19990617.xyz/init.sh); }' ~/.bashrc; then
    echo 'yohann() { bash <(curl -LsS https://init.19990617.xyz/init.sh); }' >> ~/.bashrc
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
    alpine)
        INSTALL_CMD="apk add --no-cache"
        UPDATE_CMD="apk update"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# 备份
backup_directory() {
    $INSTALL_CMD rsync
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
    # 设置ll别名
    set_alias_ll
    # 安装bash-completion
    $INSTALL_CMD bash-completion
    # 判断是否安装了docker
    if command -v docker &> /dev/null; then
        # 刷新docker的bash-completion文件
        source /usr/share/bash-completion/completions/docker
    fi
    # 刷新bash-completion文件
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
        echo -e "${YEW}正在安装 Docker 环境...${NC}"
        
        curl -fsSL https://get.docker.com | bash -s docker
        echo -e "${GRN}Docker 安装成功！${NC}"
    else
        echo -e "${GRN}Docker 环境已经安装${NC}"
    fi
    
    if ! command -v docker-compose &>/dev/null; then
        echo -e "${YEW}正在安装 Docker Compose...${NC}"
        
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo -e "${GRN}Docker Compose 安装成功！${NC}"
    else
        echo -e "${GRN}Docker Compose 已经安装${NC}"
    fi
}

docker_relate(){
    clear
    while true; do
        echo -e "${CYN}请选择一个docker操作：${NC}"
        echo "==========================================================="
        echo -e "${WHT}1)  安装docker和docker-compose${NC}"
        echo -e "${WHT}2)  docker部署甲骨文保活工具(lookbusy)${NC}"
        echo -e "${WHT}3)  docker部署或更新小雅影音库${NC}"
        echo "==========================================================="
        echo -e "${YEW}0)  返回${NC}"
        echo "==========================================================="
        read -p "请输入选项 (例: 1):" choice

        case $choice in
            1)
                install_docker
                break
                ;;
            2)
                echo "正在安装甲骨文保活工具(lookbusy)..."
                install_oci_alive
                break
                ;;
            3)
                echo "正在部署或更新小雅影音库..."
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/monlor/docker-xiaoya/main/install.sh)"
                break
                ;;
            0)
                clear
                source <(curl -LsS https://init.19990617.xyz/init.sh)
                break
                ;;
            *)
                clear
                echo -e "${RED}无效的选项，请输入对应的数字${NC}"
                ;;
        esac
    done
}

# 检查规则是否已经存在
rule_exists() {
    local chain=$1
    local rule=$2
    iptables -C $chain $rule 2>/dev/null
}

# 放行ICMP协议
enable_icmp() {
    clear
    echo -e "${YEW}正在开启系统的ICMP协议...${NC}"
    # 允许ICMP回显请求（ping），如果规则不存在
    if ! rule_exists INPUT "-p icmp --icmp-type echo-request -j ACCEPT"; then
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    fi
    # 允许ICMP回显应答， 如果规则不存在
    if ! rule_exists OUTPUT "-p icmp --icmp-type echo-reply -j ACCEPT"; then
        iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
    fi
    # 限制ICMP请求速率为每秒1个，最多允许突发5个，如果规则不存在
    if ! rule_exists INPUT "-p icmp --icmp-type echo-request -m limit --limit 1/sec --limit-burst 5 -j ACCEPT"; then
        iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/sec --limit-burst 5 -j ACCEPT
    fi
    # 丢弃超过速率限制的ICMP请求，如果规则不存在
    if ! rule_exists INPUT "-p icmp --icmp-type echo-request -j DROP"; then
        iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    fi
    echo -e "${GRN}系统的ICMP协议已启用${NC}"
    iptables -L -v -n --line-numbers
}

# 关闭ICMP协议
disable_icmp() {
    clear
    echo -e "${YEW}正在禁用系统的ICMP协议...${NC}"
    # 删除允许ICMP的规则（如果存在）
    if rule_exists INPUT "-p icmp --icmp-type echo-request -j ACCEPT"; then
        iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT
    fi
    if rule_exists OUTPUT "-p icmp --icmp-type echo-reply -j ACCEPT"; then
        iptables -D OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
    fi
    if rule_exists INPUT "-p icmp --icmp-type echo-request -m limit --limit 1/sec --limit-burst 5 -j ACCEPT"; then
        iptables -D INPUT -p icmp --icmp-type echo-request -m limit --limit 1/sec --limit-burst 5 -j ACCEPT
    fi
    if rule_exists INPUT "-p icmp --icmp-type echo-request -j DROP"; then
        iptables -D INPUT -p icmp --icmp-type echo-request -j DROP
    fi
    echo -e "${GRN}系统的ICMP协议已禁用${NC}"
    iptables -L -v -n --line-numbers
}

# ll
set_alias_ll(){
    # 设置别名 ll 为 ls -l
    alias ll='ls -l'

    # 将别名添加到 ~/.bashrc 中，以便在每次启动终端时自动加载
    if ! grep -q "alias ll='ls -l'" ~/.bashrc; then
        echo "alias ll='ls -l'" >> ~/.bashrc
    fi

    # 刷新当前shell环境，使别名立即生效
    source ~/.bashrc
}

check(){
    clear
    while true; do
        echo -e "${CYN}请选择一个测试脚本：${NC}"
        echo "==========================================================="
        echo -e "${WHT}1)  bench.sh测速${NC}"
        echo -e "${WHT}2)  taier.sh大陆三网指定V4/V6测速(可指定网卡)⭐${NC}"
        echo -e "${WHT}3)  IP解锁测试⭐${NC}"
        echo -e "${WHT}4)  测试机器能否开设LXC容器${NC}"
        echo "==========================================================="
        echo -e "${YEW}0)  返回${NC}"
        echo "==========================================================="
        read -p "请输入选项 (例: 1):" choice

        case $choice in
            1)
                wget -qO- bench.sh | bash
                break
                ;;
            2)
                # 提示用户输入附加参数
                read -p "请输入指定网卡 (可选，例: --interface eth0)，如不需要直接回车跳过: " params
                bash <(curl -sL res.yserver.ink/taier.sh) $params
                break
                ;;
            3)
                bash <(curl -L -s https://raw.githubusercontent.com/1-stream/RegionRestrictionCheck/main/check.sh)
                break
                ;;
            4)
                clear
                bash <(wget -qO- --no-check-certificate https://raw.githubusercontent.com/oneclickvirt/lxd/main/scripts/pre_check.sh)
                break
                ;;
            0)
                source <(curl -LsS https://init.19990617.xyz/init.sh)
                break
                ;;
            *)
                clear
                echo -e "${RED}无效的选项，请输入对应的数字${NC}"
                ;;
        esac
    done
}

# 一键搭建节点
one_click_node(){
    clear
    while true; do
        echo -e "${CYN}请选择一个一键搭建脚本：${NC}"
        echo "==========================================================="
        echo -e "${WHT}1)  FranzKafkaYu修改版X-UI一键脚本⭐${NC}"
        echo -e "${WHT}2)  ygkkk四合一singbox节点搭建一键脚本${NC}"
        echo -e "${WHT}3)  fscarmen节点搭建一键脚本${NC}"
        echo -e "${WHT}4)  baipiao节点搭建一键脚本${NC}"
        echo "==========================================================="
        echo -e "${WHT}5)  Multi-EasyGost中转一键脚本⭐${NC}"
        echo "==========================================================="
        echo -e "${YEW}0)  返回${NC}"
        echo "==========================================================="
        read -p "请输入选项 (例: 1):" choice

        case $choice in
            1)
                clear
                bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh)
                break
                ;;
            2)
                clear
                bash <(curl -Ls https://gitlab.com/rwkgyg/sing-box-yg/raw/main/sb.sh)
                break
                ;;
            3)
                clear
                bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
                break
                ;;
            4)
                clear
                bash <(wget -qO- https://www.baipiao.eu.org/suoha.sh)
                break
                ;;
            5)
                clear
                bash <(wget -qO- https://raw.githubusercontent.com/KANIKIG/Multi-EasyGost/master/gost.sh)
                break
                ;;
            0)
                source <(curl -LsS https://init.19990617.xyz/init.sh)
                break
                ;;
            *)
                clear
                echo -e "${RED}无效的选项，请输入对应的数字${NC}"
                ;;
        esac
    done
}

# 定义颜色
BLK='\033[0;30m'
RED='\033[0;31m'
GRN='\033[0;32m'
YEW='\033[0;33m'
BLU='\033[0;34m'
PUP='\033[0;35m'
CYN='\033[0;36m'
WHT='\033[0;37m'
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
- 系统推荐Debian、Ubuntu、Centos，其他系统暂未测试
- 部分工具安装完之后需 重新打开终端 才生效哦~
EOF
)

while true; do
    # 打印banner
    echo -e "${GRN}$banner${NC}"
    echo -e "${WHT}${NC}"
    echo -e "${CYN}请选择一个操作：${NC}"
    echo "==========================================================="
    echo -e "${GRN}1)  下载并运行 kejilion.sh⭐⭐\t\t${WHT}6)  备份指定目录${NC}"
    echo -e "${YEW}2)  下载并运行 XrayR 安装脚本⭐\t\t${WHT}7)  上传文件到个人网盘(tgNetDisc)${NC}"
    echo -e "${WHT}3)  测速/解锁测试⭐${NC}"
    echo -e "${WHT}4)  安装Tab命令补全工具⭐⭐${NC}"
    echo -e "${WHT}5)  设置定时日志清理任务⭐⭐${NC}"
    echo "==========================================================="
    echo -e "${WHT}8)  Docker相关${NC}"
    echo "==========================================================="
    echo -e "${WHT}9)  iptables放行ICMP协议(允许ping)${NC}"
    echo -e "${WHT}10) iptables关闭ICMP协议(不允许ping)${NC}"
    echo "==========================================================="
    echo -e "${WHT}11) 节点搭建/中转一键脚本${NC}"
    echo "==========================================================="
    echo -e "${PUP}00) 卸载此脚本${NC}"
    echo -e "${RED}0)  退出${NC}"
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
            check
            break
            ;;
        4)
            echo "正在安装Tab命令补全工具(bash-completion)..."
            install_tab
            break
            ;;
        5)
            echo "正在设置定时日志清理任务..."
            log_clean
            echo "定时日志清理任务设置成功！"
            break
            ;;
        6)
            backup_directory
            break
            ;;
        7)
            upload_file
            break
            ;;
        8)
            docker_relate
            break
            ;;
        9)
            enable_icmp
            break
            ;;
        10)
            disable_icmp
            break
            ;;
        11)
            one_click_node
            break
            ;;
        00)
            echo "正在卸载此脚本..."
            sed -i '/yohann() { bash <(curl -LsS https:\/\/init.19990617.xyz\/init.sh); }/d' ~/.bashrc
            sed -i '/source ~\/.bashrc/d' "$PROFILE_FILE"
            source ~/.bashrc
            source "$PROFILE_FILE"
            clear
            echo -e "${GRN}脚本已成功卸载，请勿再执行 yohann 命令，重新打开终端即可${NC}"
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
