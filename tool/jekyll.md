---

---

# Jekyll
> 本文是基于Github博客安装的

## Mac安装Jekyll

### 安装ruby

Mac自带的ruby，默认为2.6.0，通过以下命令安装的默认为3.0版本 (2022-12-16)

```shell
$ brew install ruby
```

注：版本号可通过 `ruby -v`查看，若命令无法识别，查看是否在环境变量中配置

我们需要安装的是2.7版本

> GithubPages目前对Jekyll4.0以上支持不是很友好，所以通过安装ruby2.7版本可以规避一下不必要的问题

```shell
$ brew install ruby@2.7
```

下载后注意提示信息

```shell
If you need to have ruby first in your PATH run:# 环境变量配置
  echo 'export PATH="/usr/local/opt/ruby@2.7/bin:$PATH"' >> ~/.bash_profile

For compilers to find ruby you may need to set: # 编译中使用哪个版本
  export LDFLAGS="-L/usr/local/opt/ruby@2.7/lib"
  export CPPFLAGS="-I/usr/local/opt/ruby@2.7/include"

For pkg-config to find ruby you may need to set:# 包配置
  export PKG_CONFIG_PATH="/usr/local/opt/ruby@2.7/lib/pkgconfig"
```

依据提示设置环境变量

```shell
# 环境变量设置 你可能还会设置在 ~/.zshrc 
# 设置之后生效。你的文件若是.zshrc  则source ~/.zshrc
$ source ~/.bash_profile 
# 设置完后，查看gem
$ gem env
RubyGems Environment:
  - RUBYGEMS VERSION: 3.3.26
  - RUBY VERSION: 2.7.7 (2022-11-24 patchlevel 221) [x86_64-darwin21]
  - INSTALLATION DIRECTORY: /usr/local/lib/ruby/gems/2.7.0
  - USER INSTALLATION DIRECTORY: /Users/zhanghaoyou/.gem/ruby/2.7.0
  - RUBY EXECUTABLE: /usr/local/opt/ruby@2.7/bin/ruby
  - GIT EXECUTABLE: /usr/bin/git
  - EXECUTABLE DIRECTORY: /usr/local/lib/ruby/gems/2.7.0/bin
  - SPEC CACHE DIRECTORY: /Users/zhanghaoyou/.gem/specs
  - SYSTEM CONFIGURATION DIRECTORY: /usr/local/Cellar/ruby@2.7/2.7.7/etc
  - RUBYGEMS PLATFORMS:
     - ruby
     - x86_64-darwin-21
  - GEM PATHS:
     - /usr/local/lib/ruby/gems/2.7.0
     - /Users/zhanghaoyou/.gem/ruby/2.7.0
     - /usr/local/Cellar/ruby@2.7/2.7.7/lib/ruby/gems/2.7.0
  - GEM CONFIGURATION:
     - :update_sources => true
     - :verbose => true
     - :backtrace => true
     - :bulk_threshold => 1000
  - REMOTE SOURCES:
     - https://rubygems.org/
  - SHELL PATH:
     - /usr/local/opt/ruby@2.7/bin
     - /Users/zhanghaoyou/.nvm/versions/node/v14.20.0/bin
     - /usr/local/bin
     - /usr/local/sbin
     - /usr/local/bin
     - /usr/bin
     - /bin
     - /usr/sbin
     - /sbin
     - /usr/local/scala/bin
     - /Users/zhanghaoyou/Library/Android/sdk/platform-tools
     - /Users/zhanghaoyou/Library/Android/sdk/ndk-bundle
     - /Library/Java/JavaVirtualMachines/jdk1.8.0_321.jdk/Contents/Home/bin
```
注：INSTALLATION DIRECTORY 该目录有可能不是你的安装目录，gem install的时候注意查看

### 安装bundle

```shell
$ gem install bundle
# 若你想通过gem直接安装jekyll，也是可以的，但是建议通过在github博客中的Gemfile配置
# 你的jekyll版本会根据ruby编译的版本寻找，若是4.0之上版本，可能会带来一些不必要的麻烦
$ gem install jekyll
# 默认安装的jekyll不在环境变量中 需到gem安装的目录下找到对应的安装包设置bin环境变量
$ jekyll -v
```
_更多参考[jekyll安装][jekyll-config]_

## Github中应用jekyll

> Github配置可查看官网或其他博客，以下介绍命令使用

将你的博客代码pull至本地，切换对应的工作目录
```shell
# 若你的目录下无Gemfile 执行以下命令 有则忽略
$ bundle init
# 创建后执行
$ bundle install 
```
> Gemfile文件内容参考，若初次使用直接使用默认配置，根据需要添加插件

```
# frozen_string_literal: true
source "https://rubygems.org"

# gem "rails"
gem "jekyll", "~> 3.9.0"
gem "webrick", "~> 1.7"
gem "github-pages", group: :jekyll_plugins
# gem 'jekyll-rtd-theme', '~> 2.0', '>= 2.0.10'
gem "minima"
```

通过bundle执行jekyll命令
```shell
# 清理
$ bundle exec jekyll clean 
# 构建
$ bundle exec jekyll build
# 启动
$ bundle exec jekyll server
```
_若觉得麻烦，可自行定义快捷方式_

[jekyll-config]: /others/jekyll-install