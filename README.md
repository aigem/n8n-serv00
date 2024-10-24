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

### 常见问题

1. 端口占用问题：
   - 如果提示端口已被占用，脚本会自动尝试使用其他端口
   - 也可以手动终止已运行的 n8n 进程：`pkill -f "n8n"`

2. 手动启动/停止 n8n：
   ```bash
   # 停止 n8n
   pkill -f "n8n"
   
   # 启动 n8n
   n8n start
   ```
