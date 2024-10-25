#!/bin/bash
set -e

USER_HOME="/home/$(whoami)"
PROFILE="$USER_HOME/.bash_profile"

# 颜色输出函数
log() {
    echo -e "\033[32m[INFO] $1\033[0m"
}

error() {
    echo -e "\033[31m[ERROR] $1\033[0m"
    exit 1
}

warn() {
    echo -e "\033[33m[WARN] $1\033[0m"
}

set_url() {
    local username
    username=$(whoami)
    read -r -p "是否使用默认的 ${username}.serv00.net 作为 WEBHOOK_URL? [Y/n] " yn
    case $yn in
        [Yy]* | "" ) WEBHOOK_URL="${username}.serv00.net";;
        [Nn]* ) 
            read -r -p "请输入 WEBHOOK_URL: " WEBHOOK_URL
            if [[ ! $WEBHOOK_URL =~ ^https?:// ]]; then
                error "URL 格式错误，必须以 http:// 或 https:// 开头"
            fi
            ;;
    esac
    log "WEBHOOK_URL 设置为: ${WEBHOOK_URL}"
    log "一般使用默认的域名即可，如果使用自己的域名，请确保已正确配置【具体请参考本项目README.md】"
}

set_www() {
    log "重置网站..."
    log "删除网站 ${WEBHOOK_URL}"
    devil www del "${WEBHOOK_URL}"
    ADD_WWW_OUTPUT=$(devil www add "${WEBHOOK_URL}" proxy localhost "$N8N_PORT")
    if echo "$ADD_WWW_OUTPUT" | grep -q "Domain added succesfully"; then
        log "网站 ${WEBHOOK_URL} 成功重置。"
    else
        warn "新建网站失败，可自行在网页端后台进行设置"
    fi
}

set_port() {
    log "当前可用端口列表："
    devil port list
    
    while true; do
        read -r -p "请输入列表中的端口号 或 输入'add'来新增端口: " N8N_PORT
        if [[ $N8N_PORT == "add" ]]; then
            devil port add tcp random
            log "当前可用端口列表："
            devil port list
            read -r -p "请输入新增端口号(必须在列表中): " N8N_PORT
            break
        elif [[ $N8N_PORT =~ ^[0-9]+$ ]] && [ "$N8N_PORT" -ge 1024 ] && [ "$N8N_PORT" -le 65535 ]; then
            if devil port list | grep -q "^$N8N_PORT"; then
                break
            else
                error "端口 $N8N_PORT 不在可用端口列表中"
            fi
        else
            warn "请输入有效的端口号(1024-65535)或'add'"
        fi
    done
    log "N8N_PORT 设置为: ${N8N_PORT}"
}

set_db() {
    log "数据库配置..."
    log "1) PostgreSQL (推荐，支持更多功能)"
    log "2) SQLite (简单，无需配置)"
    
    while true; do
        read -r -p "请选择数据库类型 [1/2]: " db_choice
        case $db_choice in
            1)
                DB_TYPE=postgresdb
                set_postgres
                break
                ;;
            2)
                DB_TYPE=sqlite
                log "已选择 SQLite 数据库"
                break
                ;;
            *)
                warn "请输入 1 或 2"
                ;;
        esac
    done
}

