require 'sinatra'
require 'haml'
require 'tilt/haml' # supress some console warning
require 'wikipedia'
require 'thread'
require 'redis'
require 'date'
require 'yaml'
require 'builder'

NUMBER_OF_ARTICLES = 30
REDIS_CONNECTION_STRING = 'redis://rediscloud:CkvFDQXH6tMFmNl9@pub-redis-12002.us-east-1-1.1.ec2.garantiadata.com:12002'

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
        while article.title.match(/list of/i) || (article.categories && article.categories.join.downcase.include?('disambiguation'))
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

def truncate(string, size)
  length = string.length
  output = string[0..size].rstrip
  if length > size
    output + '...'
  else
    output
  end
end

__END__

@@index 
!!!
%html
  %head
    %title DailyWiki - New random wikipedia articles every day
    %link{ rel: 'stylesheet', media: 'screen', href: '/styles.css' }
    %link{ rel: 'stylesheet', media: 'screen', href: '/themes.css' }
    %script{ src: '/script.js' }
    %link{ rel: "alternate", type: "application/rss+xml", title: "DailyWiki RSS", href: "/rss" }
  %body
    .container
      %header
        %h1 
          DailyWiki
          %small
            %a{ href: '/feed', class: 'feed_link'} rss
        %span.controls
          %span.theme-select.theme-default
          %span.theme-select.theme-inverse
      %main
        - @articles.each_with_index do |article, index|
          %a{ href: article.fullurl, title: truncate(article.summary, 667) }
            %span.article-index= index+1
            %span.article-title=article.title
            »
            = truncate(article.summary, 300)
    :javascript
      var body = document.getElementsByTagName("body")[0];
      body.className = localStorage.theme;

      var inverseThemeBtn = document.querySelectorAll(".theme-select.theme-inverse")[0];
      inverseThemeBtn.addEventListener("click", function (e){ body.className = 'theme-inverse'; localStorage.theme = 'theme-inverse'}, false);

      var defaultThemeBtn = document.querySelectorAll(".theme-select.theme-default")[0];
      defaultThemeBtn.addEventListener("click", function (e){ body.className = ''; localStorage.theme = ''}, false);

@@feed
xml.instruct! :xml, version: "1.0" 
xml.rss version: "2.0" do
  xml.channel do
    xml.title "DailyWiki"
    xml.description "New random wikipedia articles every day"
    xml.link uri('/')
    xml.language 'en-us'
    xml.pubDate DateTime.parse(Date.today.to_s).to_s
    xml.lastBuildDate DateTime.parse(Date.today.to_s).to_s

    @articles.each do |article|
      xml.item do
        xml.title article.title
        xml.link article.fullurl
        xml.description truncate(article.summary, 667)
      end
    end
  end
end
