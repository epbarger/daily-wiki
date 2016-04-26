require 'sinatra'
require 'wikipedia'
require 'thread'
require 'redis'
require 'date'
require 'yaml'
require 'haml'
require 'builder'
require 'tilt/haml' # suppress some console warning
require 'tilt/builder' # suppress some some console warning

NUMBER_OF_ARTICLES = 30
REDIS_CONNECTION_STRING = ENV['REDISCLOUD_URL']

get '/' do
  set_articles
  haml :index 
end

get '/feed' do
  set_articles
  builder :feed
end

def set_articles
  redis = Redis.new(url: REDIS_CONNECTION_STRING)
  @articles = redis.get(Date.today.to_s)
  if @articles
    @articles = YAML.load(@articles)
  else
    threads = []
    @articles = []
    NUMBER_OF_ARTICLES.times do |i|
      threads << Thread.new do
        article = Wikipedia.find_random
        while article.summary.nil? || article.title.match(/list of/i) || (article.categories && article.categories.join.downcase.include?('disambiguation'))
          article = Wikipedia.find_random
        end
        @articles << article
      end 
    end
    threads.each(&:join)
    redis.set(Date.today.to_s, YAML.dump(@articles))
    redis.expire(Date.today.to_s, 129600) # 36 hours
  end

  @articles = @articles.slice(0, NUMBER_OF_ARTICLES)
end

def truncate(string, max, min=max-15) # truncates on word boundary between max and min
  cut_index = max
  while string[cut_index] != ' ' && cut_index > min
    cut_index -= 1
  end

  output = string[0..cut_index].rstrip
  if string.length > cut_index
    output + '...'
  else
    output
  end
end
