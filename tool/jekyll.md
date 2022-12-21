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
## Jekyll主题应用

> 以jekyll-rtd-theme为例

1.github中找到喜欢的主题，将其推送至你的仓库，你的仓库名应该为`yourname/youname.github.io`

> 你可以通过fork的形式，或clone下来推送至你的项目
> 
> 注意：阅读主题的说明文件，将有助于你避免不必要的麻烦

2.依据你的需要修改配置文件

> 参考配置文件

`Gemfile`

```Gemfile
source "https://rubygems.org" # source "https://gems.ruby-china.com"

gemspec

# github pages
gem "github-pages", group: :jekyll_plugins

# 时间插件
group :jekyll_plugins do
  gem "jekyll-last-modified-at"
end
```
`_config.yml`

```yaml
title: Youzhanghao's Blog
description: Record Something
author: youzhanghao
# 主题
theme: jekyll-rtd-theme
# 编码
encoding: utf-8
# 时区
timezone: Asia/Shanghai

# debug是否开启
#debug:
# compress: true
# dist: false
# shortcodes: true

readme_index:
  with_frontmatter: true
# 应用插件
plugins:
  - jemoji
  - jekyll-avatar
  - jekyll-mentions
  - jekyll-last-modified-at
# 排除在外的打包文件
exclude:
  - Makefile
  - CNAME
  - LICENSE
  - update.sh
  - Gemfile
  - Gemfile.lock
  - requirements.txt
  - node_modules
  - package.json
  - package-lock.json
  - webpack.config.js
  - jekyll-rtd-theme.gemspec
  - test

# Optional. The default date format, used if none is specified in the tag.
last-modified-at:
  date-format: '%Y-%m-%d %H:%M:%S'
  use-git-cache: true
```
3.拓展修改

> 以添加创建时间和更新时间为例

修改`_includes/templates/content.liquid`
```html
{% raw %}
<div class="content p-3 p-sm-5">
        {% include templates/breadcrumbs.liquid %}
        <hr>
        {% include common/rest/variables.liquid param="schema_date"  %}
        <p><em >发布时间：{{ schema_date | date:"%Y-%m-%d %H:%M:%S" }}</em>
            <em style="float:right">更新时间：{% last_modified_at %}</em></p>
        <div role="main" itemscope="itemscope" itemtype="https://schema.org/Article">
            <div class="markdown-body" itemprop="articleBody">
                {{ content }}
            </div>
        </div>
        {% include templates/footer.liquid %}
    </div>
{% endraw %}
```
4.可能的问题

在markdown文件里无法使用page变量等
> 可能和编译的先后顺序有关，暂未定为根本原因，可以通过引入variable中的变量来使用，添加如下：
> {% raw %}
> {% include common/rest/variables.liquid param="schema_date"  %}
> {% endraw %}

5.延伸阅读

[Github page的配置和快速发布][github-config]

[jekyll-config]: /others/jekyll-install
[github-config]: /others/github-push