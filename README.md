LINC-Twitter-Collector
======================

Introduction
------------


### Pre-Requisites

These instructions assume you are running Ubuntu (tested on Ubuntu 12.04 Server).

Install git, ruby and rubygems as well as required gems:

    sudo apt-get install git ruby rubygems libssl-dev
    sudo gem install em-http-request simple_oauth json

### Download the code from git

    git clone https://github.com/abates/LINC-Twitter-Collector.git

### Obtain Developer Credentials from Twitter
1. Login to https://dev.twitter.com
2. Create a new app at https://dev.twitter.com/apps/new
   * Name, Description and Website are all required fields, any website will work.
3. Scroll to the bottom of the page and create a new access token

### Run one of the programs

The first time you run one of the collector scripts it will prompt you for the credentials you created in the previous steps.  Copy/paste the consumer key, consumer secret, access token and access token secret into the prompts.  If any of the information needs to be reset you can simply edit the config file in ~/.LINC_Twitter_Collector/oauth_credentials.yml


Using The Collector
-------------------

There are 3 scripts that can be used to collect twitter statuses:

* follow.rb
  This script will follow specified keywords
    ./follow.rb "topic 1" "topic 2" ...

* follow_trends.rb
  This script will follow the trending topics

* sample.rb
  This script will follow the sample feed (uniform sample of all public tweets)

All data is written to: data/[follow|trends|sample]/<keyword>/statuses_*.json.  The json files will rotate every 10000 tweets.  The first 10000 will be in statuses_001.json, the second 10000 will be in statuses_002.json and so on.

