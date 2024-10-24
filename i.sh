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

# 清理函数
cleanup() {
    log "清理可能的残留文件..."
    rm -rf "$USER_HOME/.local/share/pnpm/global/5/node_modules"
    rm -rf "$USER_HOME/.local/share/pnpm/global/5/.pnpm"
    rm -rf "$USER_HOME/.local/share/pnpm/store"
    rm -rf "$USER_HOME/.npm-global/lib/node_modules/pnpm"
}

trap cleanup ERR

set_url() {
    local username=$(whoami)
    # 设置 WEBHOOK_URL
    read -p "是否使用默认的 ${username}.serv00.net 作为 WEBHOOK_URL? [Y/n] " yn
    case $yn in
        [Yy]* | "" ) WEBHOOK_URL="${username}.serv00.net";;
        [Nn]* ) 
            read -p "请输入 WEBHOOK_URL: " WEBHOOK_URL
            # 验证URL格式
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
    # 设置 N8N_PORT
    log "当前可用端口列表："
    devil port list
    
    while true; do
        read -p "请输入列表中的端口号 或 输入'add'来新增端口: " N8N_PORT
        if [[ $N8N_PORT == "add" ]]; then
            devil port add tcp random
            read -p "请输入新增端口号: " N8N_PORT
            break
        elif [[ $N8N_PORT =~ ^[0-9]+$ ]] && [ $N8N_PORT -ge 1024 ] && [ $N8N_PORT -le 65535 ]; then
            # 检查端口是否已被占用
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
        read -p "请选择数据库类型 [1/2]: " db_choice
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
    
    # 设置数据库名称
    while true; do
        read -p "请输入新的数据库名称（仅允许字母、数字和下划线）: " DATABASE_NAME
        if [[ $DATABASE_NAME =~ ^[a-zA-Z0-9_]+$ ]]; then
            break
        else
            warn "数据库名称只能包含字母、数字和下划线"
        fi
    done
    
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
    
    read -p "请再输入一次刚才设置的数据库密码，用于N8n连接数据库: " DB_PASSWORD

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
    
    # 验证数据库连接
    # 临时设置 PGPASSWORD 环境变量
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_User}" -d "${DB_Database}" -c '\q' >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        warn "数据库连接测试失败，请检查数据库配置"
        devil pgsql db list
        exit 1
    else
        log "数据库连接测试成功"
    fi
    # 清除 PGPASSWORD 环境变量
    unset PGPASSWORD
}

# 更新环境配置
update_profile() {
    # 添加或更新 PATH
    if ! grep -q "^export PATH=.*\.npm-global/bin" "$PROFILE"; then
        echo 'export PATH="$USER_HOME/.npm-global/bin:~/bin:$PATH"' >> "$PROFILE"
    fi
    
    # 添加或更新其他环境变量
    cat << EOF >> "$PROFILE"

# N8N 配置
export N8N_PORT=${N8N_PORT}
export WEBHOOK_URL=${WEBHOOK_URL}
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
export DB_POSTGRESDB_USER=${POSTGRES_USER}
# 数据库密码
export DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
# 数据库名称
export DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
# 用户文件夹
export N8N_USER_FOLDER=${USER_HOME}/n8n
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
    if [[ -f "$PROFILE" ]]; then
        source "$PROFILE"
    fi
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
        log "数据库名称: ${POSTGRES_DB}"
        log "数据库用户: ${POSTGRES_USER}"
        log "数据库密码: ${POSTGRES_PASSWORD}"
    fi
    log "配置文件位置: $PROFILE"
    log "请保存好以上信息"
}

set_cronjob() {
    log "设置定时任务..."
    cp reboot_run.sh "$USER_HOME/reboot_run.sh"
    chmod +x "$USER_HOME/reboot_run.sh"
    devil cron add "n8n" "$USER_HOME/reboot_run.sh" "*/3 * * * *"
    log "定时任务设置完成"
}

# 主安装流程
main() {

    set_port
    set_url
    set_www
    set_db
    
    log "开始安装 n8n..."
    
    devil binexec on || error "无法设置 binexec"
    re_source
    
    mkdir -p "$USER_HOME/.npm-global" "$USER_HOME/bin"
    
    log "配置 npm..."
    npm config set prefix "$USER_HOME/.npm-global"
    ln -fs /usr/local/bin/node20 "$USER_HOME/bin/node"
    ln -fs /usr/local/bin/npm20 "$USER_HOME/bin/npm"
    
    # 确保 PATH 正确设置
    echo 'export PATH="$HOME/.npm-global/bin:$HOME/bin:$PATH"' >> "$PROFILE"
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
        echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> "$PROFILE"
        echo 'export PATH="$PNPM_HOME:$PATH"' >> "$PROFILE"
    fi
    
    re_source
    
    log "安装 n8n..."
    # 清理可能存在的旧虚拟存储
    rm -rf "$USER_HOME/.local/share/pnpm/global/5/node_modules"
    rm -rf "$USER_HOME/.local/share/pnpm/global/5/.pnpm"
    
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
    
    show_completion_message
    
    log "启动 n8n..."
    n8n start
}

# 执行主程序
bash ./uninstall.sh
main

