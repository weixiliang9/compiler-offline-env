#!/bin/bash
# 补丁部署脚本

set -e

PATCH_FILE="$1"
TARGET_DIR="${2:-/var/lib/offline-packages}"

if [ -z "$PATCH_FILE" ]; then
    echo "用法: $0 <patch-file.tar.gz> [target-directory]"
    exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
    echo "错误: 补丁文件不存在: $PATCH_FILE"
    exit 1
fi

echo "部署补丁: $PATCH_FILE"
echo "目标目录: $TARGET_DIR"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
tar -xzf "$PATCH_FILE" -C "$TEMP_DIR"

# 运行安装脚本
if [ -f "$TEMP_DIR/install-patch.sh" ]; then
    chmod +x "$TEMP_DIR/install-patch.sh"
    "$TEMP_DIR/install-patch.sh" "$TARGET_DIR"
else
    echo "错误: 安装脚本未找到"
    exit 1
fi

# 清理
rm -rf "$TEMP_DIR"

echo "补丁部署完成!"
