---
title: "数据库存储"
description: "1. [SQLite 存储](#1-sqlite-存储)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 20
---

> 本文介绍如何将爬取的数据存储到关系型数据库。

---

## 目录

1. [SQLite 存储](#1-sqlite-存储)
2. [MySQL 存储](#2-mysql-存储)
3. [SQLAlchemy ORM](#3-sqlalchemy-orm)
4. [批量插入优化](#4-批量插入优化)
5. [实战示例](#5-实战示例)

---

## 1. SQLite 存储

### 1.1 基本使用

```python
import sqlite3
from datetime import datetime

class SQLiteStorage:
    def __init__(self, db_path='data.db'):
        self.conn = sqlite3.connect(db_path)
        self.cursor = self.conn.cursor()
        self._init_table()
    
    def _init_table(self):
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS articles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                url TEXT UNIQUE,
                content TEXT,
                author TEXT,
                publish_time TEXT,
                crawled_at TEXT
            )
        ''')
        self.conn.commit()
    
    def save(self, data):
        try:
            self.cursor.execute('''
                INSERT OR REPLACE INTO articles 
                (title, url, content, author, publish_time, crawled_at)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                data['title'],
                data['url'],
                data.get('content'),
                data.get('author'),
                data.get('publish_time'),
                datetime.now().isoformat()
            ))
            self.conn.commit()
            return True
        except Exception as e:
            print(f"保存失败: {e}")
            return False
    
    def find_all(self, limit=100):
        self.cursor.execute('SELECT * FROM articles LIMIT ?', (limit,))
        return self.cursor.fetchall()
    
    def find_by_url(self, url):
        self.cursor.execute('SELECT * FROM articles WHERE url = ?', (url,))
        return self.cursor.fetchone()
    
    def close(self):
        self.conn.close()

# 使用
storage = SQLiteStorage('articles.db')
storage.save({
    'title': '文章标题',
    'url': 'https://example.com/article/1',
    'content': '文章内容...',
    'author': '作者'
})
```

### 1.2 上下文管理器

```python
class SQLiteStorage:
    def __init__(self, db_path):
        self.db_path = db_path
        self.conn = None
    
    def __enter__(self):
        self.conn = sqlite3.connect(self.db_path)
        self.cursor = self.conn.cursor()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.conn:
            self.conn.close()

# 使用
with SQLiteStorage('data.db') as storage:
    storage.save(data)
```

---

## 2. MySQL 存储

### 2.1 安装

```bash
pip install pymysql
```

### 2.2 基本使用

```python
import pymysql
from datetime import datetime

class MySQLStorage:
    def __init__(self, host, user, password, database, port=3306):
        self.conn = pymysql.connect(
            host=host,
            user=user,
            password=password,
            database=database,
            port=port,
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
        self.cursor = self.conn.cursor()
        self._init_table()
    
    def _init_table(self):
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS articles (
                id INT AUTO_INCREMENT PRIMARY KEY,
                title VARCHAR(500) NOT NULL,
                url VARCHAR(1000) UNIQUE,
                content TEXT,
                author VARCHAR(100),
                publish_time DATETIME,
                crawled_at DATETIME,
                INDEX idx_url (url(255)),
                INDEX idx_crawled (crawled_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ''')
        self.conn.commit()
    
    def save(self, data):
        sql = '''
            INSERT INTO articles (title, url, content, author, publish_time, crawled_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            content = VALUES(content),
            crawled_at = VALUES(crawled_at)
        '''
        try:
            self.cursor.execute(sql, (
                data['title'],
                data['url'],
                data.get('content'),
                data.get('author'),
                data.get('publish_time'),
                datetime.now()
            ))
            self.conn.commit()
            return True
        except Exception as e:
            self.conn.rollback()
            print(f"保存失败: {e}")
            return False
    
    def find_all(self, limit=100):
        self.cursor.execute('SELECT * FROM articles LIMIT %s', (limit,))
        return self.cursor.fetchall()
    
    def close(self):
        self.cursor.close()
        self.conn.close()

# 使用
storage = MySQLStorage(
    host='localhost',
    user='root',
    password='password',
    database='crawler'
)
storage.save({'title': '标题', 'url': 'https://example.com'})
storage.close()
```

### 2.3 连接池

```python
from dbutils.pooled_db import PooledDB
import pymysql

class MySQLPool:
    _pool = None
    
    @classmethod
    def get_pool(cls):
        if cls._pool is None:
            cls._pool = PooledDB(
                creator=pymysql,
                maxconnections=10,
                mincached=2,
                maxcached=5,
                blocking=True,
                host='localhost',
                user='root',
                password='password',
                database='crawler',
                charset='utf8mb4'
            )
        return cls._pool
    
    @classmethod
    def get_connection(cls):
        return cls.get_pool().connection()

# 使用
conn = MySQLPool.get_connection()
cursor = conn.cursor()
cursor.execute('SELECT * FROM articles')
results = cursor.fetchall()
cursor.close()
conn.close()  # 归还到连接池
```

---

## 3. SQLAlchemy ORM

### 3.1 安装

```bash
pip install sqlalchemy
```

### 3.2 定义模型

```python
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime

Base = declarative_base()

class Article(Base):
    __tablename__ = 'articles'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    title = Column(String(500), nullable=False)
    url = Column(String(1000), unique=True)
    content = Column(Text)
    author = Column(String(100))
    publish_time = Column(DateTime)
    crawled_at = Column(DateTime, default=datetime.now)
    
    def __repr__(self):
        return f"<Article(title='{self.title[:20]}...')>"
    
    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'url': self.url,
            'content': self.content,
            'author': self.author,
            'publish_time': self.publish_time.isoformat() if self.publish_time else None,
            'crawled_at': self.crawled_at.isoformat() if self.crawled_at else None
        }
```

### 3.3 数据库操作

```python
class DatabaseManager:
    def __init__(self, db_url='sqlite:///data.db'):
        self.engine = create_engine(db_url, echo=False)
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
    
    def get_session(self):
        return self.Session()
    
    def save_article(self, data):
        session = self.get_session()
        try:
            article = Article(
                title=data['title'],
                url=data['url'],
                content=data.get('content'),
                author=data.get('author'),
                publish_time=data.get('publish_time')
            )
            session.merge(article)  # 存在则更新
            session.commit()
            return True
        except Exception as e:
            session.rollback()
            print(f"保存失败: {e}")
            return False
        finally:
            session.close()
    
    def get_articles(self, limit=100):
        session = self.get_session()
        try:
            articles = session.query(Article).limit(limit).all()
            return [a.to_dict() for a in articles]
        finally:
            session.close()
    
    def get_by_url(self, url):
        session = self.get_session()
        try:
            return session.query(Article).filter_by(url=url).first()
        finally:
            session.close()
    
    def search(self, keyword, limit=50):
        session = self.get_session()
        try:
            articles = session.query(Article).filter(
                Article.title.like(f'%{keyword}%')
            ).limit(limit).all()
            return [a.to_dict() for a in articles]
        finally:
            session.close()

# 使用
db = DatabaseManager('sqlite:///articles.db')
# 或 MySQL
# db = DatabaseManager('mysql+pymysql://user:pass@localhost/crawler')

db.save_article({
    'title': '文章标题',
    'url': 'https://example.com/1',
    'content': '内容...'
})

articles = db.get_articles(limit=10)
```

---

## 4. 批量插入优化

### 4.1 SQLite 批量插入

```python
def batch_insert_sqlite(conn, data_list, batch_size=1000):
    cursor = conn.cursor()
    
    for i in range(0, len(data_list), batch_size):
        batch = data_list[i:i + batch_size]
        
        cursor.executemany('''
            INSERT OR REPLACE INTO articles (title, url, content)
            VALUES (?, ?, ?)
        ''', [(d['title'], d['url'], d.get('content')) for d in batch])
        
        conn.commit()
        print(f"已插入 {min(i + batch_size, len(data_list))} / {len(data_list)}")
```

### 4.2 MySQL 批量插入

```python
def batch_insert_mysql(conn, data_list, batch_size=1000):
    cursor = conn.cursor()
    
    sql = '''
        INSERT INTO articles (title, url, content)
        VALUES (%s, %s, %s)
        ON DUPLICATE KEY UPDATE title = VALUES(title)
    '''
    
    for i in range(0, len(data_list), batch_size):
        batch = data_list[i:i + batch_size]
        values = [(d['title'], d['url'], d.get('content')) for d in batch]
        
        cursor.executemany(sql, values)
        conn.commit()
        print(f"已插入 {min(i + batch_size, len(data_list))} / {len(data_list)}")
```

### 4.3 SQLAlchemy 批量插入

```python
from sqlalchemy.dialects.mysql import insert

def batch_insert_sqlalchemy(session, data_list, batch_size=1000):
    for i in range(0, len(data_list), batch_size):
        batch = data_list[i:i + batch_size]
        
        # 方式1：bulk_insert_mappings
        session.bulk_insert_mappings(Article, batch)
        
        # 方式2：使用 insert
        # stmt = insert(Article).values(batch)
        # stmt = stmt.on_duplicate_key_update(title=stmt.inserted.title)
        # session.execute(stmt)
        
        session.commit()
        print(f"已插入 {min(i + batch_size, len(data_list))} / {len(data_list)}")
```

---

## 5. 实战示例

### 5.1 爬虫存储管道

```python
import sqlite3
from datetime import datetime
from queue import Queue
from threading import Thread

class DatabasePipeline:
    """异步数据库存储管道"""
    
    def __init__(self, db_path='data.db', batch_size=100):
        self.db_path = db_path
        self.batch_size = batch_size
        self.queue = Queue()
        self.running = True
        
        # 初始化数据库
        self._init_db()
        
        # 启动写入线程
        self.writer_thread = Thread(target=self._writer_loop)
        self.writer_thread.start()
    
    def _init_db(self):
        conn = sqlite3.connect(self.db_path)
        conn.execute('''
            CREATE TABLE IF NOT EXISTS items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                data TEXT,
                created_at TEXT
            )
        ''')
        conn.commit()
        conn.close()
    
    def _writer_loop(self):
        conn = sqlite3.connect(self.db_path)
        batch = []
        
        while self.running or not self.queue.empty():
            try:
                item = self.queue.get(timeout=1)
                batch.append(item)
                
                if len(batch) >= self.batch_size:
                    self._write_batch(conn, batch)
                    batch = []
            except:
                if batch:
                    self._write_batch(conn, batch)
                    batch = []
        
        if batch:
            self._write_batch(conn, batch)
        
        conn.close()
    
    def _write_batch(self, conn, batch):
        import json
        cursor = conn.cursor()
        cursor.executemany(
            'INSERT INTO items (data, created_at) VALUES (?, ?)',
            [(json.dumps(item, ensure_ascii=False), datetime.now().isoformat()) for item in batch]
        )
        conn.commit()
        print(f"写入 {len(batch)} 条数据")
    
    def save(self, item):
        self.queue.put(item)
    
    def close(self):
        self.running = False
        self.writer_thread.join()

# 使用
pipeline = DatabasePipeline('crawler.db', batch_size=50)

# 爬虫中
for item in crawled_items:
    pipeline.save(item)

# 结束时
pipeline.close()
```

### 5.2 去重检查

```python
class DeduplicatedStorage:
    """带去重的存储"""
    
    def __init__(self, db_path='data.db'):
        self.conn = sqlite3.connect(db_path)
        self._init_db()
        self._load_existing_urls()
    
    def _init_db(self):
        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS articles (
                id INTEGER PRIMARY KEY,
                url TEXT UNIQUE,
                title TEXT,
                content TEXT
            )
        ''')
        self.conn.commit()
    
    def _load_existing_urls(self):
        cursor = self.conn.execute('SELECT url FROM articles')
        self.existing_urls = set(row[0] for row in cursor.fetchall())
    
    def is_duplicate(self, url):
        return url in self.existing_urls
    
    def save(self, data):
        if self.is_duplicate(data['url']):
            return False
        
        self.conn.execute(
            'INSERT INTO articles (url, title, content) VALUES (?, ?, ?)',
            (data['url'], data['title'], data.get('content'))
        )
        self.conn.commit()
        self.existing_urls.add(data['url'])
        return True

# 使用
storage = DeduplicatedStorage()

for item in items:
    if not storage.is_duplicate(item['url']):
        storage.save(item)
```

---

## 下一步

下一篇我们将学习 MongoDB 存储，适合存储非结构化数据。

---

## 参考资料

- [SQLite 文档](https://www.sqlite.org/docs.html)
- [SQLAlchemy 文档](https://docs.sqlalchemy.org/)
- [PyMySQL 文档](https://pymysql.readthedocs.io/)
