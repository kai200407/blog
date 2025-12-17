#!/usr/bin/env node
/**
 * 将 study 目录下的 markdown 文件导入到博客
 * 用法: node scripts/import-study.js
 */

const fs = require('fs');
const path = require('path');

const STUDY_DIR = '/root/workspace/study';
const BLOG_DIR = '/root/workspace/Blog/astro-blog/src/content/blog';

// 系列配置
const SERIES_CONFIG = {
    'cpp-mastery': {
        name: 'C++ 从入门到精通',
        category: 'cpp',
        tags: ['cpp', 'programming'],
        dirs: ['part1-basics', 'part2-oop', 'part3-memory', 'part4-stl', 'part5-modern',
            'part6-concurrency', 'part7-network', 'part8-system', 'part9-engineering', 'part10-projects']
    },
    'python-crawler-mastery': {
        name: 'Python 爬虫实战',
        category: 'python',
        tags: ['python', 'crawler', 'scraping'],
        dirs: ['docs/part1-basics', 'docs/part2-parsing', 'docs/part3-dynamic', 'docs/part4-anti',
            'docs/part5-storage', 'docs/part6-framework', 'docs/part7-advanced']
    },
    'rabbitmq-mastery': {
        name: 'RabbitMQ 消息队列',
        category: 'rabbitmq',
        tags: ['rabbitmq', 'mq', 'backend'],
        scanDocs: true  // 特殊标记：扫描 docs 下所有子目录
    },
    'reddit-mastery': {
        name: 'Reddit API 开发',
        category: 'reddit',
        tags: ['reddit', 'api', 'python'],
        dirs: ['docs/part1-basics', 'docs/part2-advanced', 'docs/part3-practice']
    },
    'webrtc-blog': {
        name: 'WebRTC 音视频开发',
        category: 'webrtc',
        tags: ['webrtc', 'audio', 'video'],
        dirs: ['part1-basics', 'part2-signaling', 'part3-media', 'part4-codec', 'part5-practice', 'part6-advanced']
    }
};

// 从文件名提取序号
function extractOrder(filename) {
    const match = filename.match(/^(\d+)/);
    return match ? parseInt(match[1]) : 0;
}

// 从 markdown 文件提取标题
function extractTitle(content, filename) {
    const match = content.match(/^#\s+(.+)$/m);
    if (match) return match[1].trim();
    // 从文件名生成标题
    return filename.replace(/^\d+-/, '').replace(/-/g, ' ').replace(/\.md$/, '');
}

// 从 markdown 文件提取描述
function extractDescription(content) {
    // 尝试找到第一个段落
    const lines = content.split('\n');
    for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#') && !trimmed.startsWith('>') && !trimmed.startsWith('-') && !trimmed.startsWith('```')) {
            return trimmed.slice(0, 200);
        }
    }
    return '技术学习笔记';
}

