require 'cgi'

class FeedParser
  class FeedItem
    attr_reader :type, :categories_domain

    def initialize(item)
      @guid = item.xpath(Dsl[@type][:item_guid]).text
      @title = item.xpath(Dsl[@type][:item_title]).text
      @published = parse_datetime(item.xpath(Dsl[@type][:item_published]).text)
      @author = item.xpath(Dsl[@type][:item_author]).text
      @description = possible_html_content(item.xpath(Dsl[@type][:item_description]))
      @content = possible_html_content(item.xpath(Dsl[@type][:item_content]))
      @categories_domain = {}
      self
    end

    def method_missing(method_id)
      if self.instance_variables.map(&:to_sym).include?("@#{method_id}".to_sym)
        if FeedParser.fields_to_sanitize.include?(method_id)
          FeedParser.sanitizer.sanitize(self.instance_variable_get("@#{method_id}".to_sym))
        else
          self.instance_variable_get("@#{method_id}".to_sym)
        end
      else
        super
      end
    end

    def as_json
      {
        :guid => self.guid,
        :link => self.link,
        :title => self.title,
        :published => self.published,
        :categories => self.categories,
        :categories_domain => self.categories_domain,
        :author => self.author,
        :description => self.description,
        :content => self.content
      }
    end

    private
    def possible_html_content(element)
      return '' if element.empty?
      return element.text unless element.attribute("type")

      case element.attribute("type").value
        when 'html', 'text/html'
          CGI.unescapeHTML(element.inner_html)
        when 'xhtml'
          element.xpath('*').to_xhtml
        else
          element.text
      end
    end

    def parse_datetime(string)
      begin
        DateTime.parse(string) unless string.empty?
      rescue
        warn "Failed to parse date #{string.inspect}"
        nil
      end
    end
  end

  class RssItem < FeedItem
    def initialize(item)
      @type = :rss
      super
      @link = item.xpath(Dsl[@type][:item_link]).text.strip
      item.xpath(Dsl[@type][:item_categories]).each  do |cat|
        @categories_domain[cat.text] = cat.attribute('domain').text.strip if cat.attribute('domain') #.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'}) rescue ''
      end
      @categories = item.xpath(Dsl[@type][:item_categories]).map{|cat| cat.text}
    end
  end

  class AtomItem < FeedItem
    def initialize(item)
      @type = :atom
      super
      @link = item.xpath(Dsl[@type][:item_link]).attribute("href").text.strip
      @updated = parse_datetime(item.xpath(Dsl[@type][:item_updated]).text)
      item.xpath(Dsl[@type][:item_categories]).each  do |cat|
        @categories_domain[cat.attribute("term").text] = cat.attribute('domain').text.strip if cat.attribute('domain') #.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'}) rescue ''
      end
      @categories = item.xpath(Dsl[@type][:item_categories]).map{|cat| cat.attribute("term").text}
    end

    def published
      @published ||= @updated
    end
  end
end
