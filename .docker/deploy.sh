export BUILD_IMG_TAG=1.0.0

sh .docker/check-docker.sh

cp .docker/Dockerfile ./

# 本机网络下 buildx 的 docker-container builder 无法走系统代理访问 auth.docker.io，
# 且默认 builder 不支持 --push 多架构，故改用 Docker Desktop 内置 builder 构建 amd64 单架构后 push。
docker build --platform linux/amd64 -t mythosma/orbit-hop:$BUILD_IMG_TAG .

rm -f Dockerfile

docker push mythosma/orbit-hop:$BUILD_IMG_TAG