set_postgres() {
    log "配置 PostgreSQL 数据库..."
    
    log "当前数据库列表："
    devil pgsql list
    
    read -r -p "是否使用已有的旧的数据库? [Y/n] " yn
    case $yn in
        [Yy]* | "" ) 
            log "使用已有的旧的数据库"
            warn "请自行修改 $PROFILE 文件中的数据库配置"
            return;;
        [Nn]* ) 
            # 设置数据库名称
            while true; do
                read -r -p "请输入新的数据库名称（仅允许字母、数字和下划线）: " DATABASE_NAME
                if [[ $DATABASE_NAME =~ ^[a-zA-Z0-9_]+$ ]]; then
                    break
                else
                    warn "数据库名称只能包含字母、数字和下划线"
                fi
            done
            ;;
    esac
    
    log "创建数据库: ${DATABASE_NAME}..."
    devil pgsql db del "${DATABASE_NAME}" 2>/dev/null || true
    
    # 提示用户手动输入密码并捕获输出
    log "请在接下来的提示中输入数据库密码: 8位以上要有大小写、数字及特殊字符"
    DB_INFO=$(devil pgsql db add "${DATABASE_NAME}")
    
    # 解析数据库信息（修改这部分以适应实际输出格式）
    DB_Database=$(echo "$DB_INFO" | grep "Database:" | sed 's/^[[:space:]]*Database:[[:space:]]*\(.*\)[[:space:]]*$/\1/')
    DB_HOST=$(echo "$DB_INFO" | grep "Host:" | sed 's/^[[:space:]]*Host:[[:space:]]*\(.*\)[[:space:]]*$/\1/')
    
    # 添加调试输出
    log "数据库创建输出信息："
    echo "$DB_INFO"
    
    if [[ -z "$DB_Database" || -z "$DB_HOST" ]]; then
        # 尝试使用备选方案获取信息
        DB_Database=$(echo "$DB_INFO" | grep -o 'p[0-9]*_[a-zA-Z0-9_]*')
        DB_HOST=$(echo "$DB_INFO" | grep -o 'pgsql[0-9]*\.serv00\.com')
        
        if [[ -z "$DB_Database" || -z "$DB_HOST" ]]; then
            error "无法获取数据库信息，请检查输出并手动设置环境变量"
        fi
    fi
    
    read -r -p "请再输入一次刚才设置的数据库密码，用于N8n连接数据库: " DB_PASSWORD

    log "数据库信息："
    DB_User="${DB_Database}"  # 用户名与数据库名相同
    log "DB_User: ${DB_User}"
    log "DB_Database: ${DB_Database}"
    log "DB_Host: ${DB_HOST}"
    log "DB_Password: 数据库密码"
    
        
    log "配置数据库扩展..."
    for ext in pgcrypto pg_trgm vector timescaledb; do
        devil pgsql extensions "${DB_Database}" "$ext" || warn "扩展 $ext 配置失败"
    done
    
    # 修改数据库连接检查
    if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_User}" -d "${DB_Database}" -c '\q' >/dev/null 2>&1; then
        warn "数据库连接测试失败，请检查数据库配置"
        devil pgsql db list
        exit 1
    fi
    # 清除 PGPASSWORD 环境变量
    unset PGPASSWORD
}

# 更新环境配置
update_profile() {
    # 使用双引号允许变量扩展
    if ! grep -q "^export PATH=.*\.npm-global/bin" "$PROFILE"; then
        echo "export PATH=\"\$HOME/.npm-global/bin:\$HOME/bin:\$PATH\"" >> "$PROFILE"
    fi
    
    # 添加或更新其他环境变量
    cat << EOF >> "$PROFILE"

# N8N 配置
export N8N_PORT=${N8N_PORT}
export WEBHOOK_URL="https://${WEBHOOK_URL}"
export N8N_HOST=0.0.0.0
export N8N_PROTOCOL=https
export GENERIC_TIMEZONE=Asia/Shanghai
# 是否开启 metrics 指标
export N8N_METRICS=false
# 是否开启队列健康检查
export QUEUE_HEALTH_CHECK_ACTIVE=true
# 最大负载
export N8N_PAYLOAD_SIZE_MAX=64
# 数据库类型
export DB_TYPE=${DB_TYPE}
# 数据库地址
export DB_POSTGRESDB_HOST=${DB_HOST}
# 数据库端口
export DB_POSTGRESDB_PORT=5432
# 数据库用户
export DB_POSTGRESDB_USER=${DB_User}
# 数据库密码
export DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
# 数据库名称
export DB_POSTGRESDB_DATABASE=${DB_Database}
# 用户文件夹
export N8N_USER_FOLDER=${USER_HOME}/n8n-serv00/n8n
# 加密密钥
export N8N_ENCRYPTION_KEY="n8n8n8n"
# 允许使用所有内置模块
export NODE_FUNCTION_ALLOW_BUILTIN=*
# 允许使用外部 npm 模块
export NODE_FUNCTION_ALLOW_EXTERNAL=*
EOF
    log "环境变量配置已更新"
}

re_source() {
    # shellcheck source=/dev/null
    if [[ -f "$PROFILE" ]]; then
        source "$PROFILE"
    fi
    # shellcheck source=/dev/null
    if [[ -f "$USER_HOME/.bashrc" ]]; then
        source "$USER_HOME/.bashrc"
    fi
    log "环境变量已重新加载"
}

