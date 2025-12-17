# 🚀 My Astro Blog

一个使用 Astro 构建的极简个人博客。

## ✨ 特性

- ⚡ **Astro 4.x** - 静态站点生成，极速加载
- 🎨 **TailwindCSS** - 极简 Zinc 配色方案
- 🌙 **深色模式** - 跟随系统偏好，一键切换
- 🔍 **Pagefind 搜索** - 静态全文搜索
- 📝 **MDX 支持** - 在 Markdown 中使用组件
- 📰 **RSS 订阅** - 自动生成 RSS feed
- 🗺️ **Sitemap** - 自动生成站点地图
- 📱 **响应式设计** - 移动端优先

## 🛠️ 技术栈

- [Astro](https://astro.build/) - 静态站点生成器
- [TailwindCSS](https://tailwindcss.com/) - CSS 框架
- [Lucide Icons](https://lucide.dev/) - 图标库
- [Pagefind](https://pagefind.app/) - 静态搜索

## 📦 快速开始

```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 构建生产版本
npm run build

# 预览构建结果
npm run preview
```

## 📁 项目结构

```
├── public/              # 静态资源
├── src/
│   ├── components/      # 可复用组件
│   ├── content/         # Markdown 文章
│   │   └── blog/        # 博客文章
│   ├── layouts/         # 页面布局
│   ├── pages/           # 路由页面
│   └── styles/          # 全局样式
├── deploy/              # 部署配置文件
│   ├── nginx.conf       # Nginx 配置
│   ├── deploy.sh        # 自动化部署脚本
│   ├── ssl-setup.sh     # SSL 证书配置
│   ├── health-check.sh  # 健康检查脚本
│   └── *.md             # 部署文档
└── .github/
    └── workflows/       # GitHub Actions
```

## ✍️ 写作

在 `src/content/blog/` 目录下创建 `.md` 或 `.mdx` 文件：

```markdown
---
title: '文章标题'
description: '文章描述'
pubDate: 'Dec 17 2024'
tags: ["astro", "blog"]
---

正文内容...
```

## 🚀 部署

### GitHub Pages（推荐）

1. 推送代码到 GitHub
2. 进入仓库 Settings → Pages
3. Source 选择 "GitHub Actions"
4. 推送到 main 分支自动部署

### 云服务器

参考 `deploy/SERVER_SETUP.md` 文档。

## 📄 License

MIT
