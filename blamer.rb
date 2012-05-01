#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'simplehttp'
require 'optparse'
require 'colored'
require 'yaml'

require 'lib/blame'
require 'lib/exception_group'

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
