

# Jekyll安装
## 安装ruby

Mac自带的ruby，默认为2.6.0，无法满足要求，需要安装3.0以上版本

   ```shell
   brew install ruby
   ```

注：版本号可通过 `ruby -v`查看，若命令无法识别，查看是否在环境变量中配置

## 安装Jekyll

```shell
gem install jekyll bundler
```

注：验证gem是否安装正确，可以查看对应目录

```shell
❯ ls  ~/.gem/ruby/
2.6.0 3.0.0
❯ ls ~/.gem/ruby/3.0.0/bin
bundle  bundler jekyll
```

设置环境变量

```
echo `export PATH=$PATH:$HOME/.gem/ruby/3.0.0/bin` ~/.bash_profile
source ~/.bash_profile
```

注：无`.bash_profile`自行创建，或者创建软链到该目录，或者直接切到该目录执行(如果不嫌麻烦)。

## 验证

```shell
❯ jekyll -v
jekyll 4.3.1
```

## 可能遇到的问题
[gem安装扩展失败][1]

[cannot load such file – webrick][2]

注：ruby配置脚本说明

```shell
ruby is keg-only, which means it was not symlinked into /usr/local,
because macOS already provides this software and installing another version in
parallel can cause all kinds of trouble.

If you need to have ruby first in your PATH run:
  echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >> ~/.bash_profile

For compilers to find ruby you may need to set: 编译中使用
  export LDFLAGS="-L/usr/local/opt/ruby/lib"
  export CPPFLAGS="-I/usr/local/opt/ruby/include"

For pkg-config to find ruby you may need to set:
  export PKG_CONFIG_PATH="/usr/local/opt/ruby/lib/pkgconfig"
```



[1]:https://hub.nuaa.cf/ffi/ffi/issues/653
[2]:https://talk.jekyllrb.com/t/load-error-cannot-load-such-file-webrick/5417