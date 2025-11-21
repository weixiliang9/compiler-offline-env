使用说明

- 初始化环境

```bash
# 克隆仓库
git clone <repository>
cd compiler-offline-env

# 设置执行权限
chmod +x scripts/*.sh
```

- 全量构建

```bash
# 手动触发 GitHub Actions 全量构建
# 或本地测试
./scripts/dependency-analyzer.sh generate base packages/versions/base-versions.json
```

- 增量更新

```bash
# 分析需要更新的包
./scripts/dependency-analyzer.sh python3.10 python-js packages/versions/python-js-versions.json

# 生成补丁包
./scripts/patch-generator.sh python-js v1.0.0 required-packages.txt
```

- 部署环境

```bash
# 部署基础环境
./scripts/deploy-base.sh

# 部署补丁
./scripts/deploy-patch.sh patch-base-20240115.tar.gz
```
