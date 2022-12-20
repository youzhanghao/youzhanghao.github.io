---

---
# ab

##  安装

```shell
$ brew install ab   
```

## 原理

   ab是apachebench命令的缩写，ab命令会创建多个并发访问线程，模拟多个访问者同时对某一URL地址进行访问。它的测试目标是基于URL的，因此，它既可以用来测试apache的负载压力，也可以测试nginx、lighthttp、tomcat、IIS等其它Web服务器的压力。

   ab命令对发出负载的计算机要求很低，它既不会占用很高CPU，也不会占用很多内存。但却会给目标服务器造成巨大的负载，其原理类似CC攻击。自己测试使用也需要注意，否则一次上太多的负载。可能造成目标服务器资源耗完，严重时甚至导致死机。

## 命令参数

   ```shell
   ab [可选的参数选项] 需要进行压力测试的url
   此外，我们再根据上面的用法介绍界面来详细了解每个参数选项的作用。
   -n 即requests，用于指定压力测试总共的执行次数。
   -c 即concurrency，用于指定的并发数。
   -t 即timelimit，等待响应的最大时间(单位：秒)。
   -b 即windowsize，TCP发送/接收的缓冲大小(单位：字节)。
   -p 即postfile，发送POST请求时需要上传的文件，此外还必须设置-T参数。
   -u 即putfile，发送PUT请求时需要上传的文件，此外还必须设置-T参数。
   -T 即content-type，用于设置Content-Type请求头信息，例如：application/x-www-form-urlencoded，默认值为text/plain。
   -v 即verbosity，指定打印帮助信息的冗余级别。
   -w 以HTML表格形式打印结果。
   -i 使用HEAD请求代替GET请求。
   -x 插入字符串作为table标签的属性。
   -y 插入字符串作为tr标签的属性。
   -z 插入字符串作为td标签的属性。
   -C 添加cookie信息，例如："Apache=1234"(可以重复该参数选项以添加多个)。
   -H 添加任意的请求头，例如："Accept-Encoding: gzip"，请求头将会添加在现有的多个请求头之后(可以重复该参数选项以添加多个)。
   -A 添加一个基本的网络认证信息，用户名和密码之间用英文冒号隔开。
   -P 添加一个基本的代理认证信息，用户名和密码之间用英文冒号隔开。
   -X 指定使用的和端口号，例如:"126.10.10.3:88"。
   -V 打印版本号并退出。
   -k 使用HTTP的KeepAlive特性。
   -k 使用HTTP的KeepAlive特性。
   -d 不显示百分比。
   -S 不显示预估和警告信息。
   -g 输出结果信息到gnuplot格式的文件中。
   -e 输出结果信息到CSV格式的文件中。
   -r 指定接收到错误信息时不退出程序。
   -h 显示用法信息，其实就是ab -help。
   虽然ab可以配置的参数选项比较多，但是，一般情况下我们只需要使用形如ab -n 数字 -c 数字 url路径的命令即可。譬如，我们对位于本地Apache服务器上、URL为localhost/index.的页面进行。测试总次数为1000，并发数为100(相当于100个用户同时访问，他们总共访问1000次)
   ```

## 应用

ab模拟post请求

```shell     
$ ab -n 100 -c 10 -v 4 -p 'rule-test.txt' -T 'application/json' 'http://10.19.248.200:32069/rule/getAction'
$ cat rule-test.txt
{
"eventId":"6000",
"eventValue":"上海市,上海市,杨浦区"
}
```
输出结果至html
```shell
$ ab -w -v 2 -n 100 -c 20 -p 'rule-test.txt' -T 'application/json' 'http://lk-rule-engine-qa.op.laikang.com/rule/getAction' > res.html
```