require 'rubygems'
require 'sinatra'
require './application.rb'

set :sessions, true
set :logging, true
set :dump_errors, true

run Sinatra::Application
