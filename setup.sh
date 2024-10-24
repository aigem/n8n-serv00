#!/bin/bash

# 设置错误处理
set -euo pipefail

# 设置项目（可不修改）用户输入项目名称，不输入则默认为app
read -p "根据你的喜好，输入项目名称(英文)（回车默认为app）: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-app} # 项目名称=项目文件夹名称

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 设置项目（不要修改）
USER_HOME="/usr/home/$(whoami)" # serv00用户目录
CONFIG_FILE="$USER_HOME/base/$(whoami).yaml" # 项目配置文件
BASH_PROFILE="$USER_HOME/.bash_profile"
devil binexec on # 系统必要设置为ON

# 函数：打印彩色信息
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 创建必要的目录
mkdir -p "$USER_HOME/base" "$USER_HOME/$PROJECT_NAME"
# 复制 相关 文件
if [ ! -f "reboot_run.sh" ] || [ ! -d "sample_app" ]; then
    print_color $RED "错误: 必要的文件或目录不存在。请确保您在正确的目录中运行此脚本。"
    exit 1
fi

cp reboot_run.sh "$USER_HOME/base/reboot_run.sh"
chmod +x "$USER_HOME/base/reboot_run.sh"
cp sample_app/app.py "$USER_HOME/$PROJECT_NAME/app.py"
cp sample_app/requirements.txt "$USER_HOME/$PROJECT_NAME/requirements.txt"

# 端口设置
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
print_color $BLUE "【设置 $PROJECT_NAME 端口】你的端口号为: "
devil port list

while true; do
    read -p "请输入上面的端口号，如果没有端口请输入【add】来开通一个新的端口号 (最多不超3个): " user_input
    if [[ "$user_input" == "add" ]]; then
        devil port add tcp random
        print_color $GREEN "端口开通成功 "
        devil port list
        read -p "请输入刚才生成的端口号: " app_PORT
        if ! [[ "$app_PORT" =~ ^[0-9]+$ ]] || [ "$app_PORT" -lt 1024 ] || [ "$app_PORT" -gt 65535 ]; then
            print_color $RED "无效的端口号。请输入 1024-65535 之间的数字。"
        fi
        break
    elif [[ "$user_input" =~ ^[0-9]+$ && "$user_input" -ge 1024 && "$user_input" -le 65535 ]]; then
        app_PORT="$user_input"
        break
    else
        print_color $RED "无效的输入。请输入有效的端口号 (1024-65535) 或 'add'新增端口。"
    fi
done

# 网站绑定
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
print_color $BLUE "现需要绑定网站并指向 $app_PORT"
print_color $RED "警告：这将会重置网站（删除该网站所有内容）！"
echo "输入 'yes' 来重置网站 ($(whoami).serv00.net)"
echo "或输入自定义域名,必须A记录解析到本机IP"
read -p "或输入 'no' 退出绑定，之后可自行在网页端后台进行设置: " user_input

case "$user_input" in
    yes)
        print_color $GREEN "开始重置网站..."
        devil www del "$(whoami).serv00.net" &> /dev/null
        ADD_WWW_OUTPUT=$(devil www add "$(whoami).serv00.net" proxy localhost "$app_PORT")
        if echo "$ADD_WWW_OUTPUT" | grep -q "Domain added succesfully"; then
            print_color $GREEN "网站 $(whoami).serv00.net 成功重置。"
            MY_SITE="$(whoami).serv00.net"
        else
            print_color $RED "新建网站失败，之后自行在网页端后台进行设置"
            MY_SITE=""
        fi
        ;;
    no)
        print_color $BLUE "跳过网站设置。之后可自行在网页端后台进行设置。"
        MY_SITE=""
        ;;
    *)
        custom_domain="$user_input"
        devil www del "$custom_domain"
        ADD_WWW_OUTPUT=$(devil www add "$custom_domain" proxy localhost "$app_PORT")
        if echo "$ADD_WWW_OUTPUT" | grep -q "Domain added succesfully"; then
            print_color $GREEN "网站 $custom_domain 成功绑定。"
            MY_SITE="$custom_domain"
        else
            print_color $RED "绑定网站失败，域名是否解析到本机IP。你之后可自行在网页端后台进行设置"
            MY_SITE=""
        fi
        ;;
esac

# 更新 .bash_profile
if [ -f "$BASH_PROFILE" ]; then
    sed -i.bak '/export PATH=".*\/node_modules\/pm2\/bin:$PATH"/d' "$BASH_PROFILE"
    sed -i.bak '/export CFLAGS="-I\/usr\/local\/include"/d' "$BASH_PROFILE"
    sed -i.bak '/export CXXFLAGS="-I\/usr\/local\/include"/d' "$BASH_PROFILE"
    sed -i.bak '/export PATH="$USER_HOME\/$PROJECT_NAME\/venv_$PROJECT_NAME\/bin:$PATH"/d' "$BASH_PROFILE"
fi

