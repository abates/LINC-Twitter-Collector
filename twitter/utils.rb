#!/usr/bin/env ruby

require 'yaml'

PREFERENCES_DIR='~/.LINC_Twitter_Collector'

def get_user_input message
  while (true)
    print "#{message}: "
    response = STDIN.gets
    if (response.empty?)
      puts "ERROR: please supply a value!"
    else
      return response.strip
    end
  end
end

def get_preferences_dir
  dir = File.expand_path(PREFERENCES_DIR)
  if (! File.exists?(dir))
    Dir.mkdir(dir)
  end
  return dir
end

def load_credentials
  file = File.expand_path("#{get_preferences_dir}/oauth_credentials.yml")
  if (File.exists?(file))
    credentials = YAML.load_file(file)
  else
    credentials = {}
    credentials[:consumer_key] = get_user_input(   "    Input the consumer key")
    credentials[:consumer_secret] = get_user_input("    Input the consumer secret")
    credentials[:access_token] = get_user_input("       Input the access token")
    credentials[:access_token_secret] = get_user_input("Input the access token secret")
    File.open(file, 'w') { |f| f.write(credentials.to_yaml) }
  end
  return credentials
end

def mkdir(path)
  cwd = ''
  path.split(/\//).each do |d|
    cwd += "/" unless (cwd == '')
    cwd += "#{d}"
    Dir.mkdir(cwd) unless File.exists?(cwd)
  end
end

def matches_keywords? keywords, text
  keywords = keywords.split(/\s+/) if (keywords.is_a? String)

  match = true
  keywords.each do |keyword|
    unless(text =~ /#{keyword}/i)
      match = false
      break
    end
  end
  return match
end

def add_status topic, status
  @statuses ||= {}
  @statuses[topic] ||= []
  @statuses[topic] << status unless (status.nil?)

  if (@statuses[topic].length == 10000)
    write_status(topic)
  end
end

def write_status topic
  return if (@statuses.length == 0)
  index = 1
  if (topic.nil?)
    dst_dir = "#{@data_dir}"
  else
    dst_dir = "#{@data_dir}/#{topic}" 
  end
  mkdir(dst_dir)

  Dir.foreach(dst_dir) do |file|
    if (file =~ /statuses_(\d+)\.json/)
      if ($1.to_i >= index)
        index = $1.to_i + 1
      end
    end
  end

  dst_file = sprintf("statuses_%03d.json", index)

  File.open("#{@data_dir}/#{topic}/#{dst_file}", 'w') { |f|
    f.write(@statuses[topic].to_json)
  }
end

def handle_status(status, topics=nil)
  return unless status['text']
  found = false
  if (topics.nil?)
    found = true
    add_status(nil, status)
  else
    topics.each do |topic|
      if (matches_keywords?(topic, status['text']) || 
          (! status['retweeted_status'].nil? && matches_keywords?(topic, status['retweeted_status']['text'])))
        found = true
        add_status(topic, status)
      end
    end
  end
  unless (found)
    STDERR.print "ERROR: did not have topic for status:\n"
    STDERR.print "     text: #{status['text']}\n"
    STDERR.print "  retweet: #{status['retweeted_status']['text']}\n" if (! status['retweeted_status'].nil?)
    STDERR.print "\n"
  end
end

