require 'mechanize'
require 'optparse'
require 'uri'
require 'progressbar'
require 'fileutils'
require 'pathname'

module MechaZilla
  VERSION = '0.1a'

  class Downloader
    
    def initialize(options={})
      validate_options(options)

      @agent = WWW::Mechanize.new do |agent| 
        agent.user_agent_alias = options.delete(:user_agent)
      end

      @search  = options.has_key? :url_pattern ? :urls : :text
      @pattern = options.delete[:url_pattern] or options.delete[:text_pattern]
      @prefix  = options.delete[:prefix]
      @uris    = options.delete[:urls]
      @output  = Pathname.new(options.delete[:output_dir]).cleanpath.to_s
    end

    def download
      retrieve_links.each do |link|
        #TODO
      end
    end

  private

    def retrieve_links(agent)
      ret = []
      
      @uris.each do |uri|
        @agent.transact do |ag|
          ag.get uri

          ag.page.links.each do |link|
            cmp = @search == :urls ? link.uri : link.text
            #FIXME see if this works for relatives and if not, create a resolve relative method
            ret << link if cmp =~ @pattern
          end
        end
      end

      ret
    end

    def prepare_output
      FileUtils.mkdir_p @output
    end

    def validate_options(options)
      raise ArgumentError, "Either a URL or Text pattern is required" unless options.has_key? :url_pattern or options.has_key? :text_pattern
      raise ArgumentError, "Need an output dir" unless options.has_key? :output_dir

      options[:urls].collect! {|url|
        begin
          URI.parse url
        rescue URI::InvalidURIError
          warn "Warning: url #{url} invalid. Skipping."
          nil
        end
      }.compact!

      raise ArgumentError, "Need at least 1 valid URL to proceed" if options[:urls].empty?
    end
  end
end
