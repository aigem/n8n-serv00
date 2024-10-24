#!/bin/bash

# 获取用户名
USERNAME=$(whoami)

# 定义配置文件路径
CONFIG_FILE="/usr/home/$USERNAME/base/$USERNAME.yaml"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：配置文件不存在。"
    exit 1
fi

# 使用 grep 和 awk 读取配置文件内容
APP_PORT=$(grep "port:" "$CONFIG_FILE" | awk '{print $2}')
WEBSITE_NAME=$(grep "your_website:" "$CONFIG_FILE" | awk '{print $2}')
PROJECT_NAME=$(grep "project_name:" "$CONFIG_FILE" | awk '{print $2}')
VIRTUAL_ENV=$(grep "python_virtualenv:" "$CONFIG_FILE" | awk '{print $2}')

# 在生成 HTML 内容前添加检查
if [ -z "$APP_PORT" ] || [ -z "$WEBSITE_NAME" ] || [ -z "$PROJECT_NAME" ]; then
    echo "错误：无法从配置文件中读取所需信息。"
    exit 1
fi

# 生成 HTML 内容
cat << EOF > /usr/home/$USERNAME/domains/$WEBSITE_NAME/public_html/info.html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>部署信息</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: #fff;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1, h2 {
            color: #333;
        }
        .highlight {
            background-color: #ffe6e6;
            padding: 2px 5px;
            border-radius: 3px;
        }
        code, pre {
            background-color: #f8f8f8;
            border: 1px solid #ddd;
            border-radius: 3px;
            padding: 2px 5px;
            font-family: 'Courier New', Courier, monospace;
        }
        pre {
            padding: 10px;
            overflow-x: auto;
        }
        ul, ol {
            padding-left: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>部署成功！</h1>
        <h3>返回应用 <a href="/">主页</a> | 访问<a href="https://github.com/aigem/serv00_base">Github</a></h3>
        <p>您的应用已成功部署。以下是关键配置信息：</p>
        <ul>
            <li>项目名称：<span class="highlight">$PROJECT_NAME</span></li>
        </ul>
        
        <h2>注意事项</h2>
        <ul>
            <li>请将您的程序文件放置在目录：<span class="highlight">/usr/home/$USERNAME/$PROJECT_NAME</span> 下。</li>
            <li>使用 <code>pm2</code> 命令来启动您的程序，例如：
                <pre>pm2 start your_app.js --name $PROJECT_NAME --port $APP_PORT</pre>
                <pre>pm2 start "/usr/home/$USERNAME/$PROJECT_NAME/app.py" --name "$PROJECT_NAME" --interpreter "$VIRTUAL_ENV/bin/python" -- --port "$APP_PORT"</pre>
                <p>请将 app.py / your_app.js 替换为您的实际启动程序文件名。</p>
            </li>
            <li>您的后台程序运行的端口号为：<span class="highlight">$APP_PORT</span></li>
            <li>PM2运行程序成功后，访问程序域名为：<span class="highlight">$WEBSITE_NAME</span></li>
        </ul>
        
        <h2>下一步部署自己的程序</h2>
        <ol>
            <li>将可在nodejs、python、rust、go、java等语言编写的程序放在 <code>/usr/home/$USERNAME/$PROJECT_NAME</code> 下</li>
            <li>使用 pm2 命令启动您的程序</li>
            <li>运行的端口必须为 $APP_PORT</li>
            <li>访问 $WEBSITE_NAME 查看您的应用</li>
            <li>具体查看 <a href="https://github.com/aigem/serv00_base">Github</a></li>
        </ol>
        
        <h2>常用命令</h2>
        <ul>
            <li>查看应用日志：<code>pm2 logs $PROJECT_NAME</code></li>
            <li>重启应用：<code>pm2 restart $PROJECT_NAME</code></li>
            <li>停止应用：<code>pm2 stop $PROJECT_NAME</code></li>
            <li>查看应用状态：<code>pm2 status</code></li>
            <li>查看所有应用：<code>pm2 list</code></li>
        </ul>
        
        <h2>更多信息</h2>
        <p>查看详细信息，请访问我的: <a href="https://github.com/aigem/serv00_base">Github</a></p>
    </div>
</body>
</html>
EOF

# 检查/usr/home/$USERNAME/domains/$WEBSITE_NAME/public_html/info.html是否存在
if [ -f "/usr/home/$USERNAME/domains/$WEBSITE_NAME/public_html/info.html" ]; then
    echo "info.html 文件已成功生成。"
else
    echo "info.html 文件生成失败。"
fi
