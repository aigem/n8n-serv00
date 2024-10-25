# N8N 自动安装脚本

这是一个用于在 serv00 免费主机上自动安装和配置 N8N 的脚本工具。

【[视频教程](https://www.bilibili.com/video/BV1PZy2YdErb/)】【[一键在Huggingface上使用N8N](https://www.bilibili.com/video/BV1e6sVeEEhR/)】

## 功能特点

- 自动安装和配置 N8N
- 支持 PostgreSQL 和 SQLite 数据库
- 自动配置域名和端口
- 自动设置环境变量
- 包含定时任务配置
- 提供完整的卸载功能
- 一键脚本完成全流程，无需后台操作

![n8n](https://raw.githubusercontent.com/aigem/n8n-serv00/refs/heads/main/%E4%B8%80%E9%94%AE%E5%85%8D%E8%B4%B9%E9%83%A8%E7%BD%B2%E8%87%AA%E5%8A%A8%E5%8C%96%E5%B7%A5%E4%BD%9C%E6%B5%81%E7%A5%9E%E5%99%A8N8N%20%E5%9C%A8%E5%8D%81%E5%B9%B4%E5%85%8D%E8%B4%B9%E4%B8%BB%E6%9C%BA%E4%B8%8A%E8%87%AA%E5%8A%A8%E9%83%A8%E7%BD%B2%E6%95%99%E7%A8%8B%20N8N%2Bserv00-%E5%B0%81%E9%9D%A2.jpg)

## 系统要求

- serv00 免费主机

## 快速开始

1. 进入serv00免费主机的命令行操作：
```bash
ssh 用户名@s13.serv00.com
``` 

2. 一键命令：克隆仓库并运行安装脚本：
```bash
git clone https://github.com/aigem/n8n-serv00.git && cd n8n-serv00 && bash i.sh
```



## 注意事项

### 在配置数据库时：

密码要求：
- 至少8位
- 包含大小写字母
- 包含数字
- 包含特殊字符

## 安装后配置

安装完成后，退出脚本后，需要运行以下命令使环境变量生效：

```bash
source ~/.bash_profile
source ~/.bashrc
```

然后验证安装：

```bash
pnpm --version  # 应该显示 pnpm 版本
n8n --version   # 应该显示 n8n 版本
```

## 安装后使用方法:
```bash
    bash i.sh [command]
```
```
可用命令:
    install     安装 n8n (默认命令)
    start       启动 n8n
    stop        停止 n8n
    restart     重启 n8n
    status      查看 n8n 状态
    cronjob     设置定时任务
    help        显示此帮助信息
```
示例:
```bash
    bash i.sh              # 执行完整安装
    bash i.sh start        # 启动 n8n
    bash i.sh stop         # 停止 n8n
```