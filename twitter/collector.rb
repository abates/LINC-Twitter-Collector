#!/usr/bin/ruby

require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'em-http/middleware/oauth'
require 'json'
require 'logger'
require 'set'

module Twitter
  class Collector
    def initialize oauth_config, args={}
      @trends_url = 'https://api.twitter.com/1/trends/1.json'
      @stream_url = 'https://stream.twitter.com/1/statuses/filter.json'
      @sample_url = 'https://stream.twitter.com/1/statuses/sample.json'
      @oauth_config = oauth_config

      @connection_info = {
        :stream => {
          :reconnects => args[:stream_attempts] || 6,
          :period => args[:stream_period] || 360,
          :attempts => [],
          :failed => [],
        },
        :rest => {
          :reconnects => args[:rest_reconnects] || 4,
          :period => 60,
          :attempts => [],
          :failed => [],
        },
      }

      @logger = args[:logger] || Logger.new(STDOUT)
    end

    def follow topics, &block
      follow_phrases topics, &block
    end

    def follow_trends trends, &block
      follow_phrases trends, &block
    end

    def trends &block
      throttle(:rest) do
        trends_conn = EM::HttpRequest.new(@trends_url)
        trends_conn.use EventMachine::Middleware::OAuth, @oauth_config
        trends_req = trends_conn.get
        start = Time.now
        trends_req.callback do
          begin
            response = JSON.parse(trends_req.response)
            if (response.is_a? Array)
              if (response[0]['trends'])
                trends = Set[*response[0]['trends'].collect{|t| t['name']}]
                block.call trends
              else
                @logger.error "Failed to parse trends from response: #{trends_req.response}"
                connection_failed :rest
              end
            else
              @connection_info[:rest][:failed].push Time.now
              @logger.error "Error retrieving trending topics from twitter: #{response['error']}"
            end
          rescue => e
            STDERR.print "Failed to handle trends: #{e}\n"
            STDERR.print "Response: #{trends_req.response}\n"
          end
        end
        trends_req.errback do
          @logger.error "Possible connection timeout.  Time passed: #{Time.now.to_i - start.to_i} seconds"
          @logger.error "Failed to retrieve trends from #{@trends_url}"
          connection_failed :rest
        end
      end
    end

    def stream_data url, post=nil, &block
      throttle(:stream) do
        if (@stream_conn && @stream_conn.conn)
          @stream_conn.conn.close_connection
        end
        start = Time.now
        @stream_conn = EventMachine::HttpRequest.new(url, :inactivity_timeout => 0, :connection_timeout => 0)
        @stream_conn.use EventMachine::Middleware::OAuth, @oauth_config
    
        if (post.nil?)
          @stream_req = @stream_conn.get
        else
          @stream_req = @stream_conn.post(post)
        end
    
        buffer = ""
        @stream_req.stream do |chunk|
          buffer += chunk
          while line = buffer.slice!(/.+\r?\n/)
            begin
              next if (line =~ /^\s*$/)
              block.call(JSON.parse(line))
            rescue => e
              @logger.error "Failed to handle status: '#{line}']"
              @logger.error "#{e}"
              connection_failed :stream
            end
          end
        end
    
        @stream_req.errback do
          @logger.error "Possible connection timeout.  Time passed: #{Time.now.to_i - start.to_i} seconds"
          @logger.error "Response: #{@stream_req.error}/#{@stream_req.response}"
          connection_failed :stream
        end
      end
    end

    def follow_phrases phrases, &block
      stream_data @stream_url, {:body => { :track => phrases.to_a.join(',') }}, &block
    end

    def sample &block
      stream_data @sample_url, &block
    end

    def update_attempts attempts, period
      while (attempts.length > 0 && attempts[0] < Time.now - period) do
        attempts.shift
      end
    end

    def throttled? connection_type
      update_attempts @connection_info[connection_type][:attempts], @connection_info[connection_type][:period]
      update_attempts @connection_info[connection_type][:failed], @connection_info[connection_type][:period]
      return @connection_info[connection_type][:attempts].length >= @connection_info[connection_type][:reconnects]
    end

    def connection_failed connection_type
      @connection_info[connection_type][:failed].push Time.now
    end

    def throttle connection_type, &block
      if (throttled?(connection_type))
        # calculate exponential backoff for failures
        if (@connection_info[connection_type][:failed].length > @connection_info[connection_type][:reconnects])
          @logger.fatal "Exceeded number of failed attempts.  Stopping EventMachine"
          EM.stop
        end
        succ_delay = 0
        if @connection_info[connection_type][:attempts].length > 0
          succ_delay = @connection_info[connection_type][:period] - Time.now.to_i - @connection_info[connection_type][:attempts][0].to_i 
        end
        fail_delay = (2**@connection_info[connection_type][:failed].length)-1
        # pick the greater of the two delays
        delay = fail_delay > succ_delay ? fail_delay : succ_delay

        @logger.debug "Internal throttle.  Fail delay: #{fail_delay}s Normal Delay: #{succ_delay}.  Waiting for #{delay}s"

        EM.add_timer delay do
          @logger.debug "Throttle complete.  Continuing execution"
          block.call
          @connection_info[connection_type][:attempts].push Time.now
        end
      else
        block.call
        @connection_info[connection_type][:attempts].push Time.now
      end
    end
  end
end
