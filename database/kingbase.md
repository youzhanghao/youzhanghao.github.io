---
title: kingbase
---
# 人大金仓kingbase

## 安装
> 数据库管理员：默认SYSTEM；
> 
> 管理员密码：手动输入，确认密码；
> 
> 字符集编码：默认UTF-8；
> 
> 大小写是否敏感：1不敏感，2敏感，默认敏感。

## 配置
kingbase.conf
```
# 连接数设置
max_connections=500
# 区分null和空字符串 
# 注:只能区分输入的内容为null或者空
ora_input_emptystr_isnull=false 
```
## 语法
登录
```
ksql -Usystem -W123456 test
```
创建用户
```
create user kingbase with password '3edcVFR$';
```
查看用户
```
select * from sys_user;
```
修改用户
```
alter user test1 with password '654321';
```
删除用户
```
drop user test1;
```
查看所有表
```
\d
\d+
```
查看表结构
```
\d+ table_name;
```
创建数据库
```
TEST=# create database ruoyi_mysql_test owner kingbase;
```
查看数据库
```
\l
```
更改数据库配置
```
ALTER DATABASE mydb SET geqo TO off;
```
销毁数据库
```
DROP DATABASE name;
```
切换数据库
```
\c changning_qinwu;
```
时间类型做interval转换
```
to_char( t1.start_time,'HH24:MI:SS')::interval 
```
查看登录用户下所有的表
```
select table_name from user_tables;
```
与kingbase系统表重名
```
ALTER DATABASE 数据库名 SET search_path to "$user", public, sys, sys_catalog, pg_catalog;
然后执行 select sys_reload_conf(); 重载配置文件
```
> 注意：应用系统可能需重新连接生效

举例
```
ALTER DATABASE ruoyi_mysql_test SET search_path to kingbase, public, sys, sys_catalog, pg_catalog;
```
sql中repalce函数替换为空后仍为null

修改前
```
 REPLACE ( jgmc, 'XXX', '' ) AS orgName
```
修改后
```
 case when REPLACE ( b.jgmc, 'XXX', '') isnull then ' ' else REPLACE ( b.jgmc, 'XXX', '') end AS orgName

```
pgsql迁移分页的方言选择
  
修改前
```
pagehelper:
    auto-dialect: pgsql
    reasonable: true
    support-methods-arguments: true
    page-size-zero: true
    params: countSql
```
修改后
```
pagehelper:
    reasonable: true
    support-methods-arguments: true
    page-size-zero: true
    params: countSql
    helper-dialect: postgresql
```
别名大小写问题

pgsql中字段别名
```
select t1.jgbm orgCode, replace(replace(t1.jgmc,'XXX',''),replace(t2.jgmc,'XXX','') ,'')  orgName,replace(t2.jgmc,'XXX','') parentOrgName,t2.jgbm parentOrgCode from sh_agency_info t1 join sh_agency_info t2 on t1.sjxzqhdm=t2.jgbm
```
V8R3数据库中将按原别名字段，结果集
```
orgcode|orgname|parentorgname|parentorgcode
```
mysql中的`to_date`函数替换`date_formate`


