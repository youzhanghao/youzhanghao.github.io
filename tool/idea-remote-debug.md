---

---
# Idea远程调试
1. 运行程序处->Edit Configurations，如下图

	<img src="https://img-blog.csdnimg.cn/55bfe368ed0745ceb299283affbd8b71.png#pic_left" alt="在这里插入图片描述" style="margin:0px;zoom:50%;"/>


2. 添加->Remote Jvm Debug
		![在这里插入图片描述](https://img-blog.csdnimg.cn/353363b4e5024e3ca89940c3428479fe.png#pic_center)

3. 粘贴下图中command line arguments追加至你的java启动命令，host为远程服务器地址，端口即参数中指定的端口号，保持一致。
		![在这里插入图片描述](https://img-blog.csdnimg.cn/169567c914a04ec9951411f7b4b7c483.png#pic_center)

> 启动脚本参考

```shell
nohup java -jar    
-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=35005   
-Djava.rmi.server.hostname=172.21.62.11 
-Dcom.sun.management.jmxremote=true  
-Dcom.sun.management.jmxremote.port=33346  
-Dcom.sun.management.jmxremote.authenticate=false  
-Dcom.sun.management.jmxremote.ssl=false -Xss512k -Xmx4g -Xms4g 
-XX:+UseG1GC  
-XX:G1HeapRegionSize=4M -Xloggc:log/gc-%t.log -XX:+UseGCLogFileRotation  
-XX:NumberOfGCLogFiles=14 -XX:GCLogFileSize=100M  
-Dspring.profiles.active=dev *.jar  > log/qw-daily.log 2>&1 &
```