#!/bin/bash
# 依赖分析和版本冲突检测工具

set -e

UBUNTU_VERSION="20.04"
DOCKER_IMAGE="ubuntu:20.04"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 获取包版本
get_package_version() {
    local package=$1
    docker run --rm $DOCKER_IMAGE bash -c "apt-get update > /dev/null 2>&1 && apt-cache show $package 2>/dev/null | grep '^Version:' | head -1 | cut -d' ' -f2" || echo ""
}

# 获取包依赖
get_package_dependencies() {
    local package=$1
    docker run --rm $DOCKER_IMAGE bash -c "apt-get update > /dev/null 2>&1 && apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $package 2>/dev/null | grep '^\w' | sort -u" || echo ""
}

# 比较版本
compare_versions() {
    local pkg=$1
    local old_version=$2
    local new_version=$3
    
    if [ -z "$old_version" ]; then
        echo "new"
        return 0
    fi
    
    if [ "$old_version" = "$new_version" ]; then
        echo "same"
        return 0
    fi
    
    # 使用 dpkg 比较版本
    local result
    result=$(docker run --rm $DOCKER_IMAGE bash -c "dpkg --compare-versions '$new_version' gt '$old_version' && echo 'newer' || echo 'older'") || echo "unknown"
    echo "$result"
}

# 递归分析依赖
analyze_dependencies() {
    local package=$1
    local base_manifest=$2
    local environment=$3
    local depth=$4
    local processed_packages=$5
    
    # 深度限制
    if [ $depth -gt 10 ]; then
        warn "依赖深度超过限制: $package"
        return
    fi
    
    # 检查是否已处理
    if echo "$processed_packages" | grep -q "^$package$"; then
        return
    fi
    processed_packages="$processed_packages"$'\n'"$package"
    
    local new_version=$(get_package_version "$package")
    if [ -z "$new_version" ]; then
        error "包不存在: $package"
        return
    fi
    
    # 检查基础版本
    local base_version=""
    if [ -f "$base_manifest" ]; then
        base_version=$(jq -r ".packages.\"$package\"" "$base_manifest" 2>/dev/null || echo "")
    fi
    
    local version_comparison=$(compare_versions "$package" "$base_version" "$new_version")
    
    case $version_comparison in
        "new")
            info "新增包: $package ($new_version)"
            echo "$package:$new_version"
            ;;
        "newer")
            info "更新包: $package ($base_version -> $new_version)"
            echo "$package:$new_version"
            ;;
        "same"|"older")
            # 版本相同或更旧，不需要处理
            return
            ;;
        "unknown")
            warn "版本比较失败: $package ($base_version vs $new_version)"
            echo "$package:$new_version"
            ;;
    esac
    
    # 递归分析依赖
    local dependencies=$(get_package_dependencies "$package")
    for dep in $dependencies; do
        local dep_result=$(analyze_dependencies "$dep" "$base_manifest" "$environment" $((depth + 1)) "$processed_packages")
        if [ -n "$dep_result" ]; then
            echo "$dep_result"
        fi
    done
}

# 主函数
main() {
    if [ $# -lt 3 ]; then
        echo "用法: $0 <package> <environment> <base_manifest> [output_file]"
        echo "环境: base, python-js, android"
        exit 1
    fi
    
    local package=$1
    local environment=$2
    local base_manifest=$3
    local output_file=${4:-"required-packages.txt"}
    
    log "开始分析包: $package"
    log "目标环境: $environment"
    log "基础清单: $base_manifest"
    
    # 检查基础清单是否存在
    if [ ! -f "$base_manifest" ]; then
        warn "基础清单不存在，将创建新清单"
        mkdir -p "$(dirname "$base_manifest")"
        echo '{"packages":{}}' > "$base_manifest"
    fi
    
    # 分析依赖
    local required_packages
    required_packages=$(analyze_dependencies "$package" "$base_manifest" "$environment" 0 "")
    
    # 去重和排序
    required_packages=$(echo "$required_packages" | sort -u)
    
    # 保存结果
    echo "$required_packages" > "$output_file"
    
    local package_count=$(echo "$required_packages" | grep -c . || echo 0)
    log "分析完成，需要 $package_count 个包"
    log "结果保存到: $output_file"
    
    # 显示结果
    if [ $package_count -gt 0 ]; then
        info "需要下载的包:"
        echo "$required_packages" | while IFS=: read pkg version; do
            echo "  - $pkg ($version)"
        done
    else
        warn "没有需要下载的包"
    fi
}

main "$@"
