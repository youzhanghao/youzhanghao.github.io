---
title: maven依赖管理
---
{%- assign base_image_url = site.url | append: '/assets/images' -%}


# maven依赖管理

## 查看依赖
1.通过命令查看依赖树

`❯ mvn dependency:tree`

建议输出到文本中查看

`❯ mvn dependency:tree > dep.txt`

2.Idea中下载插件maven helper，在你的pom文件底部将会多出dependency analyzer。

_如何安装_：参考[Idea常用插件及安装][idea-plugin]

<img src="{{ base_image_url }}/maven-helper.png" alt="image.png" style="zoom:50%;margin:0px">

## Springboot依赖管理
### pom中dependency标签引入
```xml
    <!--   链路追踪     -->
    <dependency>
        <groupId>org.apache.skywalking</groupId>
        <artifactId>apm-toolkit-trace</artifactId>
        <version>8.9.0</version>
    </dependency>
```
### 父pom的properties版本号覆盖（重点）
> 现在spring新系列都采用此种方式，不要再随意的引入和exclude方式去做，容易
造成依赖混乱不清
> 
引入方式：parent标签声明依赖管理

```xml
    <!--声明依赖管理-->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.1.2.RELEASE</version>
    </parent>
    <!--内部版本号管理-->
    <properties>
        <java.version>1.8</java.version>
        <commons-pool2.version>2.9.0</commons-pool2.version>
        <jedis.version>3.6.0</jedis.version>
    </properties>
```
> 一般情况不建议私自改动版本号，可能会存在兼容问题
> 
>如上改了之后，你的项目在应用redis连接池，会有错误

因为2.1.2.RELEASE的父pom文件中，高版本的jedis无法兼容starter-data-redis

_查看父pom文件_：idea中点击`2.1.2.RELEASE`进入父pom，父pom文件继续点击`spring-boot-dependencies`中`2.1.2.RELEASE`
进入`spring-boot-dependencies`，可以看到`spring-boot-starter-data-redis`是固定的
```xml
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-redis</artifactId>
        <version>2.1.2.RELEASE</version>
    </dependency>
```
_兼容版本查看方法_：进入到[maven库][maven-repo]，搜索你需要的依赖，以jedis为例

<img src="{{ base_image_url }}/maven-dep.png" alt="image.png" style="zoom:50%;margin:0px">

### spring-boot低版本升级jedis至3.6.0版本
直接升级`spring-boot-starter-data-redis`，`spring-boot-starter-data-redis`
是由内部的`spring-data-redis`管理jedis版本，通过maven仓库查找[对应版本][spring-data-redis]，发现2.5.1版本开始支持3.6.0
，升级`spring-boot-starter-data-redis`至该版本即可
```xml
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
            <version>2.5.1</version>
        </dependency>
```
_jedis为何升级3.6.0版本_：阅读[jedis连接池泄漏][jedis-pool]

[idea-plugin]: idea-plugin
[maven-repo]: https://mvnrepository.com/
[spring-data-redis]:https://mvnrepository.com/artifact/org.springframework.data/spring-data-redis/2.5.1
[jedis-pool]: ../questions/jedis-pool-qa