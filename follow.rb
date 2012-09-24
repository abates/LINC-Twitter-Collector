#!/usr/bin/env ruby

require 'twitter/collector'
require 'twitter/utils'
require 'set'

if (ARGV.length < 1)
  STDERR.print "usage: #{$0} <topic1> <topic2> <topic3> ...\n"
  exit -1
end

@data_dir = 'data/follow'
@topics = ARGV

OAuthConfig = {
  :consumer_key => "consumer key",
  :consumer_secret => "consumer secret",
  :access_token => "access token",
  :access_token_secret => "access token secret"
}

EventMachine.run do
  trap("INT") do
    ARGV.each do |topic|
      write_status(topic)
    end
    EventMachine.stop
  end

  @twitter = Twitter::Collector.new(OAuthConfig)
  @twitter.follow ARGV do |status|
    handle_status(status, ARGV)
  end
end
