#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'simplehttp'
require 'optparse'
require 'colored'
require 'yaml'

##
# CLASS SETUP
##

class Blame
  attr_accessor :author, :exceptions

  def initialize(name)
    self.author = name
    self.exceptions = []
  end

  def sort_exceptions!
    self.exceptions.sort!{|a, b| b.score <=> a.score}
  end

  def score
    unless @score
      @score =  # number of exceptions
                #self.exceptions.length * 
                # sum number of counts over all exceptions, then log
                self.exceptions.map(&:score).reduce(:+)
    end
    
    @score
  end
end

class ExceptionGroup
  attr_accessor :error_class, :error_message, :notices_count, :backtrace, :most_recent_notice, :file, :line, :created_at, :id

  def initialize(options = {})
    self.error_class = options[:error_class]
    self.error_message = options[:error_message]
    self.notices_count = options[:notices_count] 
    self.most_recent_notice = options[:most_recent_notice]
    self.created_at = options[:created_at]
    self.id = options[:id]
  end

  # capture high-volume issues
  # capture very old issues
  def score
    Math.log(self.notices_count.to_f) * (1 / Math.log(time_since_last_error))
  end

  def age
    unless @age
      if self.created_at.nil?
        @age = 0
      else
        now = DateTime.now.to_time.to_i
        created_at = self.created_at.to_time.to_i
        @age = now - created_at
      end
    end

    @age
  end

  def time_since_last_error
    if self.most_recent_notice.nil?
      @time_since_last_error = 0 
    else
      now = DateTime.now.to_time.to_i
      last = self.most_recent_notice.to_time.to_i
      @time_since_last_error = now - last
    end

    @time_since_last_error
  end

  def process_backtrace!(group)
    backtraces = group.css('backtrace line').map {|e| e.content} 

    backtraces.each do |line|
      line.gsub!(/\[PROJECT_ROOT\]\//, "")

      if line =~ /^(?:app|lib)/
        m = /^(?<path>.+)\:(?<line>[[:digit:]]+):in/.match(line)

        unless m.nil?
          self.file = m[:path]
          self.line = m[:line]
        end
        break
      end
    end

  end

  def self.parse_from_node(group)
    e = new({
          :error_class => group.css('error-class').first.content,
          :error_message => group.css('error-message').first.content,
          :notices_count => group.css('notices-count').first.content.to_i,
          :most_recent_notice => DateTime.parse(group.css('most-recent-notice-at').first.content),
          :created_at => DateTime.parse(group.css('created-at').first.content),
          :id => group.css('id').first.content.to_i
    })
      
    e
  end
end

##
# APP SETUP
##
#

begin
  CONFIG = YAML.load_file 'config.yml'
rescue Exception => e
  puts "Error: no config.yml found!"
  exit
end

AIRBRAKE = CONFIG['airbrake']
PROJECT = CONFIG['project']

PROJECT_ID = AIRBRAKE['project_id']
AUTH_TOKEN = AIRBRAKE['auth_token']
ERRORS_URL = "https://airbnb.airbrake.io/errors.xml?project_id=#{PROJECT_ID}&auth_token=#{AUTH_TOKEN}"
ERROR_URL =  "https://airbnb.airbrake.io/errors/%s.xml?auth_token=#{AUTH_TOKEN}"

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: blamer.rb [options]"

  opts.on("--file FILE", "Pull exeception data from a file") do |f|
    options[:file] = f
  end

  opts.on("-v", "Increase verbosity") do |v|
    options[:verbose] = true
  end
end.parse!

blames = {}

##
# PARSING
##

doc = if options.has_key? :file
        Nokogiri::XML.parse open(options[:file])
      else
        xml = SimpleHttp.get ERRORS_URL 
        Nokogiri::XML.parse xml
      end

doc.css('group').each do |group|
  e = ExceptionGroup.parse_from_node group

  puts "Processing error #{e.id}..." if options[:verbose]

  # now grab the backtraces
  xml = SimpleHttp.get sprintf(ERROR_URL, e.id)
  detail = Nokogiri::XML.parse xml
  
  e.process_backtrace!(detail)

  if e.file && e.line
    name = `cd #{PROJECT['path']} && git blame -L #{e.line},#{e.line} #{e.file} -p | grep "author " | sed "s/author //"`
    name.strip!

    blames[name] = Blame.new(name) unless blames.has_key? name
    blames[name].exceptions << e
  end
end

##
# SCORING
##

blames = blames.values
blames = blames.sort {|a, b| b.score <=> a.score}
i = 1

puts "\nLEADERBOARD OF OPPORTUNITY\n".magenta.underline.bold

blames.each do |blame|
  blame.sort_exceptions!

  puts "#{i}.".rjust(3) + " #{blame.author.bold.red.underline} " + "(#{"%.2f" % blame.score})".magenta
  
  blame.exceptions.each do |e|
    puts "\t#{("%.2f" % e.score).rjust(5)}".green +  "\t#{e.notices_count}".yellow + "\t#{e.time_since_last_error / 60} mins ago".blue + "\t#{e.error_message[0..80]} in #{e.file}:#{e.line} (#{e.id})"
  end

  i += 1
end
