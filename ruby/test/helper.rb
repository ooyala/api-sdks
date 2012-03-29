require 'rubygems'
require 'simplecov'

SimpleCov.start do
  add_filter 'vendor'
end if ENV["COVERAGE"]

require File.join(File.dirname(__FILE__), '..', 'ooyala_api')

require 'test/unit'
require 'rr'
