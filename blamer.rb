#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'simplehttp'
require 'optparse'
require 'colored'
require 'yaml'

require_relative 'lib/blame'
require_relative 'lib/exception_group'

##
# APP SETUP
##

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
ERRORS_URL = "https://airbnb.airbrake.io/errors.xml?project_id=#{PROJECT_ID}&auth_token=#{AUTH_TOKEN}&page=%d"
ERROR_URL =  "https://airbnb.airbrake.io/errors/%s.xml?auth_token=#{AUTH_TOKEN}"

options = {
  :verbose => true,
  :pages => 3,
  :reverse => false
}

OptionParser.new do |opts|
  opts.banner = "Usage: blamer.rb [options]"

  opts.on("--file FILE", "Pull exeception data from a file") do |f|
    options[:file] = f
  end

  opts.on("-v", "--verbose", "Increase verbosity") do |v|
    options[:verbose] = true
  end

  opts.on("--pages PAGES", "Specify the number of Airbrake error pages to parse (default 3)") do |p|
    options[:pages] = p.to_i
  end

  opts.on('-r', "--reverse", "Reverse sorting order (lower rankings displayed first)") do |r|
    options[:reverse] = true
  end

  opts.on('--top NUMBER', "Display the top <NUMBER> of results") do |n|
    options[:number] = n.to_i 
  end

  opts.on('--presenter', '-p', "Enable presenter mode. Users must hit a keyboard key between printing each item.") do |p|
    options[:presenter] = true
  end
end.parse!

blames = {}

##
# PARSING
##

puts "Grabbing list of errors from #{options.has_key?(:file) ? "file" : "Airbrake"}..." if options[:verbose]

(1..options[:pages]).each do |page|
  puts "Getting page #{page}..." if options[:verbose]
  doc = if options.has_key? :file
          Nokogiri::XML.parse open(options[:file])
        else
          xml = SimpleHttp.get sprintf(ERRORS_URL, page)
          Nokogiri::XML.parse xml
        end

  doc.css('group').each do |group|
    e = ExceptionGroup.parse_from_node group

    puts "Grabbing backtrace for error #{e.id}..." if options[:verbose]

    # now grab the backtraces.
    detail =  if options.has_key? :file
                group
              else
                xml = SimpleHttp.get sprintf(ERROR_URL, e.id)
                Nokogiri::XML.parse xml
              end
    
    e.process_backtrace!(detail)

    # figure out the blame
    if e.file && e.line
      name = `cd #{PROJECT['path']} && git blame -L #{e.line},#{e.line} #{e.file} -p | grep "author " | sed "s/author //"`
      name.strip!

      blames[name] = Blame.new(name) unless blames.has_key? name
      blames[name].exceptions << e
    end
  end
end

##
# SCORING
##

# sort the values based on score
blames = blames.values
blames = blames.sort {|a, b| b.score <=> a.score}

# apply various options like truncation and reversal
blames = blames[0..(options[:number] - 1)] if options.has_key? :number
blames = blames.reverse if options[:reverse]

i = options[:reverse] ? blames.length : 1 

puts "\nLEADERBOARD OF OPPORTUNITY\n".magenta.underline.bold

if options[:presenter]
  puts "Press any key to continue..."
  gets
end

blames.each do |blame|
  # clear the screen
  print "\e[2J\e[f" if options[:presenter]

  blame.sort_exceptions!

  puts "#{i}.".rjust(3) + " #{blame.author.bold.red.underline} " + "(#{"%.2f" % blame.score})".magenta
  
  blame.exceptions.each do |e|
    puts "\t#{("%.2f" % e.score).rjust(5)}".green +  "\t#{e.notices_count}".yellow + "\t#{e.time_since_last_error / 60} mins ago".blue + "\t#{e.error_message[0..80]} in #{e.file}:#{e.line} (#{e.id})"
  end

  puts "\n"

  i += options[:reverse] ? -1 : 1

  if options[:presenter]
    puts "Press any key to continue..."
    gets
  end
end
