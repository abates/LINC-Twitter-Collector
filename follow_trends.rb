#!/usr/bin/env ruby

require './twitter/collector'
require './twitter/utils'
require 'set'

OAuthConfig = load_credentials

# where to store data
@data_dir = 'data/trends'

# how often to check for new trends
@trends_period = 300

# We only want to do r reconnects in a period p so we
# track every time we reconnect by pushing a time onto
# the topic_changes array.  We shift the oldest time 
# off if it is older then now - trend_windo (in seconds).
# We allow a maximum of trend_changes_allowed in the
# given window of time.  All of this is to prevent
# Twitter from rate limiting us
@trend_window = 600
@trend_changes_allowed = 3
@topics = Set.new

def fetch_trends
  @twitter.trends do |trends|
    puts '-------------------------------------'
    puts "#{Time.now}"

    topics_changed = false

    old_trends = @topics - trends
    old_trends.each do |trend|
      puts "No longer trendy: #{trend}"
      topics_changed = true
    end
  
    new_trends = trends - @topics
    new_trends.each do |trend|
      puts "New Trend: #{trend}"
      topics_changed = true
    end

    if (topics_changed)
      puts "Resetting stream feed"
      @topics = @topics - old_trends + new_trends

      @twitter.follow_trends @topics do |status|
        handle_status(status, @topics)
      end
    else
      puts 'No Changes to trending topics'
    end
    puts '-------------------------------------'

  end

end

EventMachine.run do
  trap("INT") do
    @topics.each do |trend|
      write_status(trend)
    end
    EventMachine.stop
  end

  @twitter = Twitter::Collector.new(OAuthConfig)
  fetch_trends
  EM.add_periodic_timer(@trends_period) do
    fetch_trends
  end
end

