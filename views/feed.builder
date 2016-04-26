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