echo "export PATH=\"$USER_HOME/node_modules/pm2/bin:\$PATH\"" >> "$BASH_PROFILE"
echo "export PYTHON_VIRTUAL_ENV=\"$USER_HOME/${PROJECT_NAME}/venv_${PROJECT_NAME}\"" >> "$BASH_PROFILE"
echo "export PATH=\"$USER_HOME/${PROJECT_NAME}/venv_${PROJECT_NAME}/bin:\$PATH\"" >> "$BASH_PROFILE"
echo "export CFLAGS=\"-I/usr/local/include\"" >> "$BASH_PROFILE"
echo "export CXXFLAGS=\"-I/usr/local/include\"" >> "$BASH_PROFILE"

source "$BASH_PROFILE"

cd "$USER_HOME"

# 安装 PM2
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
if [ ! -f "$USER_HOME/node_modules/pm2/bin/pm2" ]; then
    print_color $GREEN "正在安装 PM2..."
    npm install pm2
else
    print_color $GREEN "PM2 已安装。"
fi

# 安装示例应用
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
print_color $GREEN "安装示例项目 $PROJECT_NAME "
print_color $BLUE "这里以 Flask 为例，文件将放在 $USER_HOME/$PROJECT_NAME/ 文件夹下 "
cp "$USER_HOME/serv00_base/sample_app/app.py" "$USER_HOME/$PROJECT_NAME/app.py"

VIRTUAL_ENV_PATH="$USER_HOME/$PROJECT_NAME/venv_$PROJECT_NAME"

# 创建虚拟环境
print_color $GREEN "正在创建虚拟环境..."
if ! command -v virtualenv &> /dev/null; then
    print_color $RED "错误: virtualenv 未安装。请先安装 virtualenv。"
    exit 1
fi

virtualenv "$VIRTUAL_ENV_PATH"
source "$VIRTUAL_ENV_PATH/bin/activate"

#检查是否进入虚拟环境，进入后会显示虚拟环境路径
if [ -z "$VIRTUAL_ENV" ]; then
    print_color $RED "未进入虚拟环境，请手动进入虚拟环境"
    exit 1
fi

print_color $GREEN "已进入虚拟环境: $VIRTUAL_ENV"

# 安装 Flask
print_color $GREEN "正在安装 Python 依赖..."
pip install -r "$USER_HOME/$PROJECT_NAME/requirements.txt"

# 使用 PM2 启动应用(启动python项目与nodejs项目命令不同的)
print_color $GREEN "使用 PM2 启动应用..."
pm2 start "$USER_HOME/$PROJECT_NAME/app.py" --name "$PROJECT_NAME" --interpreter "$VIRTUAL_ENV/bin/python" -- --port "$app_PORT"

# 检查应用是否启动成功
if pm2 list | grep -q "$PROJECT_NAME"; then
    print_color $GREEN "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    print_color $GREEN "$PROJECT_NAME 已成功启动。"
else
    print_color $RED "$PROJECT_NAME 启动失败，请检查配置。"
    exit 1
fi

# 保存 PM2 状态
pm2 save

# 设置重启后的自动 reboot_run.sh
PM2_PATH=$(which pm2 | tr -d '\n')
# crontab中没有运行reboot_run.sh的才添加，有了就不添加了
if ! crontab -l | grep -q "@reboot $USER_HOME/base/reboot_run.sh"; then
    (crontab -l 2>/dev/null; echo "@reboot $USER_HOME/base/reboot_run.sh") | crontab -
fi

if ! crontab -l | grep -q "0 \*/* \* \* \* $USER_HOME/base/reboot_run.sh"; then
    (crontab -l 2>/dev/null; echo "0 */3 * * * $USER_HOME/base/reboot_run.sh") | crontab -
fi

if [ -z "$MY_SITE" ]; then
    print_color $RED "错误: 网站未成功绑定。请检查之前的步骤。"
    MY_SITE="未绑定,重新安装或自己在网页端后台进行设置"
fi

# 生成配置文件
cat <<EOF > "$CONFIG_FILE"
project_name: $PROJECT_NAME
address: 0.0.0.0
port: $app_PORT
serv00_user: $(whoami)
serv00_domain: $(whoami).serv00.net
user_home: $USER_HOME
base_profile: $BASH_PROFILE
pm2_path: $PM2_PATH
your_website: $MY_SITE
python_virtualenv: $VIRTUAL_ENV_PATH
EOF

# 清理旧的 index.html 文件
rm -f "$USER_HOME/domains/$(whoami).serv00.net/public_html/index.html"
rm -f "$USER_HOME/domains/$MY_SITE/public_html/index.html"

# 生成 info.html 文件
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
chmod +x $USER_HOME/serv00_base/make_info.sh
print_color $GREEN "生成 info.html 文件..."
bash $USER_HOME/serv00_base/make_info.sh

# 提示安装完成
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
print_color $GREEN "$PROJECT_NAME 当前服务运行在端口: $app_PORT"
pm2 list
print_color $RED "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
print_color $GREEN "安装全部完成! Happy 白嫖! 请从【 http://$MY_SITE 】开始"
print_color $YELLOW "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
print_color $RED "=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

# 返回项目目录
cd "$USER_HOME/$PROJECT_NAME"