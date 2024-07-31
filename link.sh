#!/bin/bash

# 检查 ~/.bashrc 中是否已存在 yohann 函数定义
grep -qxF 'yohann() { bash <(curl -LsS https://blog.jvm.us.kg/init.sh); }' ~/.bashrc || echo 'yohann() { bash <(curl -LsS https://blog.jvm.us.kg/init.sh); }' >> ~/.bashrc

# 使更改生效
source ~/.bashrc

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
grep -qxF 'source ~/.bashrc' "$PROFILE_FILE" || echo 'source ~/.bashrc' >> "$PROFILE_FILE"

# 使更改生效
source "$PROFILE_FILE"
