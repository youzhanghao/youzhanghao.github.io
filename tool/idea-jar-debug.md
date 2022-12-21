---
title: Idea中引入源码包调试
---
{% include common/rest/variables.liquid %}

# Idea中引入源码包调试

## 写在前面

以下内容为笔者实践而来，并结合自己的推测整理。若有不对或疏漏的欢迎交流。

本文以commons-pool为例，介绍如何在Idea中进行源码修改调试。

## 第一种方式

###  原理

将源码以module的形式引入，idea中识别module高于仓库jar，但module引入只限于同级。
  > 优点：修改后运行即可查看
  >
  >  缺点：module有层级限制，且有可能未运行module中的源码包。

### 步骤

1.GitHub上找寻源代码[commons-pool](https://github.com/apache/commons-pool.git)，
Idea->New project from version controll

  > 若未识别maven项目，手动add framework support。已识别则忽略此步骤。

2.打开引用了`commons-pool`依赖的项目，操作`File->New module from existing resource`。将源码包以`module`形式引入。
   
  > 注意：保持引入的module在idea中的显示为同级别module。存在父子module引用，如下图，你需要保证引入的module也在同一级，否则可能仍不是以源码包运行。

  <img src="{{ base_image_url }}/module-parent.png" alt="image.png" style="zoom: 50%;margin:0px" />

> 笔者试验当前idea只能引入到与父级同级别，尝试将子module作为单独项目打开引入并运行，如下图，若子module无需依赖其他module，可以运行，但有其他子module依赖，容易报错。若项目只依赖第三方包，可尝试此方法。

<img src="{{ base_image_url }}/module-sub.png" alt="image.png" style="zoom:50%;margin:0px" />

3.验证

引入以后，右边菜单栏->reimporty依赖->找到引用了依赖包处，点击，查看是否跳转到引入的源码中；需要注意的是，此处验证即使能跳转，也有可能还是使用了原先的依赖包中，具体以运行时，断点是否能进入引入的源码包中为准；

## 第二种方式
### 原理
本地编译覆盖同组织版本号jar包。
> 优点：保证运行的即为修改的代码，一般不会有什么奇怪错误产生。
> 
> 缺点，需重新clean install。

### 步骤
1. 拉取源码
2. 本地maven clean install
3. 项目中reimport
4. 验证
>  1. 修改源码，项目中点击应用源码包处，验证否跳转的对应的修改处。
>  
>  2. 可以从本地仓库中解压对应jar包，查看修改处
>  
> 注意：版本号要与引入的版本对齐