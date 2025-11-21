#!/bin/bash
# Android 环境部署脚本

set -e

REPO_DIR="${1:-/opt/offline-repo/android}"
RELEASE_TAG="${2:-latest}"

echo "部署 Android 环境..."
echo "目标目录: $REPO_DIR"
echo "版本: $RELEASE_TAG"

# 创建目录
sudo mkdir -p "$REPO_DIR"
sudo mkdir -p "/opt/android"

# 下载环境包
if [[ $RELEASE_TAG == http* ]]; then
    wget -q "$RELEASE_TAG" -O android-packages.tar.gz
else
    wget -q "https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/android-packages.tar.gz" -O android-packages.tar.gz
fi

# 校验
if [ -f "android-packages.sha256" ]; then
    sha256sum -c android-packages.sha256
fi

# 解压
sudo tar -xzf android-packages.tar.gz -C "$REPO_DIR"

# 设置本地源
sudo tee /etc/apt/sources.list.d/local-android.list > /dev/null << EOF
deb [trusted=yes] file://$REPO_DIR ./
EOF

# 安装 Android 工具
if [ -f "$REPO_DIR/commandlinetools-linux-*.zip" ]; then
    sudo unzip -q "$REPO_DIR/commandlinetools-linux-*.zip" -d "/opt/android"
fi

if [ -f "$REPO_DIR/android-ndk-*.zip" ]; then
    sudo unzip -q "$REPO_DIR/android-ndk-*.zip" -d "/opt/android"
fi

# 更新 apt
sudo apt-get update

echo "Android 环境部署完成!"
