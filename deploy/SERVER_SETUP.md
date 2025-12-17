# 🖥️ 云服务器部署指南

## 📋 前置要求

- Ubuntu 22.04 LTS / CentOS 8 服务器
- 已配置 SSH 密钥登录
- 已解析域名到服务器 IP
- 开放端口：22 (SSH), 80 (HTTP), 443 (HTTPS)

---

## 🚀 快速部署（一键脚本）

```bash
# 1. 上传部署文件到服务器
scp -r deploy/ user@your-server:/tmp/

# 2. SSH 登录服务器
ssh user@your-server

# 3. 执行安装
cd /tmp/deploy
chmod +x *.sh
sudo ./server-init.sh  # 如果有的话，或按下面步骤手动执行
```

---

## 📝 手动部署步骤

### Step 1: 系统更新与基础软件

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx git curl wget unzip

# CentOS/RHEL
sudo yum update -y
sudo yum install -y nginx git curl wget unzip
```

### Step 2: 安装 Node.js

```bash
# 使用 NodeSource 安装 Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 验证安装
node --version  # 应该显示 v20.x.x
npm --version
```

### Step 3: 创建部署目录

```bash
# 创建网站目录
sudo mkdir -p /var/www/blog
sudo mkdir -p /var/www/blog-backups
sudo mkdir -p /var/www/certbot

# 设置权限
sudo chown -R $USER:$USER /var/www/blog
sudo chown -R $USER:$USER /var/www/blog-backups
```

### Step 4: 配置 Nginx

```bash
# 复制配置文件
sudo cp nginx.conf /etc/nginx/sites-available/blog

# 创建软链接启用站点
sudo ln -s /etc/nginx/sites-available/blog /etc/nginx/sites-enabled/

# 删除默认站点（可选）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重载 Nginx
sudo systemctl reload nginx
sudo systemctl enable nginx
```

### Step 5: 配置 SSL 证书

```bash
# 运行 SSL 配置脚本
chmod +x ssl-setup.sh
sudo ./ssl-setup.sh

# 或手动安装 Certbot
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

### Step 6: 首次部署

```bash
# 方式一：使用部署脚本
chmod +x deploy.sh
./deploy.sh

# 方式二：手动部署
git clone https://github.com/your-username/your-blog.git /tmp/blog
cd /tmp/blog
npm ci
npm run build
cp -r dist /var/www/blog/
```

### Step 7: 配置日志轮转

```bash
sudo cp logrotate.conf /etc/logrotate.d/nginx-blog
```

### Step 8: 配置健康检查

```bash
# 复制健康检查脚本
sudo cp health-check.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/health-check.sh

# 添加到 cron（每 5 分钟检查一次）
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/health-check.sh") | crontab -
```

### Step 9: 配置防火墙

```bash
# Ubuntu (UFW)
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# CentOS (firewalld)
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

---

## 🔧 配置文件说明

### 文件清单

| 文件 | 用途 | 安装位置 |
|------|------|----------|
| `nginx.conf` | Nginx 站点配置 | `/etc/nginx/sites-available/blog` |
| `deploy.sh` | 自动化部署脚本 | `/usr/local/bin/deploy-blog.sh` |
| `ssl-setup.sh` | SSL 证书配置 | 一次性运行 |
| `health-check.sh` | 健康检查脚本 | `/usr/local/bin/health-check.sh` |
| `logrotate.conf` | 日志轮转配置 | `/etc/logrotate.d/nginx-blog` |

### 需要修改的配置项

在使用前，请修改以下配置：

#### nginx.conf
```nginx
server_name your-domain.com www.your-domain.com;  # 改为你的域名
ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;  # 改为你的域名
```

#### deploy.sh
```bash
REPO_URL="git@github.com:your-username/your-blog.git"  # 改为你的仓库
```

#### ssl-setup.sh
```bash
DOMAIN="your-domain.com"  # 改为你的域名
EMAIL="your-email@example.com"  # 改为你的邮箱
```

---

## 🔄 日常运维

### 手动部署更新
```bash
cd /path/to/deploy
./deploy.sh
```

### 查看 Nginx 状态
```bash
sudo systemctl status nginx
```

### 查看访问日志
```bash
tail -f /var/log/nginx/blog.access.log
```

### 查看错误日志
```bash
tail -f /var/log/nginx/blog.error.log
```

### 手动续期 SSL 证书
```bash
sudo certbot renew
```

### 运行健康检查
```bash
/usr/local/bin/health-check.sh --verbose
```

---

## ❓ 常见问题

### Q1: Nginx 启动失败
```bash
# 检查配置语法
sudo nginx -t

# 查看详细错误
sudo journalctl -u nginx -n 50
```

### Q2: 502 Bad Gateway
- 检查后端服务是否运行
- 检查 Nginx 配置中的 upstream 设置

### Q3: SSL 证书问题
```bash
# 检查证书状态
sudo certbot certificates

# 强制续期
sudo certbot renew --force-renewal
```

### Q4: 权限问题
```bash
# 确保 Nginx 用户可以读取网站目录
sudo chown -R www-data:www-data /var/www/blog/dist
# 或
sudo chmod -R 755 /var/www/blog/dist
```

---

## 📊 监控建议

### 免费监控服务
- **UptimeRobot**: 网站可用性监控
- **Cloudflare**: CDN + 基础分析
- **Google Analytics**: 访问统计

### 服务器监控
```bash
# 安装 htop
sudo apt install htop

# 查看系统资源
htop

# 查看磁盘使用
df -h

# 查看内存使用
free -h
```
