#!/usr/bin/env ruby
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'rubygems'
require 'bundler'
Bundler.require
require 'tempfile'

require './settings.rb'

# === DataMapper Setup === #
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite:test.sqlite')
DataMapper::Model.raise_on_save_failure = true
DataMapper::Property::String.length(255)
#DataMapper::Logger.new($stdout, :debug)

class Post
  include DataMapper::Resource
  default_scope(:default).update(:order => [:id.asc])

  property :id, Serial

  property :post_id, String, :required => true
  property :title, String, :required => true
  property :post_time, DateTime

  property :author, String, :required => true
  property :author_id, String, :required => true

  property :content, Text
  property :post_hash, String

  property :pictures_count, Integer, :default => 0

  property :published, Boolean, :default  => false
  property :send_status, Boolean, :default => false

  property :created_at, DateTime

  property :deleted_at, ParanoidDateTime
  property :deleted, ParanoidBoolean, :default => false

  belongs_to :group, :required => false
  has n, :pictures, :through => Resource

  def to_s
    "[%s] %s %s %-40s\t- %s:%s" % [self.post_time, self.post_id, self.post_hash, self.title[0..20], self.author_id, self.author]
  end

  def post_url
    "https://www.douban.com/group/topic/#{self.post_id}/"
  end

  def author_url
    "https://www.douban.com/people/#{self.author_id}/"
  end
end

class Group
  include DataMapper::Resource

  property :id, Serial

  property :doubangroup_id, String, :default => "407518"

  property :doubangroup_name, String

  property :created_at, DateTime

  has n, :posts
end

class Picture
  include DataMapper::Resource
  default_scope(:default).update(:order => [:id.asc])

  property :id, Serial

  property :url, String

  property :md5, String
  property :ext, String, :default => "jpg"
  property :path, String

  property :deleted_at, ParanoidDateTime
  property :deleted, ParanoidBoolean, :default => false

  property :created_at, DateTime

  has n, :posts, :through => Resource

  has n, :tags, :through => Resource

  def to_s
    self.url
  end

  def access_url
    # "#{HOST_IMG}/files/pictures/#{self.url.split('?', 2)[0].split('/')[-1]}"
    # "%s/images/%s.%s" % [HOST_IMG, self.md5, self.ext]
    "%s%s" % [HOST_IMG, self.path]
  end

  def access_url_resize(width=320, height=480)
    # "#{HOST_IMG}/resize/files/pictures/#{self.url.split('?', 2)[0].split('/')[-1]}?width=#{width}&height=#{height}"
    self.access_url
  end
end

class Tag
  include DataMapper::Resource
  default_scope(:default).update(:order => [:id.asc])

  property :id, Serial
  property :name, String

  has n, :pictures, :through => Resource
end

DataMapper.finalize
DataMapper.auto_upgrade!
# === end DataMapper === #

IMGTAG_LIST = IMGTAGS.map {|tag| Tag.first_or_create(:name => tag)}

if File.exists?('mail.yml')
  options = YAML.load_file('mail.yml')

  Mail.defaults do
    delivery_method :smtp, options
  end
end
