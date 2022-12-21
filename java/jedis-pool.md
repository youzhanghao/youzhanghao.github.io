---
title: 低版本中Jedis对象泄漏证明及探究
---

# 低版本中Jedis对象泄漏证明及探究
> 以下内容为笔者实践而来，并结合自己的推测整理。若有不对或疏漏的欢迎交流。

## 前置条件

> 低版本目前查看版本源码，为3.6.0版本以下，不含3.6.0版本
> 
> 笔者所用版本: jedis 2.9.0版本 spring-boot-starter-data-redis：2.1.2.RELEASE

*版本查看*参考[maven依赖管理][maven-dep]

## 证明
方法有多种，主要抓住何时生成对象，何时销毁对象，本文以@Cacheable为例

项目中新建一个类，`IRedisCacheWriter`，该类从源码包`DefaultRedisCacheWriter`拷贝而来，只做日志打印，方便调试
> 需要注意的是，你需要在`CacheManager`注入自定义的`IRedisCacheWriter`

代码如下

```java
			@Configuration
      @EnableCaching
      public class RedisConfig implements Serializable {
      
      
      
          @Bean
          public RedisCacheManager cacheManager(RedisConnectionFactory redisConnectionFactory) {
              return new RedisCacheManager(
                  new IRedisCacheWriter(redisConnectionFactory),
                  //实时数据 就是默认数据 缓存时间设置
                  this.getRedisCacheConfigurationWithTtl(60), // 默认策略，未配置的 key 会使用这个
                  this.getRedisCacheConfigurationMap() // 指定 key 策略
              );
          }
      
          private Map<String, RedisCacheConfiguration> getRedisCacheConfigurationMap() {
              Map<String, RedisCacheConfiguration> redisCacheConfigurationMap = new HashMap<>();
              //历史数据缓存24小时
              redisCacheConfigurationMap.put("history", this.getRedisCacheConfigurationWithTtl(60 * 60*23));
      
              return redisCacheConfigurationMap;
          }
      
          private RedisCacheConfiguration getRedisCacheConfigurationWithTtl(Integer seconds) {
              Jackson2JsonRedisSerializer<Object> jackson2JsonRedisSerializer = new Jackson2JsonRedisSerializer<>(Object.class);
              ObjectMapper om = new ObjectMapper();
              om.setVisibility(PropertyAccessor.ALL, JsonAutoDetect.Visibility.ANY);
              om.enableDefaultTyping(ObjectMapper.DefaultTyping.NON_FINAL);
              jackson2JsonRedisSerializer.setObjectMapper(om);
              RedisCacheConfiguration redisCacheConfiguration = RedisCacheConfiguration.defaultCacheConfig();
              redisCacheConfiguration = redisCacheConfiguration.serializeValuesWith(
                  RedisSerializationContext
                      .SerializationPair
                      .fromSerializer(jackson2JsonRedisSerializer)
              ).entryTtl(Duration.ofSeconds(seconds));
      
              return redisCacheConfiguration;
          }
      }
```

```java

@Slf4j
class IRedisCacheWriter implements RedisCacheWriter {

	private final RedisConnectionFactory connectionFactory;
	private final Duration sleepTime;

	// ... 代码省略
	
	/**
	 * @return {@literal true} if {@link RedisCacheWriter} uses locks.
	 */
	private boolean isLockingCacheWriter() {
		return !sleepTime.isZero() && !sleepTime.isNegative();
	}

	private <T> T execute(String name, Function<RedisConnection, T> callback) {

		RedisConnection connection = connectionFactory.getConnection();
	 	log.info("-----连接已获得-------");
		try {

			checkAndPotentiallyWaitUntilUnlocked(name, connection);
			return callback.apply(connection);
		} finally {
			connection.close();
		log.info("-----连接已释放-------");
		}
	}

}

```
```java
 @Override
  public void close() {
    log.info("--- jedis jar close func---");
    if (dataSource != null) {
      Pool<Jedis> pool = this.dataSource;
      // 只有进入该方法 才会释放对象
      log.info("--- jedis close dataSource---");
      this.dataSource = null;
      if (client.isBroken()) {
        this.dataSource.returnBrokenResource(this);
      } else {
        this.dataSource.returnResource(this);
      }
    } else {
      super.close();
    }
  }
```
ab并发调用接口，获取日志文件。笔者压测50个并发，总数1000个，ab脚本如下
```shell
❯ ab -n 1000 -c 50 -p postOrg_data.txt -T 'application/json' localhost:28080/schedual/postOrg/countDistinctByRangeDateAndOrgId
```
jedis配置如下
```yaml
         jedis:
                pool:
                    # 连接池中的最小空闲连接
                    min-idle: 1
                    # 连接池中的最大空闲连接
                    max-idle: 2
                    # 连接池的最大数据库连接数
                    max-active: 2
```
压测后，调用接口，查看是否接口报错，若无报错，可适当调整并发数。

笔者在压测后，调用接口，已不可用，并报无法从redis连接池拿到连接`Could not get a resource from the pool`

最终观察日志，你会发现`连接已获得的次数=连接已释放的次数=jedis jar close func的次数`，而这些次数 - (max-idle)刚好是`jedis close dataSource的次数`。

也就是说在整个压测过程中，虽然连接似乎被释放了，但所创建的对象，并未回收。也就证明了，连接创建对象存在泄漏。

## 探究
通过日志，我们大致可以确定是`this.dataSource`出现了为null的情况，那么我们仔细寻找`dataSource`是在哪里被设置值，又是哪里被释放的

被赋予值
```java
  @Override
  public Jedis getResource() {
    Jedis jedis = super.getResource();
    // 设置dataSource
    jedis.setDataSource(this); // <-- This line 
    return jedis;
  }
```
释放值
```java
@Override
public void close() {
    if (dataSource != null) {
        if (client.isBroken()) {
            this.dataSource.returnBrokenResource(this);
        } else {
            this.dataSource.returnResource(this);
        }
        this.dataSource = null;  // <-- This line 
    } else {
        super.close();
    }
}
```
1. 当线程A归还对象后，但还未运行至`this.dataSource = null`
2. 线程B借了对象之后，并且设置了`dataSource`
3. 然后线程A运行至`this.dataSource = null`
4. 最后线程B永远无法归还对象，因为`dataSource`为null了

其实这个问题早被提出了，参考 [issue-1920][issue1920]。

这个bug也在[这段代码][bug-fix]中被修复了，所以升级jedis版本，你主要关注此段代码就可以了。

> 你是否有这样的疑问，为什么不使用原子性去控制该变量

关于这个问题，其实也有讨论，参考[fix-1920][issue-dis]

> 大致就是作者觉得`returnBrokenResource/returnResource`是有锁控制的，不需要再额外去做原子性了。具体怎么控制，读者可以自行研究。


[maven-dep]: ../tool/maven-dependency
[issue1920]: https://hub.nuaa.cf/redis/jedis/issues/1920
[bug-fix]: https://hub.nuaa.cf/redis/jedis/pull/1918/commits/df1bffa3c77f4ede4c912f2c3e78b5c8857725e7
[issue-dis]: https://hub.nuaa.cf/redis/jedis/commit/02f2cc5cce2f44efeaaafe351a2facf66988ddbf#diff-df2421269af8d142bf842cb0141f3a95R3639