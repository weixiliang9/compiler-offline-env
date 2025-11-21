#!/bin/bash
# 版本检查和清单管理工具

set -e

DOCKER_IMAGE="ubuntu:20.04"

# 生成版本清单
generate_version_manifest() {
    local package_list=$1
    local output_file=$2
    
    echo "生成版本清单: $package_list -> $output_file"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    
    docker run --rm \
        -v "$temp_dir:/workspace" \
        $DOCKER_IMAGE \
        bash -c "
        cd /workspace
        apt-get update > /dev/null 2>&1
        
        echo '{' > manifest.json
        echo '  \"packages\": {' >> manifest.json
        
        first=true
        while read pkg; do
            if [[ \"\$pkg\" =~ ^# ]] || [[ -z \"\$pkg\" ]]; then
                continue
            fi
            
            version=\$(apt-cache show \"\$pkg\" 2>/dev/null | grep '^Version:' | head -1 | cut -d' ' -f2)
            if [[ -n \"\$version\" ]]; then
                if [[ \"\$first\" == \"true\" ]]; then
                    first=false
                else
                    echo ',' >> manifest.json
                fi
                echo -n \"    \\\"\$pkg\\\": \\\"\$version\\\"\" >> manifest.json
            else
                echo \"警告: 包 \$pkg 未找到\" >&2
            fi
        done < /workspace/package_list
        
        echo '' >> manifest.json
        echo '  }' >> manifest.json
        echo '}' >> manifest.json
        " < "$package_list"
    
    # 复制结果
    mkdir -p "$(dirname "$output_file")"
    cp "$temp_dir/manifest.json" "$output_file"
    rm -rf "$temp_dir"
    
    echo "版本清单已生成: $output_file"
}

# 更新版本清单
update_version_manifest() {
    local package_name=$1
    local package_version=$2
    local manifest_file=$3
    
    if [ ! -f "$manifest_file" ]; then
        echo '{"packages":{}}' > "$manifest_file"
    fi
    
    # 使用 jq 更新清单
    jq ".packages.\"$package_name\" = \"$package_version\"" "$manifest_file" > "${manifest_file}.tmp"
    mv "${manifest_file}.tmp" "$manifest_file"
    
    echo "更新清单: $package_name -> $package_version"
}

# 比较两个清单
compare_manifests() {
    local old_manifest=$1
    local new_manifest=$2
    
    if [ ! -f "$old_manifest" ] || [ ! -f "$new_manifest" ]; then
        echo "错误: 清单文件不存在"
        return 1
    fi
    
    echo "比较清单差异:"
    echo "=== 新增的包 ==="
    jq -r '.packages | keys[]' "$new_manifest" | while read pkg; do
        if ! jq -e ".packages.\"$pkg\"" "$old_manifest" > /dev/null 2>/dev/null; then
            version=$(jq -r ".packages.\"$pkg\"" "$new_manifest")
            echo "  + $pkg ($version)"
        fi
    done
    
    echo "=== 更新的包 ==="
    jq -r '.packages | keys[]' "$new_manifest" | while read pkg; do
        if jq -e ".packages.\"$pkg\"" "$old_manifest" > /dev/null 2>/dev/null; then
            old_version=$(jq -r ".packages.\"$pkg\"" "$old_manifest")
            new_version=$(jq -r ".packages.\"$pkg\"" "$new_manifest")
            if [ "$old_version" != "$new_version" ]; then
                echo "  ~ $pkg ($old_version -> $new_version)"
            fi
        fi
    done
    
    echo "=== 删除的包 ==="
    jq -r '.packages | keys[]' "$old_manifest" | while read pkg; do
        if ! jq -e ".packages.\"$pkg\"" "$new_manifest" > /dev/null 2>/dev/null; then
            echo "  - $pkg"
        fi
    done
}

# 主函数
main() {
    local command=$1
    shift
    
    case $command in
        "generate")
            generate_version_manifest "$@"
            ;;
        "update")
            update_version_manifest "$@"
            ;;
        "compare")
            compare_manifests "$@"
            ;;
        *)
            echo "用法: $0 <command>"
            echo "命令:"
            echo "  generate <package_list> <output_manifest>  生成版本清单"
            echo "  update <package> <version> <manifest>      更新版本清单"
            echo "  compare <old_manifest> <new_manifest>      比较清单差异"
            exit 1
            ;;
    esac
}

main "$@"
