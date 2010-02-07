require 'mechanize'
require 'optparse'
require 'uri'
require 'open-uri'
require 'progressbar'
require 'fileutils'
require 'pathname'

module MechaZilla
  VERSION = '1.0'

  class Downloader
    
    def initialize(options={})
      validate_options(options)

      @agent = WWW::Mechanize.new do |agent| 
        agent.user_agent_alias = options[:user_agent]
      end

      @search     = options[:url_pattern] ? :urls : :text
      @pattern    = (options[:url_pattern] or options[:text_pattern])
      @prefix     = options[:prefix]
      @sleep_secs = options[:sleep_secs]
      @uris       = options[:urls]
      @output     = Pathname.new(options[:output_dir]).realpath.to_s
      @dry_run    = options[:dry_run]
      @debug      = options[:debug]
      @quiet      = options[:quiet]

      @messages = []
    end

    def download
      uris = retrieve_uris(@agent)
      pbar = ProgressBar.new("All Downloads", uris.length) unless @quiet or @dry_run
      uris.each_with_index do |uri, i|
        filename = "#{@prefix}#{uri.to_s.split('/').last}"

        if @dry_run
          fake_download(filename, uri)
        else
          download_file(filename, uri)
          # Sleep to throttle the connection and avoid getting B&
          sleep(@sleep_secs) if @sleep_secs and i < uris.length - 1
        end

        pbar.inc unless @quiet or @dry_run
      end

      dump_messages unless @quiet
    end

  private

    def dump_messages
      puts @messages.join("\n")
      @messages.clear
    end

    def fake_download(filename, uri)
      @messages << "Dry Run: Would download #{uri.to_s} to path #{File.join(@output, filename)}"
    end

    def download_file(filename, uri)
      begin
        File.open(File.join(@output, filename), 'w') do |file|
          file.write @agent.get(uri, spoof_referrer(uri)).body
        end
      rescue OpenURI::HTTPError, SocketError, WWW::Mechanize::ResponseCodeError => e
        warn "Warning: error encountered on uri #{uri.to_s}: #{e.message}#{"\n#{e.backtrace.join("\n")}" if @debug}" unless @quiet
      end
    end

    def spoof_referrer(uri)
      up_one = uri.path.to_s.split('/')[0...-1].join('/')
      WWW::Mechanize::Page.new(URI::Generic.build(:scheme => uri.scheme, :host => uri.host, :port => uri.port).merge(up_one), {'content-type' => 'text/html'})
    end

    def retrieve_uris(agent)
      ret = []
      
      @uris.each do |uri|
        @agent.transact do |ag|
          ag.get uri

          ag.page.links.each do |link|
            cmp = (@search == :urls) ? link.uri.to_s : link.text
            ret << absolutize_link(ag.page.uri, link.uri) if cmp =~ @pattern
          end
        end
      end

      ret
    end

    def prepare_output
      FileUtils.mkdir_p @output
    end

    def validate_options(options)
      raise ArgumentError, "Either a URL or Text pattern is required" unless options[:url_pattern] or options[:text_pattern]
      raise ArgumentError, "Need an output dir" unless options[:output_dir]

      options[:urls].collect! {|url|
        begin
          URI.parse url
        rescue URI::InvalidURIError
          warn "Warning: url #{url} invalid. Skipping." unless @quiet
          nil
        end
      }.compact!

      raise ArgumentError, "Need at least 1 valid URL to proceed" if options[:urls].empty?
    end

    def absolutize_link(page_uri, link_uri)
      link_uri.relative? ? page_uri.merge(link_uri) : link_uri
    end
  end
end
