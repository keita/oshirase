#!/usr/bin/env ruby

$KCODE = "UTF-8"

require "rss/1.0"
require "rubygems"
require "open-uri"
require "starruby"
require "net/flickr"
require "thread"
require "tempfile"
require "simple_http"
require "RMagick"

include StarRuby

$flickr = Net::Flickr.new("c1119364ed4fd3f81f2998a3846b307d")

class Headline
  def self.fontname=(name)
    @@fontname = name
  end

  attr_accessor :time

  def initialize(item)
    @title = item.title
    #@date = date
    @font_size = 35
    @line_height = @font_size + 2
    @font = Font.new(@@fontname, @font_size)
    @bg = Color.new(30, 30, 30)
    @fg = Color.new(255, 255, 255)
  end

  def texture
    lines = @title.split(/＝|−/)
    width = lines.inject(0) do |max, line|
      w = @font.get_size(line)[0]
      max > w ? max : w
    end
    tt = Texture.new(width, lines.size*@line_height)
    tt.fill(@bg)
    lines.each_with_index do |line, idx|
      tt.render_text(line, 0, idx*@line_height, @font, @fg, true)
    end
    return tt
  end
end

# make headlines
Headline.fontname = "IPAfont/ipam.ttf"

URL = "http://www.jiji.com/rss/ranking.rdf"
$headlines = Queue.new

Thread.new do
  loop do
    if $headlines.size < 3
      RSS::Parser.parse(open(URL)).items.map do |item|
        $headlines.push Headline.new(item)
      end
    else
      sleep 1
    end
  end
end

# make backgrounds
$backgrounds = Queue.new
Thread.new do
  loop do
    if $backgrounds.size < 3
      $flickr.photos.search("tags" => "cat", "per_page" => 5).each do |photo|
        tmp = Tempfile.new("oshirase")
        tmp.close
        img = Magick::Image.from_blob(SimpleHttp.get(photo.source_url)).first
        img.format = "PNG"
        img.write(tmp.path)
        $backgrounds << tmp
      end
    else
      sleep 1
    end
  end
end

Game.title = "Oshirase"

Game.run(640, 480, :fullscreen => (ARGV[0] == "f")) do
  Game.terminate if Input.keys(:keyboard).include?(:escape)
  Game.screen.save("out.png") if Input.keys(:keyboard).include?(:s)
  Game.screen.instance_eval do
    if !$current or Game.ticks - $current.time > 1000 * 10
      clear
      width, height = size
      bg = Texture.load($backgrounds.pop.path)
      render_texture(bg,
                     (width - bg.width)/2,
                     (height - bg.height)/2)
      $current = $headlines.pop
      $current.time = Game.ticks
      tt = $current.texture
      render_texture(tt,
                     (width - tt.width) / 2,
                     (height - tt.height) / 2,
                     :alpha => 180)
    end
  end
end
