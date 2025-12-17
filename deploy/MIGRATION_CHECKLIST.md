# 🚀 云服务器 → GitHub Pages 迁移检查清单

## 📋 迁移前准备

### 1. 数据备份
- [ ] 备份云服务器上的 `/var/www/blog/dist` 目录
- [ ] 备份 Nginx 配置文件
- [ ] 备份 SSL 证书（如需保留）
- [ ] 导出访问日志（如需分析）

### 2. 代码仓库准备
- [ ] 确保代码已推送到 GitHub 仓库
- [ ] 确认 `.github/workflows/deploy.yml` 文件存在
- [ ] 检查 `astro.config.mjs` 中的 `site` 配置

### 3. GitHub 仓库设置
- [ ] 进入仓库 Settings → Pages
- [ ] Source 选择 "GitHub Actions"
- [ ] 如使用自定义域名，在 Custom domain 填入域名

---

## 🔄 迁移步骤

### Step 1: 测试 GitHub Actions 构建
```bash
# 推送一个小改动触发构建
git commit --allow-empty -m "test: trigger GitHub Actions"
git push origin main
```
- [ ] 检查 Actions 页面，确认构建成功
- [ ] 访问 `https://your-username.github.io/your-repo/` 验证

### Step 2: 配置自定义域名（可选）

#### 2.1 在仓库中添加 CNAME 文件
```bash
echo "your-domain.com" > public/CNAME
git add public/CNAME
git commit -m "Add custom domain"
git push
```

#### 2.2 GitHub Pages 设置
- [ ] Settings → Pages → Custom domain 填入 `your-domain.com`
- [ ] 勾选 "Enforce HTTPS"

### Step 3: DNS 切换

#### 3.1 获取 GitHub Pages IP 地址
GitHub Pages 的 IP 地址（A 记录）：
```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

#### 3.2 修改 DNS 记录

**方案 A：使用 A 记录（推荐用于根域名）**
| 类型 | 名称 | 值 | TTL |
|------|------|-----|-----|
| A | @ | 185.199.108.153 | 300 |
| A | @ | 185.199.109.153 | 300 |
| A | @ | 185.199.110.153 | 300 |
| A | @ | 185.199.111.153 | 300 |
| CNAME | www | your-username.github.io | 300 |

**方案 B：使用 CNAME（仅适用于子域名）**
| 类型 | 名称 | 值 | TTL |
|------|------|-----|-----|
| CNAME | www | your-username.github.io | 300 |

- [ ] 登录域名注册商控制台
- [ ] 删除指向旧服务器的 A 记录
- [ ] 添加上述新记录
- [ ] 等待 DNS 生效（通常 5-30 分钟，最长 48 小时）

### Step 4: 验证迁移
```bash
# 检查 DNS 解析
dig your-domain.com +short

# 应该返回 GitHub Pages 的 IP
# 185.199.108.153
# 185.199.109.153
# ...

# 检查网站可访问性
curl -I https://your-domain.com
```
- [ ] 网站可正常访问
- [ ] HTTPS 证书有效（GitHub 自动提供）
- [ ] 所有页面和资源加载正常

### Step 5: 清理旧服务器
- [ ] 停止 Nginx 服务
- [ ] 备份重要数据到本地
- [ ] 取消服务器续费（或删除实例）

---

## ⚡ 零停机迁移策略

为了实现零停机迁移，建议按以下顺序操作：

1. **先在 GitHub Pages 部署成功**
   - 使用 `your-username.github.io` 访问验证

2. **降低 DNS TTL**
   - 迁移前 24 小时，将 TTL 改为 300 秒（5分钟）
   - 这样切换后能更快生效

3. **选择低流量时段切换**
   - 建议在凌晨或周末进行

4. **切换 DNS 后保持旧服务器运行 24 小时**
   - 确保所有 DNS 缓存都已更新

5. **监控新站点**
   - 使用 UptimeRobot 等工具监控可用性

---

## 🔙 回滚方案

如果迁移后发现问题，可以快速回滚：

### 立即回滚
```bash
# 1. 将 DNS 记录改回旧服务器 IP
# 2. 确保旧服务器 Nginx 仍在运行
# 3. 等待 DNS 生效
```

### 回滚检查
- [ ] 旧服务器 Nginx 正常运行
- [ ] 网站内容是最新版本
- [ ] SSL 证书仍然有效

---

## 🔍 常见问题排查

### Q1: GitHub Pages 构建失败
```bash
# 检查 Actions 日志
# 常见原因：
# - Node.js 版本不兼容
# - 依赖安装失败
# - 构建脚本错误
```

### Q2: 自定义域名不生效
- 确认 CNAME 文件在 `public/` 目录
- 检查 DNS 记录是否正确
- 等待 DNS 传播（使用 https://dnschecker.org 检查）

### Q3: HTTPS 证书错误
- GitHub 会自动为自定义域名申请证书
- 首次配置可能需要等待 15-30 分钟
- 确保 "Enforce HTTPS" 已勾选

### Q4: 404 错误
- 检查 `astro.config.mjs` 中的 `base` 配置
- 如果是项目页面（非 user.github.io），需要设置 base 路径

---

## ✅ 迁移完成确认

- [ ] 网站可通过 HTTPS 正常访问
- [ ] 所有页面路由正常
- [ ] 图片和静态资源加载正常
- [ ] RSS 订阅链接有效
- [ ] 搜索功能正常（如有）
- [ ] 旧服务器已安全下线
- [ ] 通知搜索引擎重新索引（可选）
  - Google Search Console
  - Bing Webmaster Tools
