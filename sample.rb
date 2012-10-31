#!/usr/bin/env ruby

require './twitter/collector'
require './twitter/utils'
require 'set'

@data_dir = 'data/sample'
@topics = ARGV

OAuthConfig = load_credentials

EventMachine.run do
  trap("INT") do
    close_file(nil)
    EventMachine.stop
  end

  @twitter = Twitter::Collector.new(OAuthConfig)
  @twitter.sample do |status|
    handle_status(status)
  end
end

