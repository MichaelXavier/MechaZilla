require 'mechanize'
require 'optparse'
require 'uri'
require 'open-uri'
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

      @search   = options[:url_pattern] ? :urls : :text
      @pattern  = (options.delete(:url_pattern) or options.delete(:text_pattern))
      @prefix   = options.delete(:prefix)
      @uris     = options.delete(:urls)
      @output   = Pathname.new(options.delete(:output_dir)).realpath.to_s
      @dry_run  = options.delete(:dry_run)
      @debug    = options.delete(:debug)

      @messages = []
    end

    def download
      #puts retrieve_uris(@agent).collect(&:to_s);exit#DEBUG
      uris = retrieve_uris(@agent)
      pbar = ProgressBar.new("All Downloads", uris.length)
      uris.each do |uri|
        filename = "#{@prefix}#{uri.to_s.split('/').last}"

        if @dry_run
          fake_download(filename, uri)
        else
          download_file(filename, uri)
        end

        pbar.inc
      end

      dump_messages
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
          file.write uri.read
        end
      rescue OpenURI::HTTPError => e
        warn "Warning: error encountered on uri #{uri.to_s}: #{e.message}#{"\n#{e.backtrace.join("\n")}" if @debug}"
      end
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
          warn "Warning: url #{url} invalid. Skipping."
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
