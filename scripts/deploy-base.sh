#!/bin/bash
# 基础环境部署脚本

set -e

REPO_DIR="${1:-/opt/offline-repo/base}"
RELEASE_TAG="${2:-latest}"

echo "部署基础环境..."
echo "目标目录: $REPO_DIR"
echo "版本: $RELEASE_TAG"

# 创建目录
sudo mkdir -p "$REPO_DIR"

# 下载基础环境包
if [[ $RELEASE_TAG == http* ]]; then
    # 从 URL 下载
    wget -q "$RELEASE_TAG" -O base-packages.tar.gz
else
    # 从 GitHub Release 下载
    wget -q "https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/base-packages.tar.gz" -O base-packages.tar.gz
fi

# 校验
if [ -f "base-packages.sha256" ]; then
    sha256sum -c base-packages.sha256
fi

# 解压
sudo tar -xzf base-packages.tar.gz -C "$REPO_DIR"

# 设置本地源
sudo tee /etc/apt/sources.list.d/local-base.list > /dev/null << EOF
deb [trusted=yes] file://$REPO_DIR ./
EOF

# 更新 apt
sudo apt-get update

echo "基础环境部署完成!"
echo "可以使用: sudo apt-get install <package> 安装包"
