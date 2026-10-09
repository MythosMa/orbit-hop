# 使用官方 Node.js 镜像作为基础镜像
FROM --platform=linux/amd64 node:alpine

# 创建工作目录
WORKDIR /app

# 复制 必须文件
COPY build/web ./build

# 安装项目依赖（node:alpine 不带 yarn，本项目仅需 npm；淘宝旧源已失效，改用 npmmirror）
RUN npm config set registry https://registry.npmmirror.com

RUN npm install -g serve

# 暴露端口
EXPOSE 3000

# 启动实例
CMD [ "serve", "-s", "build" ]
