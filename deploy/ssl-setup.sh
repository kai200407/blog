#!/bin/bash
# =============================================================================
# SSL 证书安装与自动续期配置脚本
# 使用 Let's Encrypt + Certbot
# 适用于：Ubuntu 22.04 / Debian 12
# =============================================================================

set -e

# =============================================================================
# 配置区域
# =============================================================================
DOMAIN="your-domain.com"
EMAIL="your-email@example.com"
WEBROOT="/var/www/certbot"

# =============================================================================
# 颜色输出
# =============================================================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# =============================================================================
# Step 1: 安装 Certbot
# =============================================================================
install_certbot() {
    log_info "安装 Certbot..."
    
    # Ubuntu/Debian
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    # CentOS/RHEL
    elif command -v yum &> /dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y certbot python3-certbot-nginx
    else
        log_warn "未知的包管理器，请手动安装 certbot"
        exit 1
    fi
    
    log_info "Certbot 安装完成"
}

# =============================================================================
# Step 2: 创建 webroot 目录
# =============================================================================
setup_webroot() {
    log_info "创建 webroot 目录..."
    sudo mkdir -p "$WEBROOT"
    sudo chown -R www-data:www-data "$WEBROOT" 2>/dev/null || \
    sudo chown -R nginx:nginx "$WEBROOT" 2>/dev/null || true
}

# =============================================================================
# Step 3: 获取证书
# =============================================================================
obtain_certificate() {
    log_info "获取 SSL 证书..."
    
    # 使用 webroot 模式（需要 Nginx 已配置 .well-known 路径）
    sudo certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"
    
    log_info "证书获取成功！"
    log_info "证书位置: /etc/letsencrypt/live/$DOMAIN/"
}

# =============================================================================
# Step 4: 配置自动续期
# =============================================================================
setup_auto_renewal() {
    log_info "配置自动续期..."
    
    # Certbot 通常会自动创建 systemd timer 或 cron job
    # 这里我们确保它存在并添加 Nginx reload
    
    # 创建续期后的 hook 脚本
    sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh > /dev/null << 'EOF'
#!/bin/bash
# 证书续期后自动重载 Nginx
systemctl reload nginx
echo "[$(date)] Nginx reloaded after certificate renewal" >> /var/log/letsencrypt/renewal.log
EOF
    
    sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
    
    # 测试续期（dry-run）
    log_info "测试自动续期..."
    sudo certbot renew --dry-run
    
    log_info "自动续期配置完成"
}

# =============================================================================
# Step 5: 创建证书到期提醒脚本
# =============================================================================
setup_expiry_alert() {
    log_info "创建证书到期提醒脚本..."
    
    sudo tee /usr/local/bin/check-ssl-expiry.sh > /dev/null << 'SCRIPT'
#!/bin/bash
# =============================================================================
# SSL 证书到期检查脚本
# 建议添加到 cron: 0 9 * * * /usr/local/bin/check-ssl-expiry.sh
# =============================================================================

DOMAIN="${1:-your-domain.com}"
ALERT_DAYS=14  # 提前多少天告警
EMAIL="your-email@example.com"

# 获取证书到期时间
EXPIRY_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

if [ -z "$EXPIRY_DATE" ]; then
    echo "无法获取证书信息"
    exit 1
fi

# 计算剩余天数
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

echo "域名: $DOMAIN"
echo "到期时间: $EXPIRY_DATE"
echo "剩余天数: $DAYS_LEFT"

# 如果剩余天数少于告警阈值，发送邮件
if [ "$DAYS_LEFT" -lt "$ALERT_DAYS" ]; then
    echo "⚠️ 警告：SSL 证书将在 $DAYS_LEFT 天后到期！"
    
    # 发送邮件告警（需要配置 mailutils）
    if command -v mail &> /dev/null; then
        echo "SSL 证书 $DOMAIN 将在 $DAYS_LEFT 天后到期，请及时续期。" | \
        mail -s "⚠️ SSL证书即将到期: $DOMAIN" "$EMAIL"
    fi
fi
SCRIPT
    
    sudo chmod +x /usr/local/bin/check-ssl-expiry.sh
    
    # 添加到 cron（每天早上9点检查）
    (crontab -l 2>/dev/null | grep -v "check-ssl-expiry"; echo "0 9 * * * /usr/local/bin/check-ssl-expiry.sh $DOMAIN") | crontab -
    
    log_info "证书到期提醒已配置"
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    echo "=========================================="
    echo "SSL 证书安装与配置"
    echo "域名: $DOMAIN"
    echo "=========================================="
    
    install_certbot
    setup_webroot
    obtain_certificate
    setup_auto_renewal
    setup_expiry_alert
    
    echo ""
    echo "=========================================="
    echo "✅ SSL 配置完成！"
    echo ""
    echo "证书路径:"
    echo "  - 证书: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    echo "  - 私钥: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
    echo ""
    echo "下一步:"
    echo "  1. 更新 Nginx 配置中的证书路径"
    echo "  2. 运行: sudo nginx -t && sudo systemctl reload nginx"
    echo "=========================================="
}

# 运行
main "$@"
