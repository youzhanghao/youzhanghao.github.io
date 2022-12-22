# Github Pages

## Github 配置
![config][github-config]
## Github 推送
```shell
# 进入到项目目录
# 切换到对应分支 不建议于master修改，切一个隶属于你自己的分支
❯ git checkout -b feature-name
# 添加subtree子仓库的目录 该目录无需事先创建 确保有权限创建目录
# 确保已有gh-pages分支，并将该分支内容清空  
# 参考命令
# git checkout gh-pages
# git rm -r --cached * && git commit -m "init gh-pages" && git push 
# 第一次需要执 subtree add，docs目录要被git跟踪
❯ git subtree add --prefix=docs origin gh-pages
git fetch origin gh-pages
From github.com:youzhanghao/youzhanghao.github.io
 * branch            gh-pages   -> FETCH_HEAD
Added dir 'docs'
# 编译生成_site 内容 _site不被git跟踪
❯ bundle exec jekyll build
# 将内容拷贝到docs
❯ cp -r  _site/* docs/
# 本地内容提交到仓库
❯ git commit -m"init pages" && git push
# docs文件夹内容推到gh-pages
# 若提示需要先pull更新，执行以下命令
# git subtree pull --prefix=docs origin gh-pages
# 若提示需要合并，命令末尾添加 --squash
#  git subtree pull -P docs origin gh-pages --squash -d
❯ git subtree push --prefix=docs origin gh-pages
# 注：每个命令执行，注意查看输出 subtree 添加 -d 开启debug
# 若要删除subtree，直接删除对应目录，并commit
```
[github-config]:  /assets/images/github-config.png