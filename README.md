# N8N 自动安装脚本

这是一个用于在 serv00 免费主机上自动安装和配置 N8N 的脚本工具。

【[视频教程](https://www.bilibili.com/video/BV1e6sVeEEhR/)】【[一键在Huggingface上使用N8N](https://www.bilibili.com/video/BV1e6sVeEEhR/)】

## 功能特点

- 自动安装和配置 N8N
- 支持 PostgreSQL 和 SQLite 数据库
- 自动配置域名和端口
- 自动设置环境变量
- 包含定时任务配置
- 提供完整的卸载功能
- 一键脚本完成全流程，无需后台操作

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