show_completion_message() {
    log "=== 安装完成 ==="
    log "N8N 已成功安装并启动"
    log "访问地址: ${WEBHOOK_URL}"
    log "端口: ${N8N_PORT}"
    log "数据库类型: ${DB_TYPE}"
    if [[ $DB_TYPE == "postgresdb" ]]; then
        log "数据库名称: ${DB_Database}"
        log "数据库用户: ${DB_User}"
        log "数据库密码: **********"
    fi
    log "配置文件位置: $PROFILE"
    log "日志文件位置: ${USER_HOME}/n8n-serv00/n8n/logs/n8n.log"
    log "退出脚本后，请运行以下命令使环境变量生效："
    warn "source ~/.bash_profile"
    warn "source ~/.bashrc"
    log "详细使用方法请参考本项目 README.md"
}

set_crontab() {
    # 问题：没有检查是否已存在相同的定时任务
    # 建议改进：
    if crontab -l 2>/dev/null | grep -q "i.sh cronjob"; then
        warn "定时任务已存在，跳过设置"
        return 0
    fi
    
    # 添加错误处理
    if ! (crontab -l 2>/dev/null; echo "*/1 * * * * bash $USER_HOME/n8n-serv00/i.sh cronjob") | crontab -; then
        error "设置定时任务失败"
    fi
}

uninstall_old_n8n() {
    # 使用 n8n -v 检查版本, 如果无法获取, 则卸载旧版本, 否则询问是否卸载
    if ! n8n -v > /dev/null 2>&1; then
        bash ./uninstall.sh
    else
        warn "卸载旧版本 n8n、pnpm等本程序安装的相关文件...？"
        read -r -p "是否卸载? [Y/n] " yn
        case $yn in
            [Yy]* | "" ) bash ./uninstall.sh;;
            # 其他情况不卸载
            * ) log "不卸载，继续安装";;
        esac
    fi
}

# 在 main() 函数之前添加创建日志目录的函数
create_log_dir() {
    if [[ ! -d "${USER_HOME}/n8n-serv00/n8n/logs" ]]; then
        mkdir -p "${USER_HOME}/n8n-serv00/n8n/logs"
    fi
}

install_pnpm() {
    mkdir -p "$USER_HOME/.npm-global" "$USER_HOME/bin"
    
    log "配置 npm..."
    npm config set prefix "$USER_HOME/.npm-global"
    ln -fs /usr/local/bin/node20 "$USER_HOME/bin/node"
    ln -fs /usr/local/bin/npm20 "$USER_HOME/bin/npm"
    
    # 使用双引号允许变量扩展
    echo "export PATH=\"\$HOME/.npm-global/bin:\$HOME/bin:\$PATH\"" >> "$PROFILE"
    re_source
    
    log "安装和配置 pnpm..."
    # 清理可能存在的旧安装
    rm -rf "$USER_HOME/.local/share/pnpm"
    rm -rf "$USER_HOME/.npm-global/lib/node_modules/pnpm"
    
    # 使用 npm 安装 pnpm
    npm install -g pnpm || error "pnpm 安装失败"
    
    # 配置 pnpm
    pnpm setup
    
    # 添加 pnpm 环境变量
    if ! grep -q "PNPM_HOME" "$PROFILE"; then
        echo "export PNPM_HOME=\"\$HOME/.local/share/pnpm\"" >> "$PROFILE"
        echo "export PATH=\"\$PNPM_HOME:\$PATH\"" >> "$PROFILE"
    fi
    re_source
}

check_status() {
    if pgrep -f "n8n start" > /dev/null 2>&1; then
        log "n8n 正在运行"
        return 0
    else
        warn "n8n 未在运行"
        return 1
    fi
}

# 添加启动函数
start_n8n() {
    create_log_dir
    # 检查 n8n 是否运行，如果运行就跳过启动，否则启动n8n
    if check_status; then
        return 0
    else
        log "启动 n8n..."
        nohup n8n start >> "${USER_HOME}/n8n-serv00/n8n/logs/n8n.log" 2>&1 &
        sleep 10
        if check_status; then
            log "日志文件位置: ${USER_HOME}/n8n-serv00/n8n/logs/n8n.log"
        else
            error "n8n启动失败，请查看日志文件 ${USER_HOME}/n8n-serv00/n8n/logs/n8n.log"
            cat "${USER_HOME}/n8n-serv00/n8n/logs/n8n.log"
        fi
    fi
}