// 处理 markdown 内容，移除第一个标题（会在 frontmatter 中使用）
function processContent(content) {
    // 移除第一个 h1 标题
    return content.replace(/^#\s+.+\n+/, '');
}

// 生成 frontmatter
function generateFrontmatter(title, description, series, category, tags, order) {
    const pubDate = new Date().toISOString().split('T')[0];
    return `---
title: "${title.replace(/"/g, '\\"')}"
description: "${description.replace(/"/g, '\\"')}"
pubDate: "${pubDate}"
tags: ${JSON.stringify(tags)}
category: "${category}"
series: "${series}"
order: ${order}
---

`;
}

// 生成 slug
function generateSlug(seriesKey, filename) {
    const base = filename.replace(/\.md$/, '');
    return `${seriesKey}-${base}`;
}

// 处理单个文件
function processFile(filePath, seriesKey, config) {
    const filename = path.basename(filePath);
    if (!filename.endsWith('.md') || filename === 'README.md') return null;

    const content = fs.readFileSync(filePath, 'utf-8');
    const title = extractTitle(content, filename);
    const description = extractDescription(content);
    const order = extractOrder(filename);
    const processedContent = processContent(content);

    const tags = [...config.tags];
    const frontmatter = generateFrontmatter(title, description, config.name, config.category, tags, order);

    const slug = generateSlug(seriesKey, filename);
    const outputPath = path.join(BLOG_DIR, `${slug}.md`);

    fs.writeFileSync(outputPath, frontmatter + processedContent);
    console.log(`✅ ${slug}.md`);

    return { slug, title, order };
}

// 处理一个系列
function processSeries(seriesKey, config) {
    const seriesDir = path.join(STUDY_DIR, seriesKey);
    if (!fs.existsSync(seriesDir)) {
        console.log(`⚠️ 目录不存在: ${seriesDir}`);
        return [];
    }

    const articles = [];

    // 特殊处理：扫描 docs 下所有子目录
    if (config.scanDocs) {
        const docsDir = path.join(seriesDir, 'docs');
        if (fs.existsSync(docsDir)) {
            const subdirs = fs.readdirSync(docsDir).filter(d => {
                const stat = fs.statSync(path.join(docsDir, d));
                return stat.isDirectory();
            }).sort();

            for (const subdir of subdirs) {
                const dirPath = path.join(docsDir, subdir);
                // 优先查找非 README.md 的文件，如果没有则使用 README.md
                let files = fs.readdirSync(dirPath).filter(f => f.endsWith('.md') && f !== 'README.md');
                if (files.length === 0) {
                    // 如果只有 README.md，则使用它
                    const readmePath = path.join(dirPath, 'README.md');
                    if (fs.existsSync(readmePath)) {
                        files = ['README.md'];
                    }
                }
                files.sort();

                for (const file of files) {
                    // 使用目录名作为文件名前缀
                    const order = extractOrder(subdir);
                    const result = processFileWithOrder(path.join(dirPath, file), seriesKey, config, order, subdir);
                    if (result) articles.push(result);
                }
            }
        }
        return articles;
    }

    for (const subdir of config.dirs) {
        const dirPath = path.join(seriesDir, subdir);
        if (!fs.existsSync(dirPath)) continue;

        const files = fs.readdirSync(dirPath).filter(f => f.endsWith('.md') && f !== 'README.md');
        files.sort();

        for (const file of files) {
            const result = processFile(path.join(dirPath, file), seriesKey, config);
            if (result) articles.push(result);
        }
    }

    return articles;
}

// 处理单个文件（带自定义序号）
function processFileWithOrder(filePath, seriesKey, config, order, dirName) {
    const filename = path.basename(filePath);
    if (!filename.endsWith('.md')) return null;

    const content = fs.readFileSync(filePath, 'utf-8');
    const title = extractTitle(content, filename);
    const description = extractDescription(content);
    const processedContent = processContent(content);

    const tags = [...config.tags];
    const frontmatter = generateFrontmatter(title, description, config.name, config.category, tags, order);

    const slug = `${seriesKey}-${dirName}`;
    const outputPath = path.join(BLOG_DIR, `${slug}.md`);

    fs.writeFileSync(outputPath, frontmatter + processedContent);
    console.log(`✅ ${slug}.md`);

    return { slug, title, order };
}

// 主函数
function main() {
    console.log('🚀 开始导入 study 目录...\n');

    // 确保输出目录存在
    if (!fs.existsSync(BLOG_DIR)) {
        fs.mkdirSync(BLOG_DIR, { recursive: true });
    }

    const allArticles = {};

    for (const [seriesKey, config] of Object.entries(SERIES_CONFIG)) {
        console.log(`\n📚 处理系列: ${config.name}`);
        const articles = processSeries(seriesKey, config);
        allArticles[seriesKey] = articles;
        console.log(`   共 ${articles.length} 篇文章`);
    }

    // 统计
    const total = Object.values(allArticles).reduce((sum, arr) => sum + arr.length, 0);
    console.log(`\n✨ 导入完成! 共 ${total} 篇文章`);
}

main();
