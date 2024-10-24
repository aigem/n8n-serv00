# N8N 自动安装脚本

这是一个用于在 serv00.net 环境下自动安装和配置 N8N 的脚本工具。

## 功能特点

- 自动安装和配置 N8N
- 支持 PostgreSQL 和 SQLite 数据库
- 自动配置域名和端口
- 自动设置环境变量
- 包含定时任务配置
- 提供完整的卸载功能

## 系统要求

- serv00.net FreeBSD 环境
- Node.js 20.x (已预装)
- npm 10.x (已预装)
- PostgreSQL (已预装，推荐使用)

## 注意事项

1. 本脚本设计用于 serv00.net 的 FreeBSD 环境
2. 不需要 root 权限
3. 使用 devil 命令管理服务
4. 数据库密码需要手动输入（建议使用：N8n8n8n）

## 快速开始

1. 克隆仓库：

mkdir ~/.npm-global
npm config set prefix '~/.npm-global' 
echo 'export PATH=~/.npm-global/bin:~/bin:$PATH ' >> $HOME/.bash_profile && source $HOME/.bash_profile
mkdir -p ~/bin && ln -fs /usr/local/bin/node20 ~/bin/node && ln -fs /usr/local/bin/npm20 ~/bin/npm && source $HOME/.bash_profile

npm install -g pnpm
pnpm setup
source ~/.bashrc
source $HOME/.bash_profile

pnpm install -g n8n
pnpm add -g sqlite3

## 故障排除

### pnpm 虚拟存储错误

如果遇到 "ERR_PNPM_UNEXPECTED_VIRTUAL_STORE" 错误，请尝试：

1. 清理 pnpm 相关目录：

## 数据库配置说明

在配置数据库时：

1. 密码要求：
   - 至少8位
   - 包含大小写字母
   - 包含数字
   - 包含特殊字符

2. 数据库信息：
   - 数据库名称会自动生成，格式为：p{用户ID}_{自定义名称}
   - 数据库主机一般为：pgsql12.serv00.com
   - 用户名与数据库名称相同
   - 请务必保存好设置的密码
