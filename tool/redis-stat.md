---

---
# redis-stat
## 安装

地址

  - [Github地址][1]

  - [备用地址][2]

注：请勿在备用地址登录Github

> 使用jar包形式运行 **推荐**

`java -jar redis-stat-0.4.14.jar --help`


> 熟悉docker，可以采用docker

`docker run --name redis-stat-dev -p 8080:63790 -d insready/redis-stat --server 172.20.62.117:26380 -a 3edcVFR$`

## 命令参数

```shell
usage: redis-stat [HOST[:PORT][/PASS] ...] [INTERVAL [COUNT]]

    -a, --auth=PASSWORD              Password
    -v, --verbose                    Show more info
        --style=STYLE                Output style: unicode|ascii
        --no-color                   Suppress ANSI color codes
        --csv=OUTPUT_CSV_FILE_PATH   Save the result in CSV format
        --es=ELASTICSEARCH_URL       Send results to ElasticSearch: [http://]HOST[:PORT][/INDEX]

        --server[=PORT]              Launch redis-stat web server (default port: 63790)
        --daemon                     Daemonize redis-stat. Must be used with --server option.

        --version                    Show version
        --help                       Show this message
```

## 面板参数

```shell
used_memory_rss

从操作系统的角度， 返回 Redis 已分配的内存总量（ 俗称常驻集大小） 。 这个值和 top 、 ps 等命令的输出一致， 包含了used_memory和内存碎片。

mem_fragmentation_ratio 

used_memory_rss 和 used_memory 之间的比率

blocked_clients

正在等待阻塞命令（BLPOP、BRPOP、BRPOPLPUSH）的客户端的数量

rejected_connections_per_second

 因为每秒最大客户端数量限制而被拒绝的连接请求数量。

total_commands_processed_per_ses

服务器已每秒执行的命令数量

expired_keys_per_second

因为过期而每秒被自动删除的数据库键数量

evicted_keys_per_second

因为最大内存容量限制而每秒被驱逐（evict）的键数量

aof_current_size

AOF 文件目前的大小

aof_base_size :

服务器启动时或者 AOF 重写最近一次执行之后，AOF 文件的大小

rdb_changes_since_last_save 

距离最近一次成功创建持久化文件之后，经过了多少秒

pubsub_channels :

目前被订阅的频道数量

pubsub_patterns 

目前被订阅的模式数量

keyspace_misses _per_second

查找数据库键每秒失败的次数

keyspace_hits _per_second

查找数据库键成功的次数

keyspace_hits_ratio _per_second
```

## 延伸阅读

[性能问题排查][3]

[1]: https://github.com/junegunn/redis-stat
[2]: https://hub.nuaa.cf/junegunn/redis-stat
[3]: https://www.cnblogs.com/mushroom/p/4738170.html