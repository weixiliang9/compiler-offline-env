#!/bin/bash
# Python/JS 环境部署脚本

set -e

REPO_DIR="${1:-/opt/offline-repo/python-js}"
RELEASE_TAG="${2:-latest}"

echo "部署 Python/JS 环境..."
echo "目标目录: $REPO_DIR"
echo "版本: $RELEASE_TAG"

# 创建目录
sudo mkdir -p "$REPO_DIR"

# 下载环境包
if [[ $RELEASE_TAG == http* ]]; then
    wget -q "$RELEASE_TAG" -O python-js-packages.tar.gz
else
    wget -q "https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/python-js-packages.tar.gz" -O python-js-packages.tar.gz
fi

# 校验
if [ -f "python-js-packages.sha256" ]; then
    sha256sum -c python-js-packages.sha256
fi

# 解压
sudo tar -xzf python-js-packages.tar.gz -C "$REPO_DIR"

# 设置本地源
sudo tee /etc/apt/sources.list.d/local-python-js.list > /dev/null << EOF
deb [trusted=yes] file://$REPO_DIR ./
EOF

# 更新 apt
sudo apt-get update

echo "Python/JS 环境部署完成!"
