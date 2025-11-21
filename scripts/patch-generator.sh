#!/bin/bash
# 补丁包生成工具

set -e

DOCKER_IMAGE="ubuntu:20.04"

# 下载指定的包
download_packages() {
    local package_file=$1
    local output_dir=$2
    
    echo "下载包到: $output_dir"
    mkdir -p "$output_dir"
    
    # 提取包列表
    local packages=$(cut -d: -f1 "$package_file" | sort -u)
    
    docker run --rm \
        -v "$(pwd):/workspace" \
        -w "/workspace" \
        $DOCKER_IMAGE \
        bash -c "
        cd '$output_dir'
        apt-get update
        
        # 下载包
        for pkg in $packages; do
            echo \"下载: \$pkg\"
            apt-get download \"\$pkg\" || echo \"下载失败: \$pkg\"
        done
        "
    
    echo "下载完成: $(ls "$output_dir" | wc -l) 个包"
}

# 生成补丁元数据
generate_patch_metadata() {
    local package_file=$1
    local output_dir=$2
    local environment=$3
    local base_release=$4
    
    local metadata_file="$output_dir/patch-metadata.json"
    
    # 收集包信息
    echo "生成补丁元数据..."
    
    cat > "$metadata_file" << EOF
{
    "patch_info": {
        "environment": "$environment",
        "base_release": "$base_release",
        "generated_date": "$(date -Iseconds)",
        "package_count": $(wc -l < "$package_file")
    },
    "packages": {
EOF
    
    # 添加包信息
    local first=true
    while IFS=: read pkg version; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$metadata_file"
        fi
        echo "        \"$pkg\": \"$version\"" >> "$metadata_file"
    done < "$package_file"
    
    cat >> "$metadata_file" << EOF
    }
}
EOF
    
    echo "补丁元数据已生成: $metadata_file"
}

# 创建补丁包
create_patch_package() {
    local environment=$1
    local base_release=$2
    local package_file=$3
    local output_dir=$4
    
    local patch_name="patch-${environment}-$(date +%Y%m%d-%H%M%S)"
    local temp_dir=$(mktemp -d)
    
    echo "创建补丁包: $patch_name"
    
    # 下载包
    download_packages "$package_file" "$temp_dir/packages"
    
    # 生成元数据
    generate_patch_metadata "$package_file" "$temp_dir" "$environment" "$base_release"
    
    # 复制包文件列表
    cp "$package_file" "$temp_dir/package-list.txt"
    
    # 创建安装脚本
    cat > "$temp_dir/install-patch.sh" << 'EOF'
#!/bin/bash
# 补丁安装脚本

set -e

PATCH_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_DIR="${1:-/var/lib/offline-packages}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "错误: 目标目录不存在: $TARGET_DIR"
    echo "请指定正确的离线包目录"
    exit 1
fi

echo "安装补丁到: $TARGET_DIR"

# 复制包文件
if [ -d "$PATCH_DIR/packages" ]; then
    cp -v "$PATCH_DIR/packages"/*.deb "$TARGET_DIR/" 2>/dev/null || true
    echo "包文件复制完成"
fi

# 更新包索引
if command -v dpkg-scanpackages > /dev/null; then
    cd "$TARGET_DIR"
    dpkg-scanpackages . /dev/null > Packages 2>/dev/null || true
    gzip -k -f Packages 2>/dev/null || true
    echo "包索引更新完成"
else
    echo "警告: 无法更新包索引，请手动运行: dpkg-scanpackages . /dev/null > Packages"
fi

echo "补丁安装完成"
EOF
    
    chmod +x "$temp_dir/install-patch.sh"
    
    # 创建压缩包
    mkdir -p "$output_dir"
    tar -czf "$output_dir/$patch_name.tar.gz" -C "$temp_dir" .
    
    # 生成校验和
    cd "$output_dir"
    sha256sum "$patch_name.tar.gz" > "$patch_name.sha256"
    
    # 清理
    rm -rf "$temp_dir"
    
    echo "补丁包创建完成: $output_dir/$patch_name.tar.gz"
    echo "校验和: $(cat "$output_dir/$patch_name.sha256")"
}

# 主函数
main() {
    if [ $# -lt 3 ]; then
        echo "用法: $0 <environment> <base_release> <package_file> [output_dir]"
        echo "环境: base, python-js, android"
        exit 1
    fi
    
    local environment=$1
    local base_release=$2
    local package_file=$3
    local output_dir=${4:-"patch-packages"}
    
    if [ ! -f "$package_file" ]; then
        echo "错误: 包文件不存在: $package_file"
        exit 1
    fi
    
    create_patch_package "$environment" "$base_release" "$package_file" "$output_dir"
}

main "$@"
