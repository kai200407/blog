#!/bin/bash
# =============================================================================
# 健康检查脚本
# 功能：检查网站可用性、Nginx状态、磁盘空间
# 用法：./health-check.sh [--verbose]
# 建议 cron: */5 * * * * /path/to/health-check.sh
# =============================================================================

# =============================================================================
# 配置区域
# =============================================================================
DOMAIN="your-domain.com"
CHECK_URL="https://$DOMAIN"
DISK_THRESHOLD=90  # 磁盘使用率告警阈值（%）
LOG_FILE="/var/log/blog-health.log"
WEBHOOK_URL=""  # 可选：告警 Webhook

VERBOSE=false
[ "$1" = "--verbose" ] && VERBOSE=true

# =============================================================================
# 颜色输出
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if $VERBOSE; then
        case $level in
            "OK")    echo -e "${GREEN}[OK]${NC} $message" ;;
            "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
            "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
            *)       echo "[$level] $message" ;;
        esac
    fi
}

send_alert() {
    local message=$1
    
    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"🚨 $message\", \"timestamp\": \"$(date -Iseconds)\"}" \
            > /dev/null 2>&1 || true
    fi
}

# =============================================================================
# 检查项目
# =============================================================================

# 1. 检查网站可访问性
check_website() {
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$CHECK_URL")
    
    if [ "$http_code" = "200" ]; then
        log "OK" "网站可访问 (HTTP $http_code)"
        return 0
    else
        log "ERROR" "网站不可访问 (HTTP $http_code)"
        send_alert "网站 $DOMAIN 不可访问 (HTTP $http_code)"
        return 1
    fi
}

# 2. 检查 Nginx 状态
check_nginx() {
    if systemctl is-active --quiet nginx; then
        log "OK" "Nginx 运行正常"
        return 0
    else
        log "ERROR" "Nginx 未运行"
        send_alert "Nginx 服务未运行"
        
        # 尝试自动重启
        log "WARN" "尝试重启 Nginx..."
        sudo systemctl restart nginx
        
        if systemctl is-active --quiet nginx; then
            log "OK" "Nginx 重启成功"
            send_alert "Nginx 已自动重启"
            return 0
        else
            log "ERROR" "Nginx 重启失败"
            return 1
        fi
    fi
}

# 3. 检查磁盘空间
check_disk() {
    local usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$usage" -lt "$DISK_THRESHOLD" ]; then
        log "OK" "磁盘使用率: ${usage}%"
        return 0
    else
        log "WARN" "磁盘使用率过高: ${usage}%"
        send_alert "磁盘使用率过高: ${usage}%"
        return 1
    fi
}

# 4. 检查 SSL 证书有效性
check_ssl() {
    local expiry=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [ -z "$expiry" ]; then
        log "WARN" "无法获取 SSL 证书信息"
        return 1
    fi
    
    local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    
    if [ "$days_left" -gt 14 ]; then
        log "OK" "SSL 证书有效，剩余 ${days_left} 天"
        return 0
    elif [ "$days_left" -gt 0 ]; then
        log "WARN" "SSL 证书即将到期，剩余 ${days_left} 天"
        send_alert "SSL 证书即将到期，剩余 ${days_left} 天"
        return 1
    else
        log "ERROR" "SSL 证书已过期"
        send_alert "SSL 证书已过期！"
        return 1
    fi
}

# 5. 检查内存使用
check_memory() {
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    
    if [ "$mem_usage" -lt 90 ]; then
        log "OK" "内存使用率: ${mem_usage}%"
        return 0
    else
        log "WARN" "内存使用率过高: ${mem_usage}%"
        return 1
    fi
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    local errors=0
    
    $VERBOSE && echo "=========================================="
    $VERBOSE && echo "健康检查 - $(date)"
    $VERBOSE && echo "=========================================="
    
    check_nginx   || ((errors++))
    check_website || ((errors++))
    check_disk    || ((errors++))
    check_ssl     || ((errors++))
    check_memory  || ((errors++))
    
    $VERBOSE && echo "=========================================="
    
    if [ $errors -eq 0 ]; then
        $VERBOSE && echo -e "${GREEN}所有检查通过 ✅${NC}"
        exit 0
    else
        $VERBOSE && echo -e "${RED}发现 $errors 个问题 ❌${NC}"
        exit 1
    fi
}

main "$@"
