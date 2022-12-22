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

