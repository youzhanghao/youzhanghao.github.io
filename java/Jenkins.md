---
tilte: Jenkins
---

#  Jenkins

{% include common/rest/variables.liquid %}

## Jenkins安装
1. 包安装，注意配置文件
2. docker安装
> docker安装注意挂宿主机和特权模式配置，同时注意docker内部网络问题
> 
> docker构建jenkins主从节点，也要主要网络问题，尽量属于同一个--net下

3. 插件安装

	> 系统管理->插件管理

4. 从节点配置

	注：要安装ssh插件

	<img src="{{ base_image_url }}/jenkins-slave-config.png" alt="image.png" style="zoom:50%;margin:0px">



## Jenkins权限控制

1. 插件管理中-->安装role base插件，若因网络无法下载，可离线安装，也可以更换源

2. 系统管理-->全局安全配置-->保存
<img src="{{ base_image_url }}/jenkins-role-config.png" alt="image.png" style="zoom:50%;margin:0px">
3. 设置用户组-->设置角色和权限-->Manage Roles
	
	<img src="{{ base_image_url }}/jenkins-role-manager.png" alt="image.png" style="zoom:50%;margin:0px">

	注：请按如下基础设置
  > 给予基础read权限
  > 
  > 给予项目正则权限
  >
  > 项目或任务起名标准化，利于正则分权

	<img src="{{ base_image_url }}/jenkins-role-assign.png" alt="image.png" style="zoom:50%;margin:0px">

4. 用户管理

	> 可以通过用户注册
	> 用户栏基于项目--点击用户--设置--设置用户密码（设置即为注册）

	<img src="{{ base_image_url }}/jenkins-role-user.png" alt="image.png" style="zoom:50%;margin:0px">

	<img src="{{ base_image_url }}/jenkins-role-userMag.png" alt="image.png" style="zoom:50%;margin:0px">

	个人密码设置

	<img src="{{ base_image_url }}/jenkins-role-userpwd.png" alt="image.png" style="zoom:50%;margin:0px">

5. 权限分配

<img src="{{ base_image_url }}/jenkins-role-user-manager.png" alt="image.png" style="zoom:50%;margin:0px">

## Jenkins使用中的一些问题

###  配置的job后台运行的命令，执行完命令未在后台保持运行
参考官网：[ProcessTreeKiller][ProcessTreeKiller]
> BUILD_ID=dontKillMe nohup java -jar   -Xss512k -Xmx4g -Xms4g -XX:+UseG1GC -XX:G1HeapRegionSize=4M -Xloggc:log/gc-%t.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=14 -XX:GCLogFileSize=100M  -Dspring.profiles.active=dev qw-daily-scheduling.jar 

### Jenkins中Maven的错误


[ProcessTreeKiller]: https://wiki.jenkins-ci.org/display/JENKINS/ProcessTreeKiller

## 参考

### job配置

### docker持续化部署脚本
```shell
#!/usr/bin/env bash
# Written by youzhanghao

# Error code
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Jenkins
TAGS=`date +%Y%m%d.%H%I%S`
PROGRANME_PATH="$JOB_NAME"
STAGE=`echo ${JOB_NAME%%_*}|tr 'A-Z' 'a-z'`
MODULE=`echo ${JOB_NAME##*_}`
if [ $STAGE == $MODULE ]; then
    IMAGE="$MODULE"
else
    IMAGE="$MODULE-$STAGE"
fi
# Docker
DOCKER_USER='ggov'
DOCKER_PWD='!qaz2wsX'
# Author
PROGRAAME=$(basename $0)
RELEASE="Reversion 1.0"
AUTHOR="(c) 2018 Youzhanghao (youzhanghao003@gmail.com)"

# Function and Release
print_release() {
    echo "$RELEASE $AUTHOR"
}

print_usage() {
        echo ""
        echo "$PROGRAAME $RELEASE - Jenkins for CICD"
        echo ""
        echo "Usage: bash $0 <project-name> <options> <commands>"
        echo ""
        echo "project-name is the job name which you build and compile the source code"
        echo "  -s  jenkins job name that include project source code(default:current JOB_NAME) "
        echo "  -n  namespace which you want deploy for cicd,and it should be used with -d "
        echo "  -d  deployment which you want deploy for cicd,and it should be used with -n "
        echo "  -c  container which you want deploy for cicd(default:name of deployment)"
        echo "  -v  check the version"
        echo "  -h  Show this page"
        echo "  eg: bash $0 -s [test-project] -n g-laikang-sh-dev -d test-deployment -c test-container "
        echo ""
    echo "Usage: $PROGRAAME"
    echo "Usage: $PROGRAAME --help"
    echo ""
    exit 0
}

print_help() {
        print_usage
        echo ""
        echo "This plugin will help jenkins deployment"
        echo ""
        exit 0
}


# Parse parameters
while [ $# -lt 1 ]; do
    echo "You should give at least one param"
    print_usage
    exit $STATE_OK
done
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            print_help
            exit $STATE_OK
            ;;
        -v | --version)
            print_release
            exit $STATE_OK
            ;;
        -s | --stand)
            shift
            echo "---> start project module build ---"
            PROGRANME_PATH="$1/$MODULE"
            ;;
        -n | --namespace)
            shift
            namespace=$1
            ;;
        -d | --deployment)
            shift
            deployment=$1
            ;;
        -c | --container)
            shift
            container=$1
            ;;
        *)

        echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
        esac
shift
done
# docker
docker build --network=host -t 10.19.248.200:30100/g_laikang/$IMAGE:$TAGS -f /home/jenkins_home/workspace/$PROGRANME_PATH/Docker/Dockerfile /home/jenkins_home/workspace/$PROGRANME_PATH
err_code=`echo $?`
if [ $err_code -eq $STATE_OK ];then
    docker login -u="$DOCKER_USER" -p="$DOCKER_PWD" 10.19.248.200:30100
    err_code=`echo $?`
    if [ $err_code -eq $STATE_OK ];then
        docker push 10.19.248.200:30100/g_laikang/$IMAGE:$TAGS;
        err_code=`echo $?`
    fi
    if [ $err_code -ne $STATE_OK ];then
        echo "Unknown error: docker push failed project stop here"
        exit $STATE_WARNING
    fi
    if [ ! -n "$namespace" ] || [ ! -n "$deployment" ]; then
        echo 'Error: you should give both -n namespace and -d deployment '
        exit $STATE_WARNING
    else
        container=${container:-$deployment}
        echo "---> start update namespace:$namespace deployment:$deployment container:$container "
        ennctl -n $namespace set image deployment/$deployment  $container=10.19.248.200:30100/g_laikang/$IMAGE:$TAGS
    fi
fi


```
