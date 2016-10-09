#!/usr/bin/env ruby -w
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require './common.rb'
require './app.rb'

require 'rack/cache'

use Rack::Cache,
  :metastore   => 'file:/tmp/rack_meta',
  :entitystore => 'file:/tmp/rack_body',
  :verbose     => false

run AppController
