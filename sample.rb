#!/usr/bin/ruby1.9.3

require './twitter/collector'
require './twitter/utils'
require 'set'

@data_dir = 'data/sample'
@topics = ARGV

OAuthConfig = {
  :consumer_key => "consumer key",
  :consumer_secret => "consumer secret",
  :access_token => "access token",
  :access_token_secret => "access token secret"
}

EventMachine.run do
  trap("INT") do
    write_status(nil)
    EventMachine.stop
  end

  @twitter = Twitter::Collector.new(OAuthConfig)
  @twitter.sample do |status|
    handle_status(status)
  end
end