# 添加停止函数
stop_n8n() {
    log "停止 n8n..."
    if pgrep -f "n8n" > /dev/null; then
        pkill -f "n8n"
        sleep 3
        if pgrep -f "n8n" > /dev/null; then
            error "无法停止 n8n 进程"
        else
            log "n8n 已停止"
        fi
    else
        log "n8n 未在运行"
    fi
}

# 添加重启函数
restart_n8n() {
    stop_n8n
    sleep 2
    start_n8n
}

# 主安装流程 main
main() {
    uninstall_old_n8n
    set_port
    set_url
    set_www
    set_db
    
    log "开始安装 n8n..."
    
    devil binexec on || error "无法设置 binexec"
    re_source
    
    install_pnpm
    
    log "安装 n8n..."
    
    # 设置 pnpm 存储路径
    pnpm config set store-dir "$USER_HOME/.local/share/pnpm/store"
    pnpm config set global-dir "$USER_HOME/.local/share/pnpm/global"
    pnpm config set state-dir "$USER_HOME/.local/share/pnpm/state"
    pnpm config set cache-dir "$USER_HOME/.local/share/pnpm/cache"
    
    # 安装 n8n
    export PNPM_HOME="$USER_HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    
    pnpm install -g n8n || error "n8n 安装失败"
    
    update_profile
    re_source
       
    # 创建日志目录
    create_log_dir
    
    # 检查并停止已存在的 n8n 进程
    if check_status; then
        stop_n8n
    fi
    
    log "启动 n8n..."
    start_n8n
    
    sleep 25
    # 检查 n8n 是否运行，如果运行就输出状态
    if check_status; then
        log "n8n 已成功启动"
        set_crontab
        show_completion_message
    else
        error "n8n 启动失败.请查看 ${USER_HOME}/n8n-serv00/n8n/logs/n8n.log 日志文件"
    fi    
}

# 主程序 cronjob
cronjob() {
    create_log_dir
    # 使用大括号组合多个重定向
    {
        echo "当前时间: $(date)"
        echo "当前用户: $(whoami)"
        echo "当前目录: $(pwd)"
        echo "which pnpm: $(which pnpm)"
        echo "which node: $(which node)"
        echo "which npm: $(which npm)"
        echo "which n8n: $(which n8n)"
        echo "n8n 状态: $(check_status)"
        echo "crontab 状态: $(crontab -l)"
        echo "============"
    } >> "${USER_HOME}/n8n-serv00/n8n/logs/cronjob.log"
    
    # 检查 pnpm 是否安装
    if ! pnpm -v > /dev/null 2>&1; then
        log "pnpm 未安装"
    else
        log "pnpm 已安装"
    fi

    # 检查 n8n 是否安装
    if ! n8n -v > /dev/null 2>&1; then
        log "n8n 未安装"
    else
        log "n8n 已安装"
    fi

    # 检查 n8n 是否运行
    if check_status; then
        log "Happy n8n is running"
    else
        log "再启动一次 n8n"
        start_n8n
        check_status
    fi
    echo "============" >> "${USER_HOME}/n8n-serv00/n8n/logs/cronjob.log"
    echo "当前时间: $(date)" >> "${USER_HOME}/n8n-serv00/n8n/logs/cronjob.log"
    
}

# 在文件开头添加使用说明函数
usage() {
    cat << EOF
使用方法:
    bash i.sh [command]

可用命令:
    install     安装 n8n (默认命令)
    start       启动 n8n
    stop        停止 n8n
    restart     重启 n8n
    status      查看 n8n 状态
    cronjob     设置定时任务
    help        显示此帮助信息

示例:
    bash i.sh              # 执行完整安装
    bash i.sh start        # 启动 n8n
    bash i.sh stop         # 停止 n8n
EOF
}


# 修改主程序入口
case "${1:-install}" in
    install)
        main
        ;;
    start)
        start_n8n
        ;;
    stop)
        stop_n8n
        ;;
    restart)
        restart_n8n
        ;;
    status)
        check_status
        ;;
    cronjob)
        cronjob
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        error "未知命令: $1（使用 --help/-h 查看帮助）"
        ;;
esac
