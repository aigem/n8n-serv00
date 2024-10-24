#!/bin/bash

# 系统重启后运行本脚本。

# 获取当前时间并格式化
timestamp1=$(date +"%Y-%m-%d %H:%M:%S")

# 将时间戳写入新的一行到 reboot_log.txt
echo "开始：$timestamp1" >> reboot_log.txt

# 定义用户目录
USER_HOME="/usr/home/$(whoami)"
BASH_PROFILE="$USER_HOME/.bash_profile"
CONFIG_FILE="$USER_HOME/base/$(whoami).yaml"
WEBHOOK_URL=""

# 使用 grep 和 awk 读取配置文件内容
APP_PORT=$(grep "port:" "$CONFIG_FILE" | awk '{print $2}')
PROJECT_NAME=$(grep "project_name:" "$CONFIG_FILE" | awk '{print $2}')
PYTHON_VIRTUALENV=$(grep "python_virtualenv:" "$CONFIG_FILE" | awk '{print $2}')

# 添加新的环境变量条目到 .bash_profile
if ! grep -q 'export PATH="$USER_HOME/node_modules/pm2/bin:$PATH"' "$BASH_PROFILE"; then
    echo "export PATH=\"$USER_HOME/node_modules/pm2/bin:\$PATH\"" >> "$BASH_PROFILE"
fi

if ! grep -q 'export CFLAGS="-I/usr/local/include"' "$BASH_PROFILE"; then
    echo 'export CFLAGS="-I/usr/local/include"' >> "$BASH_PROFILE"
fi

if ! grep -q 'export CXXFLAGS="-I/usr/local/include"' "$BASH_PROFILE"; then
    echo 'export CXXFLAGS="-I/usr/local/include"' >> "$BASH_PROFILE"
fi

# 重新加载 .bash_profile
source "$BASH_PROFILE"

# 激活虚拟环境,先检查是否存在。如果不存在则创建并安装requirements.txt中的依赖。
if [ -d "$PYTHON_VIRTUALENV" ]; then
    source "$PYTHON_VIRTUALENV/bin/activate"
else
    echo "虚拟环境不存在，正在创建..."
    virtualenv "$PYTHON_VIRTUALENV"
    source "$PYTHON_VIRTUALENV/bin/activate"
    pip install -r "$USER_HOME/$PROJECT_NAME/requirements.txt"
fi

# 安装 pm2
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
    if [ $? -ne 0 ]; then
        echo "PM2安装失败，请检查npm是否正确安装"
        exit 1
    fi
fi

# 重启 pm2
pm2 resurrect

sleep 5

# resurrect后检查指定项目是否启动
if ! pm2 list | grep -q "$PROJECT_NAME"; then
    echo "项目 $PROJECT_NAME 未启动，正在尝试启动..."
    pm2 restart all

    # 检查是否启动成功
    if [ $? -ne 0 ]; then
        echo "项目启动失败，请检查配置和代码"
        # 向webhook发送通知
        curl -X POST -H "Content-Type: application/json" -d '{"text": "项目启动失败，请检查配置和代码"}' $WEBHOOK_URL
        exit 1
    fi
fi

# 一段时间后检查项目是否仍然运行
sleep 10

# 如果项目仍然没有启动，则尝试运行通知流程
if ! pm2 list | grep -q "$PROJECT_NAME"; then
    # 这里需要根据实际情况修改通知命令  
    echo "警告：$PROJECT_NAME 未能成功启动"
fi

# 获取当前时间并格式化
timestamp2=$(date +"%Y-%m-%d %H:%M:%S")

# 将时间戳写入新的一行到 reboot_log.txt
echo "结束：$timestamp2" >> reboot_log.txt