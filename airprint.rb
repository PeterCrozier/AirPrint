#!/usr/bin/env ruby -rubygems
#
require 'dnssd'
require 'timeout'
require 'optparse'

class Airprint

  attr_accessor :service, :domain, :script, :timeout

  def initialize
    self.service="_ipp._tcp"
    self.domain="local"
    self.script="airprint.sh"
    self.timeout=5
  end

  def browse(s=self.service, d=self.domain, t=self.timeout)
    browser = DNSSD::Service.new
    printers=[]
    puts "Browsing for #{s} services in domain #{d}..."
    begin
      Timeout::timeout t do
        browser.browse s, d do |reply|
          resolver = DNSSD::Service.new
          resolver.resolve reply do |r|
            puts "Resolved #{r.name}"
            printers.push r
          end
        end
      end
    rescue
      # puts "Timed out"
    end
    # there might be more than one interface
    up = printers.uniq { |r| r.name }
    puts "Found #{up.count} unique from #{printers.count} entries" if up.count > 0
    up
  end

  def expand(fd, r, bg)
    # Expand out the Bonjour response
    puts "Service Name: #{r.name}\nResolved to: #{r.target}:#{r.port}\nService type: #{r.type}"
    txt = r.text_record
    # remove entry inserted by Bonjour
    txt.delete 'UUID'
    # Add Airprint txt fields
    txt['URF'] = 'none'
    txt['pdl'] = 'application/pdf,image/urf'
    txt.each_pair do |k,v|
      puts "\t#{k} = #{v}"
    end
    fd.write "dns-sd -R \"#{r.name} airprint\" _ipp._tcp,_universal . 631"
    txt.each_pair do |k,v|
      fd.write " \\\n\t#{k}=\'#{v}\'"
    end
    if bg
      fd.write ' &'
    end
    fd.puts 
  end

end


options = {}
cmd = {}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] command"

  opts.separator ""
  opts.separator "Command: Choose only one"

  opts.on("-i", "--install", "install permanently, requires sudo") do |v|
    cmd[:install] = v
  end

  opts.on("-u", "--uninstall", "uninstall, requires sudo") do |v|
    cmd[:uninstall] = v
  end

  opts.on("-t", "--test", "test, use CTRL-C to exit") do |v|
    cmd[:test] = v
  end

  opts.separator ""
  opts.separator "Options:"

  opts.on("-f", "--script_file", "script filename") do |v|
    options[:script] = v
  end

  opts.on_tail("-h", "--help", "print this message") do
    puts opts
    exit
  end

end.parse!

if ARGV.count != 0 or cmd.count != 1
  puts "Bad command"
  exit
end

# require sudo to update /Library
euid=`id -u`.to_i
isRoot = (euid == 0)
if (options.key? :install or options.key? :uninstall) and !isRoot
  puts "Run with sudo to install or uninstall"
  exit
end


# plist for LaunchControl
hostname = `hostname`.strip.gsub(/\..*$/,'')
revhost = "local.#{hostname}.airprint"
launchlib = "/Library/LaunchDaemons"
launchfile=revhost + ".plist"

plist=<<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>#{revhost}</string>
        <key>ProgramArguments</key>
        <array>
                <string>/Library/LaunchDaemons/airprint.sh</string>
        </array>
        <key>LowPriorityIO</key>
        <true/>
        <key>Nice</key>
        <integer>1</integer>
        <key>UserName</key>
        <string>root</string>
        <key>RunAtLoad</key>
        <true/>
        <key>Keeplive</key>
        <true/>
</dict>
</plist>
EOT

ap = Airprint.new


if options.key? :uninstall
  `launchctl unload #{launchfile}`
  puts "Uninstalling #{ap.script} from #{launchlib}"
  delete File.expand_path ap.script, launchlib
  puts "Uninstalling #{launchfile} from #{launchlib}"
  delete File.expand_path launchfile, launchlib
  exit
end


# determine existing printers
printers = ap.browse
count = printers.count
if count == 0
  puts "No shared printers were found"
  exit
end

# if not installing, create files in the working directory
wd = options.key?(:install) ? launchlib : "."
p wd

# write script to register them
bg = (count > 1)
File.open File.expand_path(ap.script, wd), 'w' do |fd|
  printers.each { |r| ap.expand fd, r, bg }
end

# write a plist file to launch it
File.open File.expand_path(launchfile, wd), 'w' do |fd|
  fd.write plist
end

if options.key? :install
  `launchctl load #{launchfile}`
  puts "Installed"
  exit
end

if options.key? :test
  puts "Registering printer, use CTRL-C when done"
  `sh #{ap.script}`
  exit
end

exit
