time = Time.new
timestr = time.strftime("%Y-%m-%d-")
puts "title: "
title = gets.chomp!
puts "dir: "
dir = gets.chomp!
puts "tags: "
tags = gets.chomp!
str = <<here
---
layout: post
title: #{title}
modified:
categories: #{dir}
description:
tags: [#{tags}]
image:
  feature: abstract-5.jpg
  credit:
  creditlink:
comments: false
share: false
---
here

dir = File.join("_posts",dir)
puts dir
Dir.mkdir(dir) unless File.exist?(dir)
filename = File.join(dir,timestr + title + ".md")
File.open(filename,"w+"){|file|
  file.puts str
}