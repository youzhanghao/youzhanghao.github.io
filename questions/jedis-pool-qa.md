---

---

# Timeout waiting for idle object

> 以下内容为笔者实践而来，并结合自己的推测整理。若有不对或疏漏的欢迎指出交流。

##  问题引出
> 现象：某次高并发过后，应用系统部分接口仍旧出现系统异常。查看应用日志，初步推断为redis连接池问题，查看grafana中的redis监控，redis客户端连接数较少

![在这里插入图片描述](https://img-blog.csdnimg.cn/c427ca0068cc4e62bd64276104e8b8a0.png#pic_left)

临时快速解决方法：**<font color="red">重启应用</font>**

Ps: 重启大法好 --，--！

## 问题初探

### 初步排查
1. 拉取生产应用日志

    ![在这里插入图片描述](https://img-blog.csdnimg.cn/4f1e5fe6f34944cb88e396bc5efb6c55.png#pic_left)

    ![在这里插入图片描述](https://img-blog.csdnimg.cn/acba83df83ca433ba73b38be14a44add.png#pic_left)


2. 根据日志，初步推测为redis连接池问题导致问题发生，查看生产Redis监控，发现Redis在高并发时间段，连接数较多，但对于redis服务端来说，仍在可控范围，并且在高峰过后，Redis连接已被释放。于是引出两个问题需要弄清
   
    > 1. 高峰时间段Redis服务端无问题，难道是Java应用的连接池满了？
    > 2. Redis连接释放后，为何还是无法从连接池中获取到对象？

### 问题复现
 使用ab作为模拟高并发工具。参考[ab简介与基本使用][ab]

 使用redis-stat实时监控redis服务端信息。参考[redis-stat简介与基本使用][redis-stat]

 应用debug，若应用部署在服务器，采用remote-debug形式。参考[Idea远程调试][idea-debug]

 步骤
  1. ab脚本50并发压测服务器，观察redis服务器情况(连接数)；服务器连接数达到应用Jedis-pool的配置的连接数；整体表现和生产相同；（由于仅限复现问题，适当调小Jedis配置）

     ```yaml
        spring
        redis:
           # 地址
           host: localhost
           # 端口，默认为6379
           port: 26379
           password: 3edcVFR$
           # 连接超时时间
           timeout: 10s
           jedis:
               pool:
                   # 连接池中的最小空闲连接
                   min-idle: 2
                   # 连接池中的最大空闲连接
                   max-idle: 6
                   # 连接池的最大数据库连接数
                   max-active: 6
                   # 连接池最大阻塞等待时间（使用负值表示没有限制）300ms
                   max-wait: 300
     ```

  2. 观察Redis服务端情况，表现和生产相同 
     ![在这里插入图片描述](https://img-blog.csdnimg.cn/990602aca60d4e99ae3db6a1efb22f53.png#pic_left)
  3. 请求相关接口，都已经表现为系统异常，并且redis服务端连接释放后，系统仍未恢复；和生产表现相同，至此，生产问题完全复现
     ![在这里插入图片描述](https://img-blog.csdnimg.cn/92ec44926473496e86b299b524d2b2a0.png#pic_left)



### 源码排查
 高并发接口中的代码，引用了@Cacheable(该注解请参考[@Cache部分源码解读][Cache])

_时序图参考_

![在这里插入图片描述](https://img-blog.csdnimg.cn/f92527d669cc4b659566d5f736ff19e0.jpeg#pic_center)

  ```java
  @Cacheable(value = "history")
  public Integer canDutyPersonNum(String orgCode, Integer jgsx) {
  // 省略
  }
  ```
 @Cacheable主要是通过CacheAspectSupport实现，处理流程大致为excute()->excute()->findCachedItem()->findInCaches()->Cache.ValueWrapper.doGet()

  ```java
    CacheAspectSupport.java	
      
   	@Nullable
  	protected Object execute(CacheOperationInvoker invoker, Object target, Method method, Object[] args) {
  		// Check whether aspect is enabled (to cope with cases where the AJ is pulled in automatically)
  		if (this.initialized) {
  			Class<?> targetClass = getTargetClass(target);
  			CacheOperationSource cacheOperationSource = getCacheOperationSource();
  			if (cacheOperationSource != null) {
  				Collection<CacheOperation> operations = cacheOperationSource.getCacheOperations(method, targetClass);
  				if (!CollectionUtils.isEmpty(operations)) {
  					return execute(invoker, method,
  							new CacheOperationContexts(operations, method, args, target, targetClass));
  				}
  			}
  		}
  
  		return invoker.invoke();
  	}
  
  // ...
  
  @Nullable
  	private Object execute(final CacheOperationInvoker invoker, Method method, CacheOperationContexts contexts) {
  		// Special handling of synchronized invocation
  		if (contexts.isSynchronized()) {
  			CacheOperationContext context = contexts.get(CacheableOperation.class).iterator().next();
  			if (isConditionPassing(context, CacheOperationExpressionEvaluator.NO_RESULT)) {
  				Object key = generateKey(context, CacheOperationExpressionEvaluator.NO_RESULT);
  				Cache cache = context.getCaches().iterator().next();
  				try {
  					return wrapCacheValue(method, cache.get(key, () -> unwrapReturnValue(invokeOperation(invoker))));
  				}
  				catch (Cache.ValueRetrievalException ex) {
  					// The invoker wraps any Throwable in a ThrowableWrapper instance so we
  					// can just make sure that one bubbles up the stack.
  					throw (CacheOperationInvoker.ThrowableWrapper) ex.getCause();
  				}
  			}
  			else {
  				// No caching required, only call the underlying method
  				return invokeOperation(invoker);
  			}
  		}
  
  
  		// Process any early evictions
  		processCacheEvicts(contexts.get(CacheEvictOperation.class), true,
  				CacheOperationExpressionEvaluator.NO_RESULT);
  
  		// Check if we have a cached item matching the conditions
  		Cache.ValueWrapper cacheHit = findCachedItem(contexts.get(CacheableOperation.class));
  }
  
  	@Nullable
  	private Cache.ValueWrapper findCachedItem(Collection<CacheOperationContext> contexts) {
  		Object result = CacheOperationExpressionEvaluator.NO_RESULT;
  		for (CacheOperationContext context : contexts) {
  			if (isConditionPassing(context, result)) {
  				Object key = generateKey(context, result);
  				Cache.ValueWrapper cached = findInCaches(context, key);
  				if (cached != null) {
  					return cached;
  				}
  				else {
  					if (logger.isTraceEnabled()) {
  						logger.trace("No cache entry for key '" + key + "' in cache(s) " + context.getCacheNames());
  					}
  				}
  			}
  		}
  		return null;
  	}
  
  	@Nullable
  	private Cache.ValueWrapper findInCaches(CacheOperationContext context, Object key) {
  		for (Cache cache : context.getCaches()) {
  			Cache.ValueWrapper wrapper = doGet(cache, key);
  			if (wrapper != null) {
  				if (logger.isTraceEnabled()) {
  					logger.trace("Cache entry for key '" + key + "' found in cache '" + cache.getName() + "'");
  				}
  				return wrapper;
  			}
  		}
  		return null;
  	}
  
  ```

  ```java
  AbstractCacheInvoker.java
    	@Nullable
  	protected Cache.ValueWrapper doGet(Cache cache, Object key) {
  		try {
  			return cache.get(key);
  		}
  		catch (RuntimeException ex) {
  			getErrorHandler().handleCacheGetError(ex, cache, key);
  			return null;  // If the exception is handled, return a cache miss
  		}
  	}
  ```

 Cache.ValueWrapper.doGet()->Cache.get()  Cache为interface，查看Cache的实现图，判断为AbstractValueAdaptingCache的实现。若无法判断为哪一个类的执行，则可通过debug定位追踪

<img src="https://img-blog.csdnimg.cn/bf9d79297801470b9dfc6bf683766b05.png#pic_left&width=100" alt="在这里插入图片描述" style="zoom:50%;" />
    
![在这里插入图片描述](https://img-blog.csdnimg.cn/0b1c72807c484fdb8432bb4355e6b716.png#pic_left)


```java
Cache.java
  
ValueWrapper get(Object key);
```

```java
  RedisCache.java
    
  @Override
  @SuppressWarnings("unchecked")
  @Nullable
  public <T> T get(Object key, @Nullable Class<T> type) {
    Object value = fromStoreValue(lookup(key));
    if (value != null && type != null && !type.isInstance(value)) {
      throw new IllegalStateException(
          "Cached value is not of required type [" + type.getName() + "]: " + value);
    }
    return (T) value;
  }
```

 Cache.get()->AbstractValueAdaptingCache.get()->fromStoreValue(lookup(key))->lookup() lookup的实现如图，其采用的方法为RedisCache
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/2a22d44fb517423f8ea046f0c8ed0bb2.png#pic_left)


  ```java
  RedisCache.java
  
    @Override
    protected Object lookup(Object key) {
  
      byte[] value = cacheWriter.get(name, createAndConvertCacheKey(key));
  
      if (value == null) {
        return null;
      }
  
      return deserializeCacheValue(value);
    }
  ```

 RedisCache.lookup()->cacheWriter.get() cacheWriter(RedisCacheWriter)的实现默认只有一个DefaultRedisCacheWriter，IRedisCacheWriter为笔者添加的

  ![在这里插入图片描述](https://img-blog.csdnimg.cn/a534282e95fb4ba5b5d9d2a0ca24aa91.png#pic_left)

  ```java
    DefaultRedisCacheWriter.java
        @Override
        public byte[] get(String name, byte[] key) {
        
            Assert.notNull(name, "Name must not be null!");
      Assert.notNull(key, "Key must not be null!");
  
          return execute(name, connection -> connection.get(key));
          }
    
  
  private <T> T execute(String name, Function<RedisConnection, T> callback) {
          
              RedisConnection connection = connectionFactory.getConnection();
          try {
          
                  checkAndPotentiallyWaitUntilUnlocked(name, connection);
                  return callback.apply(connection);
              } finally {
              connection.close();
          }
          }
  ```
DefaultRedisCacheWriter.get()->execute()->connectionFactory.getConnection()   connectionFactory默认实现有两个，JedisSelfConnectionFactory为笔者实现的，该处为JedisConnectionFactory

_JedisConnectionFactory时序图参考_

![在这里插入图片描述](https://img-blog.csdnimg.cn/f2845e727cb94bb08de954fd2ba01b3d.jpeg#pic_center)

  ![在这里插入图片描述](https://img-blog.csdnimg.cn/4ff20337c2bf4c8097dac530226c797e.png#pic_left)


 JedisConnectionFactory.getConnection()->fetchJedisConnector()->pool.getResource()
  ```java
  	JedisConnectionFactory.java
  public RedisConnection getConnection() {
  
  	if (isRedisClusterAware()) {
  		return getClusterConnection();
  	}
  	
  	Jedis jedis = fetchJedisConnector();
  	String clientName = clientConfiguration.getClientName().orElse(null);
  JedisConnection connection = (getUsePool() ? new JedisConnection(jedis, pool, getDatabase(), clientName)
  			: new JedisConnection(jedis, null, getDatabase(), clientName));
  	connection.setConvertPipelineAndTxResults(convertPipelineAndTxResults);
  return postProcessConnection(connection);
  }
  
  protected Jedis fetchJedisConnector() {
  try {
  
  		if (getUsePool() && pool != null) {
  			return pool.getResource();
  	}
  	
  		Jedis jedis = createJedis();
  		// force initialization (see Jedis issue #82)
  		jedis.connect();
  	
  		potentiallySetClientName(jedis);
  		return jedis;
  } catch (Exception ex) {
  	throw new RedisConnectionFailureException("Cannot get Jedis connection", ex);
  }
  }
  ```

 pool.getResource() pool有三个子类实现，该处为JedisPool，pool.getResource()->GenericObjectPool.borrowObject() 在该方法中，我们看到了底层堆栈抛出的异常“Timeout waiting for idle object” 至此，整个源码过程追踪完毕，这也符合我们从日志中查看到的堆栈信息。那么现在的问题核心就是分析GenericObjectPool.borrowObject()中异常为何抛出了。

  ![在这里插入图片描述](https://img-blog.csdnimg.cn/6dec3f8404bd40658b3bb565ed4c4219.png#pic_left)

  ```java
  Pool.java
  public T getResource() {
    try {
      return internalPool.borrowObject();
    } catch (NoSuchElementException nse) {
      throw new JedisException("Could not get a resource from the pool", nse);
    } catch (Exception e) {
      throw new JedisConnectionException("Could not get a resource from the pool", e);
    }
  }
  ```

  ```java
GenericObjectPool.java
  @Override
  public T borrowObject() throws Exception {
      return borrowObject(getMaxWaitMillis());
  }
  
   public T borrowObject(final long borrowMaxWaitMillis) throws Exception {
          assertOpen();
  
          final AbandonedConfig ac = this.abandonedConfig;
          if (ac != null && ac.getRemoveAbandonedOnBorrow() &&
                  (getNumIdle() < 2) &&
                  (getNumActive() > getMaxTotal() - 3) ) {
              removeAbandoned(ac);
          }
      
          PooledObject<T> p = null;
      
          // Get local copy of current config so it is consistent for entire
          // method execution
          final boolean blockWhenExhausted = getBlockWhenExhausted();
      
          boolean create;
          final long waitTime = System.currentTimeMillis();
      
          while (p == null) {
              create = false;
              p = idleObjects.pollFirst();
              if (p == null) {
                  p = create();
                  if (p != null) {
                      create = true;
                  }
              }
              if (blockWhenExhausted) {
                  if (p == null) {
                      if (borrowMaxWaitMillis < 0) {
                          p = idleObjects.takeFirst();
                      } else {
                          p = idleObjects.pollFirst(borrowMaxWaitMillis,
                                  TimeUnit.MILLISECONDS);
                      }
                  }
                  if (p == null) {
                      throw new NoSuchElementException(
                              "Timeout waiting for idle object");
                  }
              } else {
                  if (p == null) {
                      throw new NoSuchElementException("Pool exhausted");
                  }
              }
              if (!p.allocate()) {
                  p = null;
              }
      
              if (p != null) {
                  try {
                      factory.activateObject(p);
                  } catch (final Exception e) {
                      try {
                          destroy(p);
                      } catch (final Exception e1) {
                          // Ignore - activation failure is more important
                      }
                      p = null;
                      if (create) {
                          final NoSuchElementException nsee = new NoSuchElementException(
                                  "Unable to activate object");
                          nsee.initCause(e);
                          throw nsee;
                      }
                  }
                  if (p != null && (getTestOnBorrow() || create && getTestOnCreate())) {
                      boolean validate = false;
                      Throwable validationThrowable = null;
                      try {
                          validate = factory.validateObject(p);
                      } catch (final Throwable t) {
                          PoolUtils.checkRethrow(t);
                          validationThrowable = t;
                      }
                      if (!validate) {
                          try {
                              destroy(p);
                              destroyedByBorrowValidationCount.incrementAndGet();
                          } catch (final Exception e) {
                              // Ignore - validation failure is more important
                          }
                          p = null;
                          if (create) {
                              final NoSuchElementException nsee = new NoSuchElementException(
                                      "Unable to validate object");
                              nsee.initCause(validationThrowable);
                              throw nsee;
                          }
                      }
                  }
              }
          }
      
          updateStatsBorrow(p, System.currentTimeMillis() - waitTime);
      
          return p.getObject();
      }
  ```

 分析抛出异常的代码块，Debug到该段代码块

```java
GenericObjectPool.borrowObject()        
if (blockWhenExhausted) {
            if (p == null) {
                if (borrowMaxWaitMillis < 0) {
                    // 空闲队列中获取空闲对象 一直等待 
                    p = idleObjects.takeFirst();
                } else {
                    // 等待borrowMaxWaitMillis ms后,放弃 该参数即对应redis中的配置 max-wait
                    p = idleObjects.pollFirst(borrowMaxWaitMillis,
                            TimeUnit.MILLISECONDS);
                }
            }
            if (p == null) {
                throw new NoSuchElementException(
                        "Timeout waiting for idle object");
            }
        }
```

  ![在这里插入图片描述](https://img-blog.csdnimg.cn/5012d288b2a74bc4a86cdec8890e15f4.png#pic_left)
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/4e9b0dff532e4360b597f51a8d420325.png#pic_left)


> 观察发现，该对象中的allObject已经都是被分配(ALLOCATED)状态，因此当程序继续请求，都将报错。

> 也许你有这样的疑问，程序已经不在使用redis连接池中的连接，而且Redis服务端也显示客户端未占用连接来，为何应用中对象未被释放，reidis中不是默认会有闲时检测么（关于redis的配置参考[Redis配置解读][Redis-config]），我们进一步探究

 reidis中的闲时检测，是基于BaseGenericObjectPool.java中的定时线程实现，主要关注evict()方法

  ```java
  BaseGenericObjectPool.java
  /**
       * The idle object evictor {@link TimerTask}.
       *
       * @see GenericKeyedObjectPool#setTimeBetweenEvictionRunsMillis
       */
      class Evictor implements Runnable {
  
          private ScheduledFuture<?> scheduledFuture;
  
          /**
           * Run pool maintenance.  Evict objects qualifying for eviction and then
           * ensure that the minimum number of idle instances are available.
           * Since the Timer that invokes Evictors is shared for all Pools but
           * pools may exist in different class loaders, the Evictor ensures that
           * any actions taken are under the class loader of the factory
           * associated with the pool.
           */
          @Override
          public void run() {
              final ClassLoader savedClassLoader =
                      Thread.currentThread().getContextClassLoader();
              try {
                  if (factoryClassLoader != null) {
                      // Set the class loader for the factory
                      final ClassLoader cl = factoryClassLoader.get();
                      if (cl == null) {
                          // The pool has been dereferenced and the class loader
                          // GC'd. Cancel this timer so the pool can be GC'd as
                          // well.
                          cancel();
                          return;
                      }
                      Thread.currentThread().setContextClassLoader(cl);
                  }
  
                  // Evict from the pool
                  try {
                      evict();
                  } catch(final Exception e) {
                      swallowException(e);
                  } catch(final OutOfMemoryError oome) {
                      // Log problem but give evictor thread a chance to continue
                      // in case error is recoverable
                      oome.printStackTrace(System.err);
                  }
                  // Re-create idle instances.
                  try {
                      ensureMinIdle();
                  } catch (final Exception e) {
                      swallowException(e);
                  }
              } finally {
                  // Restore the previous CCL
                  Thread.currentThread().setContextClassLoader(savedClassLoader);
              }
          }
  
  
          void setScheduledFuture(final ScheduledFuture<?> scheduledFuture) {
              this.scheduledFuture = scheduledFuture;
          }
  
  
          void cancel() {
              scheduledFuture.cancel(false);
          }
      }
  ```

evict()方法中，我们发现第一步的清理基于有空闲对象的基础上执行，而在上述Debug过程中，我们发现borrowObject已经无空闲资源了，因此对象无法被触发回收。
还有一个清理对象是基于AbandonConfig进行的。针对此配置下面叙述。

```java
GenericObjectPool.java
public void evict() throws Exception {
    assertOpen();

    if (idleObjects.size() > 0) {
  
        PooledObject<T> underTest = null;
        final EvictionPolicy<T> evictionPolicy = getEvictionPolicy();
  
        synchronized (evictionLock) {
            final EvictionConfig evictionConfig = new EvictionConfig(
                    getMinEvictableIdleTimeMillis(),
                    getSoftMinEvictableIdleTimeMillis(),
                    getMinIdle());
  
            final boolean testWhileIdle = getTestWhileIdle();
  
            for (int i = 0, m = getNumTests(); i < m; i++) {
                if (evictionIterator == null || !evictionIterator.hasNext()) {
                    evictionIterator = new EvictionIterator(idleObjects);
                }
                if (!evictionIterator.hasNext()) {
                    // Pool exhausted, nothing to do here
                    return;
                }
  
                try {
                    underTest = evictionIterator.next();
                } catch (final NoSuchElementException nsee) {
                    // Object was borrowed in another thread
                    // Don't count this as an eviction test so reduce i;
                    i--;
                    evictionIterator = null;
                    continue;
                }
  
                if (!underTest.startEvictionTest()) {
                    // Object was borrowed in another thread
                    // Don't count this as an eviction test so reduce i;
                    i--;
                    continue;
                }
  
                // User provided eviction policy could throw all sorts of
                // crazy exceptions. Protect against such an exception
                // killing the eviction thread.
                boolean evict;
                try {
                    evict = evictionPolicy.evict(evictionConfig, underTest,
                            idleObjects.size());
                } catch (final Throwable t) {
                    // Slightly convoluted as SwallowedExceptionListener
                    // uses Exception rather than Throwable
                    PoolUtils.checkRethrow(t);
                    swallowException(new Exception(t));
                    // Don't evict on error conditions
                    evict = false;
                }
  
                if (evict) {
                    destroy(underTest);
                    destroyedByEvictorCount.incrementAndGet();
                } else {
                    if (testWhileIdle) {
                        boolean active = false;
                        try {
                            factory.activateObject(underTest);
                            active = true;
                        } catch (final Exception e) {
                            destroy(underTest);
                            destroyedByEvictorCount.incrementAndGet();
                        }
                        if (active) {
                            if (!factory.validateObject(underTest)) {
                                destroy(underTest);
                                destroyedByEvictorCount.incrementAndGet();
                            } else {
                                try {
                                    factory.passivateObject(underTest);
                                } catch (final Exception e) {
                                    destroy(underTest);
                                    destroyedByEvictorCount.incrementAndGet();
                                }
                            }
                        }
                    }
                    if (!underTest.endEvictionTest(idleObjects)) {
                        // TODO - May need to add code here once additional
                        // states are used
                    }
                }
            }
        }
    }
    final AbandonedConfig ac = this.abandonedConfig;
    if (ac != null && ac.getRemoveAbandonedOnMaintenance()) {
        removeAbandoned(ac);
    }
}
```
  <img src="https://img-blog.csdnimg.cn/6696d8523c7a4c6ebceb08e7f60d4727.png#pic_center" alt="在这里插入图片描述" style="zoom: 33%;" />


### 初步总结

> 通过Debug，我们推断问题的发生是GenericObjectPool的allObject都已经处于Allocated状态，导致异常抛出。那么要解决该问题，可以通过触发释放对象。当然这仅仅是针对问题，解决表象的思路。
>
> **<font color=red>2022-12-16补充：</font>**也许你还有这样的疑问：既然连接未创建成功，这些被分配的对象又是如何来的？这些对象创建后，又是哪里被回收或者丢弃的？
>
> 答：我们分析源码得知在connectionFactory获取connection过程中，若使用连接池，会使用GenericObjectPool.borrowObject()，只有成功获取对象，才认为连接创建成功，从而执行命令，关闭连接，并返还或销毁对象，执行JedisConnection.close()->jedis.close()方法；而在2.9.1版本中jedis.close()方法是存在jedis对象泄漏的，关于泄漏问题，请参考[低版本中Jedis对象泄漏证明及探究][jedis-pool]。
>
> Ps: 在之前的分析中，未深入分析Jedis对象泄漏问题，因此临时通过AbandonConfig配置，主动释放对象。

那么我们有没有其他方法进行设置，触发释放呢？ 

关注两块代码 borrowObject()和evict()方法中都有 AbandonedConfig这个配置；关于这个配置可以阅读源码注释；这是个能在获取连接的时候就进行分配对象舍弃的设置。

  ```java
        GenericObjectPool.java  
        public T borrowObject(final long borrowMaxWaitMillis) throws Exception {
            assertOpen();
  
            final AbandonedConfig ac = this.abandonedConfig;
            if (ac != null && ac.getRemoveAbandonedOnBorrow() &&
                    (getNumIdle() < 2) &&
                    (getNumActive() > getMaxTotal() - 3) ) {
                removeAbandoned(ac);
            }
            // ...
        }
        @Override
        public void evict() throws Exception {
          // ...
            final AbandonedConfig ac = this.abandonedConfig;
            if (ac != null && ac.getRemoveAbandonedOnMaintenance()) {
                removeAbandoned(ac);
            }
        }
  ```

直接修改此段代码，给AbandonConfig赋值。关于如何修改依赖jar的源码请参考[IDEA引入源码包修改调试][idea-jar-debug]

按相同的并发操作步骤，仅给AbandonConfig赋值，测试问题是否可以得到解决；测试结果如下图，可以发现，程序进入后释放了占用对象，并在并发结束后，仍能正常提供服务。
  ```java
  AbandonedConfig abandonedConfig = new AbandonedConfig();
  abandonedConfig.setLogAbandoned(true);
  abandonedConfig.setRemoveAbandonedOnBorrow(true);
  ```

<img src="https://img-blog.csdnimg.cn/b55eec738ab144e48ce3ef3c8b803959.png#pic_left" alt="在这里插入图片描述" style="zoom:50%;margin:0px" />


> redis为何未暴露AandonConfig配置，请参考[Redis配置解读][Redis-config]； 

> 简单说明，3版本Jedis未提供设置方法，4版本提供，但需要SpringBoot同步升级到3版本以上，且该配置通过pool对象设置

引申的问题：若我们强制给AbandonConfig赋值，是否合理，会有什么弊端？

## 解决方案
1. 升级Jedis版本 **<font color=red>推荐</font>** jedis版本要3.6.0以上，主要关注源码包中下面代码

   ```java
     @Override
     public void close() {
       if (dataSource != null) {
         JedisPoolAbstract pool = this.dataSource;
         this.dataSource = null;
         if (isBroken()) {
           pool.returnBrokenResource(this);
         } else {
           pool.returnResource(this);
         }
       } else {
         super.close();
       }
     }
   ```

   官方网址：[jedis-3.6.0][jedis-3.6]

   **注：**若你使用springboot配套的spring-data-redis，需要注意依赖的版本问题。关于如何查看项目依赖，请参考[maven依赖][maven-dep]

2. 源码修改编译
   拉取Jedis源码包，修改Pool的构造方法，使其支持Abandon Config设置，重新编译，生成定制版的jar。

    > 优点：可自定义程度高，甚至可以将原先仅支持几个配置的pool，完全置于配置文件中；同时其他的操作都可以共享该配置。
    >
    > 缺点：每次redis升级都得适配

    参考[redis-abandon-config](https://github.com/redis/jedis/compare/master...venukbh:jedis:jedis-pool-with-abandon-config)

3. 重写connection方法
   仅修改CachaAspectSupport相关，通过自定义实现RedisCacheWriter，重写其connection()方法

    > 优点：不影响源码包，后续升级不受影响
    >
    > 缺点：代码显得冗余，容易造成使用误解或干扰，重新执行了一次创建pool的流程，且redis其他使用pool的地方仍旧使用原先的pool，可以理解为维护了两套pool

      ```java
      package com.kaizhi.cache;
      
      import com.kaizhi.scheduling.config.JedisSelfFactory;
      import lombok.extern.slf4j.Slf4j;
      
      import org.apache.commons.pool2.impl.AbandonedConfig;
      import org.apache.commons.pool2.impl.GenericObjectPool;
      import org.apache.commons.pool2.impl.GenericObjectPoolConfig;
      import org.springframework.dao.PessimisticLockingFailureException;
      import org.springframework.data.redis.cache.RedisCacheWriter;
      import org.springframework.data.redis.connection.RedisConnection;
      import org.springframework.data.redis.connection.RedisConnectionFactory;
      import org.springframework.data.redis.connection.RedisStringCommands;
      import org.springframework.data.redis.connection.jedis.JedisClientConfiguration;
      import org.springframework.data.redis.connection.jedis.JedisConnection;
      import org.springframework.data.redis.connection.jedis.JedisConnectionFactory;
      import org.springframework.data.redis.core.types.Expiration;
      import org.springframework.lang.Nullable;
      import org.springframework.util.Assert;
      import redis.clients.jedis.Jedis;
      import redis.clients.jedis.JedisPool;
      import redis.clients.jedis.Protocol;
      import redis.clients.jedis.exceptions.JedisConnectionException;
      import redis.clients.jedis.exceptions.JedisException;
      import redis.clients.util.Pool;
      
      import java.nio.charset.StandardCharsets;
      import java.time.Duration;
      import java.util.Collections;
      import java.util.NoSuchElementException;
      import java.util.Optional;
      import java.util.concurrent.TimeUnit;
      import java.util.function.Consumer;
      import java.util.function.Function;
      
      /**
       * @Author: youzhanghao
       * @ClassName: IRedisCacheWriter
       * @Date: 2022-11-29 10:01:14
       * @email: m13732916591_1@163.com
       * @Description: 
       * @Version: 1.0
       */
      @Slf4j
      public class IRedisCacheWriter implements RedisCacheWriter {
      
          private final RedisConnectionFactory connectionFactory;
          private final Duration sleepTime;
      
      
          /**
           * @param connectionFactory must not be {@literal null}.
           */
          public IRedisCacheWriter (RedisConnectionFactory connectionFactory) {
              this(connectionFactory, Duration.ZERO);
          }
      
          public IRedisCacheWriter (JedisConnectionFactory connectionFactory) {
              this(connectionFactory, Duration.ZERO);
          }
      
          /**
           * @param connectionFactory must not be {@literal null}.
           * @param sleepTime sleep time between lock request attempts. Must not be {@literal null}. Use {@link Duration#ZERO}
           *          to disable locking.
           */
          public IRedisCacheWriter (RedisConnectionFactory connectionFactory, Duration sleepTime) {
      
              Assert.notNull(connectionFactory, "ConnectionFactory must not be null!");
              Assert.notNull(sleepTime, "SleepTime must not be null!");
      
              this.connectionFactory = connectionFactory;
              this.sleepTime = sleepTime;
          }
      
          /*
           * (non-Javadoc)
           * @see org.springframework.data.redis.cache.RedisCacheWriter#put(java.lang.String, byte[], byte[], java.time.Duration)
           */
          @Override
          public void put(String name, byte[] key, byte[] value, @Nullable Duration ttl) {
      
              Assert.notNull(name, "Name must not be null!");
              Assert.notNull(key, "Key must not be null!");
              Assert.notNull(value, "Value must not be null!");
      
              execute(name, connection -> {
      
                  if (shouldExpireWithin(ttl)) {
                      connection.set(key, value, Expiration.from(ttl.toMillis(), TimeUnit.MILLISECONDS), RedisStringCommands.SetOption.upsert());
                  } else {
                      connection.set(key, value);
                  }
      
                  return "OK";
              });
          }
      
          /*
           * (non-Javadoc)
           * @see org.springframework.data.redis.cache.RedisCacheWriter#get(java.lang.String, byte[])
           */
          @Override
          public byte[] get(String name, byte[] key) {
      
              Assert.notNull(name, "Name must not be null!");
              Assert.notNull(key, "Key must not be null!");
      
              return execute(name, connection -> connection.get(key));
          }
      
          /*
           * (non-Javadoc)
           * @see org.springframework.data.redis.cache.RedisCacheWriter#putIfAbsent(java.lang.String, byte[], byte[], java.time.Duration)
           */
          @Override
          public byte[] putIfAbsent(String name, byte[] key, byte[] value, @Nullable Duration ttl) {
      
              Assert.notNull(name, "Name must not be null!");
              Assert.notNull(key, "Key must not be null!");
              Assert.notNull(value, "Value must not be null!");
      
              return execute(name, connection -> {
      
                  if (isLockingCacheWriter()) {
                      doLock(name, connection);
                  }
      
                  try {
                      if (connection.setNX(key, value)) {
      
                          if (shouldExpireWithin(ttl)) {
                              connection.pExpire(key, ttl.toMillis());
                          }
                          return null;
                      }
      
                      return connection.get(key);
                  } finally {
      
                      if (isLockingCacheWriter()) {
                          doUnlock(name, connection);
                      }
                  }
              });
          }
      
          /*
           * (non-Javadoc)
           * @see org.springframework.data.redis.cache.RedisCacheWriter#remove(java.lang.String, byte[])
           */
          @Override
          public void remove(String name, byte[] key) {
      
              Assert.notNull(name, "Name must not be null!");
              Assert.notNull(key, "Key must not be null!");
      
              execute(name, connection -> connection.del(key));
          }
      
          /*
           * (non-Javadoc)
           * @see org.springframework.data.redis.cache.RedisCacheWriter#clean(java.lang.String, byte[])
           */
          @Override
          public void clean(String name, byte[] pattern) {
      
              Assert.notNull(name, "Name must not be null!");
              Assert.notNull(pattern, "Pattern must not be null!");
      
              execute(name, connection -> {
      
                  boolean wasLocked = false;
      
                  try {
      
                      if (isLockingCacheWriter()) {
                          doLock(name, connection);
                          wasLocked = true;
                      }
      
                      //使用scan命令代替keys命令
                      Cursor<byte[]> cursor = connection.scan(new ScanOptions.ScanOptionsBuilder().match(new String(pattern)).count(1000).build());
                      Set<byte[]> byteSet = new HashSet<>();
                      while (cursor.hasNext()) {
                          byteSet.add(cursor.next());
                      }
      
                      byte[][] keys = byteSet.toArray(new byte[0][]);
      
                      if (keys.length > 0) {
                          connection.del(keys);
                      }
                  } finally {
      
                      if (wasLocked && isLockingCacheWriter()) {
                          doUnlock(name, connection);
                      }
                  }
      
                  return "OK";
              });
          }
      
      
      
          /**
           * Explicitly set a write lock on a cache.
           *
           * @param name the name of the cache to lock.
           */
          void lock(String name) {
              execute(name, connection -> doLock(name, connection));
          }
      
          /**
           * Explicitly remove a write lock from a cache.
           *
           * @param name the name of the cache to unlock.
           */
          void unlock(String name) {
              executeLockFree(connection -> doUnlock(name, connection));
          }
      
          private Boolean doLock(String name, RedisConnection connection) {
              return connection.setNX(createCacheLockKey(name), new byte[0]);
          }
      
          private Long doUnlock(String name, RedisConnection connection) {
              return connection.del(createCacheLockKey(name));
          }
      
          boolean doCheckLock(String name, RedisConnection connection) {
              return connection.exists(createCacheLockKey(name));
          }
      
          /**
           * @return {@literal true} if {@link RedisCacheWriter} uses locks.
           */
          private boolean isLockingCacheWriter() {
              return !sleepTime.isZero() && !sleepTime.isNegative();
          }
      
          private <T> T execute(String name, Function<RedisConnection, T> callback) {
              RedisConnection connection = null;
              try {
                  JedisConnectionFactory jedisConnectionFactory = (JedisConnectionFactory) connectionFactory;
                  connection = getConnection(jedisConnectionFactory);
                  // connection = connectionFactory.getConnection();
                  checkAndPotentiallyWaitUntilUnlocked(name, connection);
                  return callback.apply(connection);
              } finally {
                  if(connection !=null){
                      connection.close();
                  }
              }
          }
      
          public RedisConnection getConnection(JedisConnectionFactory connectionFactory) {
      
              if (connectionFactory.isRedisClusterAware()) {
                  return connectionFactory.getClusterConnection();
              }
      
              GenericObjectPoolConfig poolConfig = connectionFactory.getPoolConfig() ;
              AbandonedConfig abandonedConfig = new AbandonedConfig();
              abandonedConfig.setLogAbandoned(true);
              abandonedConfig.setRemoveAbandonedOnBorrow(true);
              GenericObjectPool<Jedis> pool = new GenericObjectPool<Jedis>(new JedisSelfFactory(connectionFactory.getHostName(), connectionFactory.getPort(), Protocol.DEFAULT_TIMEOUT, Protocol.DEFAULT_TIMEOUT ,
                      connectionFactory.getPassword(), connectionFactory.getDatabase(), "test", connectionFactory.isUseSsl(), null, null, null), poolConfig,abandonedConfig);
              Pool<Jedis> jedisPool = createRedisPool(connectionFactory);
              Jedis jedis;
              try {
                  jedis = pool.borrowObject();
              } catch (NoSuchElementException nse) {
                  throw new JedisException("Could not get a resource from the pool", nse);
              } catch (Exception e) {
                  throw new JedisConnectionException("Could not get a resource from the pool", e);
              }
              JedisConnection connection = (connectionFactory.getUsePool() ? new JedisConnection(jedis, jedisPool, connectionFactory.getDatabase())
                      : new JedisConnection(jedis, null, connectionFactory.getDatabase()));
              return connection;
          }
      
          protected Pool<Jedis> createRedisPool(JedisConnectionFactory jedisConnectionFactory) {
              JedisClientConfiguration clientConfiguration = jedisConnectionFactory.getClientConfiguration();
              return new JedisPool(jedisConnectionFactory.getPoolConfig(), jedisConnectionFactory.getHostName(), jedisConnectionFactory.getPort(),getConnectTimeout(clientConfiguration), getReadTimeout(clientConfiguration),
                      jedisConnectionFactory.getPassword(),jedisConnectionFactory.getDatabase(), jedisConnectionFactory.getClientName(), jedisConnectionFactory.isUseSsl(),
                      clientConfiguration.getSslSocketFactory().orElse(null), //
                      clientConfiguration.getSslParameters().orElse(null), //
                      clientConfiguration.getHostnameVerifier().orElse(null));
          }
      
          private int getConnectTimeout(JedisClientConfiguration clientConfiguration) {
              return Math.toIntExact(clientConfiguration.getConnectTimeout().toMillis());
          }
      
          private int getReadTimeout(JedisClientConfiguration clientConfiguration) {
              return Math.toIntExact(clientConfiguration.getReadTimeout().toMillis());
          }
      
      
      
          private void executeLockFree(Consumer<RedisConnection> callback) {
      
              RedisConnection connection = connectionFactory.getConnection();
      
              try {
                  callback.accept(connection);
              } finally {
                  connection.close();
              }
          }
      
          private void checkAndPotentiallyWaitUntilUnlocked(String name, RedisConnection connection) {
      
              if (!isLockingCacheWriter()) {
                  return;
              }
      
              try {
      
                  while (doCheckLock(name, connection)) {
                      Thread.sleep(sleepTime.toMillis());
                  }
              } catch (InterruptedException ex) {
      
                  // Re-interrupt current thread, to allow other participants to react.
                  Thread.currentThread().interrupt();
      
                  throw new PessimisticLockingFailureException(String.format("Interrupted while waiting to unlock cache %s", name),
                          ex);
              }
          }
      
          private static boolean shouldExpireWithin(@Nullable Duration ttl) {
              return ttl != null && !ttl.isZero() && !ttl.isNegative();
          }
      
          private static byte[] createCacheLockKey(String name) {
              return (name + "~lock").getBytes(StandardCharsets.UTF_8);
          }
      
      
      }
      
      ```

      ```java
      public class JedisSelfFactory  implements PooledObjectFactory<Jedis> {
          private final AtomicReference<HostAndPort> hostAndPort = new AtomicReference<HostAndPort>();
          private final int connectionTimeout;
          private final int soTimeout;
          private final String password;
          private final int database;
          private final String clientName;
          private final boolean ssl;
          private final SSLSocketFactory sslSocketFactory;
          private SSLParameters sslParameters;
          private HostnameVerifier hostnameVerifier;
      
          public JedisSelfFactory(final String host, final int port, final int connectionTimeout,
                              final int soTimeout, final String password, final int database, final String clientName,
                              final boolean ssl, final SSLSocketFactory sslSocketFactory, final SSLParameters sslParameters,
                              final HostnameVerifier hostnameVerifier) {
              this.hostAndPort.set(new HostAndPort(host, port));
              this.connectionTimeout = connectionTimeout;
              this.soTimeout = soTimeout;
              this.password = password;
              this.database = database;
              this.clientName = clientName;
              this.ssl = ssl;
              this.sslSocketFactory = sslSocketFactory;
              this.sslParameters = sslParameters;
              this.hostnameVerifier = hostnameVerifier;
          }
      
          public JedisSelfFactory(final URI uri, final int connectionTimeout, final int soTimeout,
                              final String clientName, final boolean ssl, final SSLSocketFactory sslSocketFactory,
                              final SSLParameters sslParameters, final HostnameVerifier hostnameVerifier) {
              if (!JedisURIHelper.isValid(uri)) {
                  throw new InvalidURIException(String.format(
                          "Cannot open Redis connection due invalid URI. %s", uri.toString()));
              }
      
              this.hostAndPort.set(new HostAndPort(uri.getHost(), uri.getPort()));
              this.connectionTimeout = connectionTimeout;
              this.soTimeout = soTimeout;
              this.password = JedisURIHelper.getPassword(uri);
              this.database = JedisURIHelper.getDBIndex(uri);
              this.clientName = clientName;
              this.ssl = ssl;
              this.sslSocketFactory = sslSocketFactory;
              this.sslParameters = sslParameters;
              this.hostnameVerifier = hostnameVerifier;
          }
      
          public void setHostAndPort(final HostAndPort hostAndPort) {
              this.hostAndPort.set(hostAndPort);
          }
      
          @Override
          public void activateObject(PooledObject<Jedis> pooledJedis) throws Exception {
              final BinaryJedis jedis = pooledJedis.getObject();
              if (jedis.getDB() != database) {
                  jedis.select(database);
              }
      
          }
      
          @Override
          public void destroyObject(PooledObject<Jedis> pooledJedis) throws Exception {
              final BinaryJedis jedis = pooledJedis.getObject();
              if (jedis.isConnected()) {
                  try {
                      try {
                          jedis.quit();
                      } catch (Exception e) {
                      }
                      jedis.disconnect();
                  } catch (Exception e) {
      
                  }
              }
      
          }
      
          @Override
          public PooledObject<Jedis> makeObject() throws Exception {
              final HostAndPort hostAndPort = this.hostAndPort.get();
              final Jedis jedis = new Jedis(hostAndPort.getHost(), hostAndPort.getPort(), connectionTimeout,
                      soTimeout, ssl, sslSocketFactory, sslParameters, hostnameVerifier);
      
              try {
                  jedis.connect();
                  if (password != null) {
                      jedis.auth(password);
                  }
                  if (database != 0) {
                      jedis.select(database);
                  }
                  if (clientName != null) {
                      jedis.clientSetname(clientName);
                  }
              } catch (JedisException je) {
                  jedis.close();
                  throw je;
              }
      
              return new DefaultPooledObject<Jedis>(jedis);
      
          }
      
          @Override
          public void passivateObject(PooledObject<Jedis> pooledJedis) throws Exception {
              // TODO maybe should select db 0? Not sure right now.
          }
      
          @Override
          public boolean validateObject(PooledObject<Jedis> pooledJedis) {
              final BinaryJedis jedis = pooledJedis.getObject();
              try {
                  HostAndPort hostAndPort = this.hostAndPort.get();
      
                  String connectionHost = jedis.getClient().getHost();
                  int connectionPort = jedis.getClient().getPort();
      
                  return hostAndPort.getHost().equals(connectionHost)
                          && hostAndPort.getPort() == connectionPort && jedis.isConnected()
                          && jedis.ping().equals("PONG");
              } catch (final Exception e) {
                  return false;
              }
          }
      }
      ```

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

4. 调整参数；通过源码分析，其是由于在规定时间内未借用到空闲对象，导致异常抛出。
    若业务本身不复杂，直接调整max-wait参数           
   ```yaml
   spring:
     redis:
       jedis:
         pool:
           # 连接池最大阻塞等待时间（使用负值表示没有限制）默认是300ms
           max-wait: 300
   ```

## 复盘总结

> 上述的解决方法，后两种核心思想都是设置AbandonConfig，主动释放对象，可能会造成其他正在使用的连接被强制释放，设置需根据具体业务来综合判断。推荐通过升级版本来解决，若实在不能升级版本，可以通过修改jedis.close()方法，参考 [Move dataSource reset before connection returned][jedis-pool-bug]
>

[ab]: ../tool/ab.md
[redis-stat]: ../tool/redis-stat
[idea-debug]: ../tool/idea-remote-debug
[Cache]: http://t.csdn.cn/J1Mgt
[Redis-config]: http://t.csdn.cn/J1Mgt
[idea-jar-debug]: ../tool/idea-jar-debug
[jedis-pool]: ../java/jedis-pool
[jedis-pool-bug]: https://hub.nuaa.cf/redis/jedis/pull/1918/commits/df1bffa3c77f4ede4c912f2c3e78b5c8857725e7
[jedis-3.6]:https://hub.nuaa.cf/redis/jedis/blob/jedis-3.6.0/src/main/java/redis/clients/jedis/Jedis.java
[maven-dep]: ../tool/maven-dependency

