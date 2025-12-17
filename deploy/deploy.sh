#!/bin/bash
# =============================================================================
# 自动化部署脚本 - 个人静态博客
# 功能：Git拉取 → 构建 → 备份 → 原子化部署 → 失败回滚
# 用法：./deploy.sh [--force]
# =============================================================================

set -e  # 遇到错误立即退出

# =============================================================================
# 配置区域 - 根据实际情况修改
# =============================================================================
REPO_URL="git@github.com:your-username/your-blog.git"  # Git 仓库地址
BRANCH="main"                                           # 部署分支
DEPLOY_DIR="/var/www/blog"                              # 部署目录
BACKUP_DIR="/var/www/blog-backups"                      # 备份目录
MAX_BACKUPS=5                                           # 最大保留备份数
WEBHOOK_URL=""                                          # 可选：部署通知 Webhook

# =============================================================================
# 颜色输出
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# 发送通知（可选）
# =============================================================================
send_notification() {
    local status=$1
    local message=$2
    
    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"$status\", \"message\": \"$message\", \"timestamp\": \"$(date -Iseconds)\"}" \
            > /dev/null 2>&1 || true
    fi
}

# =============================================================================
# 清理旧备份
# =============================================================================
cleanup_old_backups() {
    log_info "清理旧备份..."
    cd "$BACKUP_DIR"
    ls -t | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -rf
    log_info "保留最近 $MAX_BACKUPS 个备份"
}

# =============================================================================
# 回滚函数
# =============================================================================
rollback() {
    log_error "部署失败，正在回滚..."
    
    # 查找最新的备份
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" 2>/dev/null | head -1)
    
    if [ -n "$LATEST_BACKUP" ] && [ -d "$BACKUP_DIR/$LATEST_BACKUP" ]; then
        rm -rf "$DEPLOY_DIR/dist"
        cp -r "$BACKUP_DIR/$LATEST_BACKUP" "$DEPLOY_DIR/dist"
        log_info "已回滚到备份: $LATEST_BACKUP"
        send_notification "rollback" "部署失败，已回滚到 $LATEST_BACKUP"
    else
        log_error "没有可用的备份，无法回滚"
        send_notification "error" "部署失败且无法回滚"
    fi
    
    exit 1
}

# =============================================================================
# 主部署流程
# =============================================================================
main() {
    log_info "=========================================="
    log_info "开始部署 - $(date)"
    log_info "=========================================="
    
    # 创建必要目录
    mkdir -p "$DEPLOY_DIR" "$BACKUP_DIR"
    
    # 创建临时工作目录
    WORK_DIR=$(mktemp -d)
    trap "rm -rf $WORK_DIR" EXIT
    
    log_info "工作目录: $WORK_DIR"
    
    # Step 1: 克隆/拉取代码
    log_info "Step 1: 拉取最新代码..."
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORK_DIR/repo"
    cd "$WORK_DIR/repo"
    
    COMMIT_HASH=$(git rev-parse --short HEAD)
    log_info "当前提交: $COMMIT_HASH"
    
    # Step 2: 安装依赖
    log_info "Step 2: 安装依赖..."
    npm ci --prefer-offline
    
    # Step 3: 构建项目
    log_info "Step 3: 构建项目..."
    npm run build
    
    if [ ! -d "dist" ]; then
        log_error "构建失败：dist 目录不存在"
        rollback
    fi
    
    # Step 4: 备份当前版本
    log_info "Step 4: 备份当前版本..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="${TIMESTAMP}_${COMMIT_HASH}"
    
    if [ -d "$DEPLOY_DIR/dist" ]; then
        cp -r "$DEPLOY_DIR/dist" "$BACKUP_DIR/$BACKUP_NAME"
        log_info "备份完成: $BACKUP_NAME"
    else
        log_warn "没有现有版本需要备份"
    fi
    
    # Step 5: 原子化部署（使用 mv 替换）
    log_info "Step 5: 原子化部署..."
    
    # 先移动到临时位置
    NEW_DIST="$DEPLOY_DIR/dist_new"
    OLD_DIST="$DEPLOY_DIR/dist_old"
    
    cp -r dist "$NEW_DIST"
    
    # 原子化切换
    if [ -d "$DEPLOY_DIR/dist" ]; then
        mv "$DEPLOY_DIR/dist" "$OLD_DIST"
    fi
    mv "$NEW_DIST" "$DEPLOY_DIR/dist"
    
    # 清理旧目录
    rm -rf "$OLD_DIST"
    
    # Step 6: 清理旧备份
    cleanup_old_backups
    
    # Step 7: 验证部署
    log_info "Step 6: 验证部署..."
    if [ -f "$DEPLOY_DIR/dist/index.html" ]; then
        log_info "✅ 部署成功！"
        send_notification "success" "部署成功: $COMMIT_HASH"
    else
        log_error "验证失败：index.html 不存在"
        rollback
    fi
    
    log_info "=========================================="
    log_info "部署完成 - $(date)"
    log_info "提交: $COMMIT_HASH"
    log_info "=========================================="
}

# 设置错误处理
trap rollback ERR

# 运行主函数
main "$@"
