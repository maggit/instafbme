require 'rubygems'
require 'sinatra'
require 'nokogiri'
require 'i18n'
require 'json'
require 'instagram'

configure do
  @@config = YAML.load_file("lib/config.yml") rescue nil || {}
  require 'redis'
  redisUri = ENV["REDISTOGO_URL"] || @@config['REDISTOGO_URL']
  uri = URI.parse(redisUri) 
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  #require File.join(File.dirname(__FILE__), 'lib/models/user')
 
end

Instagram.configure do |config|
 config.client_id = @@config['INSTAGRAM_CLIENT_ID']
 config.client_secret = @@config['INSTAGRAM_CLIENT_SECRET']
end

before do
  @user = session[:user] if session[:user]
  @access_token = session[:access_token] if session[:access_token]
end


def get_or_post(path, opts={}, &block)
  get(path, opts, &block)
  post(path, opts, &block)
end

get_or_post '/' do
  @context = "index"
  @user =  session[:user]
  redirect '/feed' if @user
  
  unless REDIS.get("main_title")
    REDIS.set("main_title", "Comming soon!")
  end
  
  @test = REDIS.get("main_title")
  erb :index
end

get_or_post '/about' do
  @context = "about"
  erb :about
end


get "/oauth/connect" do
  redirect Instagram.authorize_url(:redirect_uri => @@config['INSTAGRAM_CALLBACK_URL'])
end

get "/oauth/callback" do
  response = Instagram.get_access_token(params[:code], :redirect_uri => @@config['INSTAGRAM_CALLBACK_URL'])
  session[:access_token] = response.access_token
  redirect "/feed"
end

get "/feed" do
  logger.info "@access_token = #{@access_token}"
  client = Instagram.client(:access_token => session[:access_token])
  user = client.user
  session[:user] = user
  session[:counts] = client.user.counts.media
  logger.info "received user = #{user}"
  logger.info "user recent media #{client.user_recent_media.inspect}"
  
  html = "<h1>#{user.username}'s recent photos</h1>"
  count = 0
  while count < session[:counts] do
    last = count == 0 ? client.user_recent_media(:count => 60).last : (session[:last] ? client.user_recent_media(:count => 60, :max_id => session[:last].id).last : nil)
    session[:last] = last
    if last and session[:last]
    for media_item in client.user_recent_media(:count => 60, :max_id => last.id)
      html << "<a href='#{media_item.images.standard_resolution.url}'><img src='#{media_item.images.thumbnail.url}'></a>"
      count += 1
    end
    end
  end
  html
end

get "/logout" do
  session[:user] = nil
  session[:access_token] = nil
  redirect "/"
end 