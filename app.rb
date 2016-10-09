#!/usr/bin/env ruby
# encoding: utf-8
require 'json'

class AppController < Sinatra::Base
  enable :sessions

  configure {
    set :server, :puma
    set :static_cache_control, [:public, :max_age => 864000]
  }

  before {
    #cache_control :public, :must_revalidate, :max_age => 60
  }

  get '/' do
    cache_control :public, :max_age => 36000
    'Voo Girl!'
  end

  get '/status' do
    'OK'
  end
  head '/status' do
    'OK'
  end

  ['/admin/posts/:per_page/:compare/:from', '/admin/posts/:per_page/:compare/'].each do |loc|
    get loc do
      cache_control :public, :must_revalidate, :max_age => 0

      @admin = true
      @total_posts_count = Post.count(:pictures_count.gt => 0)
      @per_page = params[:per_page].to_i
      @first = Post.first ? Post.first.id : 0
      @last = Post.last ? Post.last.id : 0

      if params[:from]
        @compare, @order = {
          'older' => ['lt', 'desc'],
          'newer' => ['gt', 'asc']
        }[params[:compare]]
        @from = params[:from].to_i
      else
        @compare, @order, @from = {
          'older' => ['gte', 'asc', 0],
          'newer' => ['lte', 'desc', @last]
        }[params[:compare]]
      end

      @posts = Post.all(:pictures_count.gt => 0, :id.send(@compare) => @from, :order => [:id.send(@order), :created_at.send(@order)], :limit => @per_page)

      @max = @posts.map{|post| post.id}.max
      @min = @posts.map{|post| post.id}.min

      if @posts.size >= 1
        haml :admin_cur
      elsif @total_posts_count >= 1
        redirect to("/admin/posts/#{@per_page}/#{params[:compare]}/")
      else
        "no posts"
      end
    end
  end

  ['/admin/pictures/:per_page/:compare/:from', '/admin/pictures/:per_page/:compare/'].each do |loc|
    get loc do
      cache_control :public, :must_revalidate, :max_age => 0

      @admin = true
      @total_pictures_count = Picture.count
      @per_page = params[:per_page].to_i
      @first = Picture.first ? Picture.first.id : 0
      @last = Picture.last ? Picture.last.id : 0

      if params[:from]
        @compare, @order = {
          'older' => ['lt', 'desc'],
          'newer' => ['gt', 'asc']
        }[params[:compare]]
        @from = params[:from].to_i
      else
        @compare, @order, @from = {
          'older' => ['gte', 'asc', 0],
          'newer' => ['lte', 'desc', @last]
        }[params[:compare]]
      end

      @pictures = Picture.all(:id.send(@compare) => @from, :order => [:id.send(@order), :created_at.send(@order)], :limit => @per_page)

      @max = @pictures.map{|pic| pic.id}.max
      @min = @pictures.map{|pic| pic.id}.min

      if @pictures.size >= 1
        haml :admin_pictures
      elsif @total_pictures_count >= 1
        redirect to("/admin/pictures/#{@per_page}/#{params[:compare]}/")
      else
        "no pictures"
      end
    end
  end

  ['/pictures', '/pictures/tag/:tag'].each do |loc|
    get loc do
      @tag = Tag.get(params[:tag]) if params[:tag]
      if @tag
        @total_count = @tag.pictures.count
      else
        @total_count = Picture.count
      end
      @per_page = (params[:per_page] || 4*16).to_i
      @total_pages_count = @total_count > 0 ? ((@total_count - 1)/ @per_page) + 1 : 1

      page = (params[:page] || 1).to_i
      @page = (page - 1) % @total_pages_count + 1
      start = (@page - 1) * @per_page

      if @tag
        pictures = @tag.pictures(:picture_tags => {:tag => @tag}, :order => [:id.desc, :created_at.desc])
      else
        pictures = Picture.all(:order => [:id.desc, :created_at.desc])
      end

      @pictures = pictures[start, @per_page]

      haml :picture_list
    end
  end

  get '/admin/picture/:id/blacklist' do
    cache_control :public, :must_revalidate, :max_age => 0
    _tag = params['__tag'] || nil

    picture = Picture.get params[:id]
    posts = picture.posts

    picture.deleted = true
    picture.save

    posts.each do |post|
      post.update :pictures_count => post.pictures_count - 1
    end

    redirect "#{request.referrer}##{_tag}"
  end

  get '/admin/picture/:id/:tag/toggle_tag' do
    cache_control :public, :must_revalidate, :max_age => 0

    tag = Tag.get params[:tag]
    picture = Picture.get params[:id]

    link = picture.picture_tags.first(:tag => tag)
    if link
      link.destroy
    else
      picture.tags << tag
      picture.save
    end

    _tag = params['__tag'] || nil
    redirect "#{request.referrer}##{_tag}"
  end

  get '/admin/post/:post_id/:post_hash/mail' do
    post = Post.first(:post_id => params[:post_id], :post_hash => params[:post_hash])
    post_content = "#{post.content} \r\n #{post.post_url}"

    mail = Mail.new do
      from    'jiecao1024@gmail.com'
      to      'jiecaosuileyidi@googlegroups.com'
      message_id "%s.%s.1024@voogirl.com" % [post.post_id, post.post_hash]
      subject "[%s] %s - %s%s" % ['xsz', post.author, post.title, post.pictures.nil? ? '' : "[#{post.pictures.size}]" ]
      body    post_content
      post.pictures.each do |pic|
        file = pic.path
        add_file :filename => file, :content => File.read("./public#{file}")
        file = nil
      end
    end
    mail.header['References'] = "<%s.1024@voogirl.com>" % params[:post_id]
    mail.header['In-Reply-To'] = "<%s.1024@voogirl.com>" % params[:post_id]
    mail.deliver

    post.send_status = true
    post.save

    @post = post
    haml :post_mail
  end
end
