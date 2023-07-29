#!/usr/bin/env ruby
#
require 'open3'
require 'timeout'
require 'optparse'
require 'shellwords'

class Airprint

  attr_accessor :service, :domain, :script, :timeout

  def initialize
    self.service="_ipp._tcp"
    self.domain="local"
    self.script="airprintfix.sh"
    self.timeout=3
  end

  def browse(s=self.service, d=self.domain, t=self.timeout)
    printers=[]
    puts "Browsing for #{s} services in domain #{d}..."

    Open3.popen2("dns-sd -B _ipp._tcp local") {|i,o,t|
      sleep self.timeout
      Process.kill("INT", t.pid)
      o.each do |line|
        printers.push line.split('_ipp._tcp.')[1].strip if line =~ /_ipp._tcp./ if line !~ /^Browsing/ if line !~ /airprint/
      end
    }

    # there might be more than one interface
    up = printers.uniq
    puts "Found #{up.count} unique from #{printers.count} entries" if up.count > 0
    up
  end

  def expand(fd, r, bg)
    puts "Service Name: #{r}"
    txt = []

    Open3.popen2("dns-sd -L \"#{r}\" _ipp._tcp local") {|i,o,t|
      sleep self.timeout
      Process.kill("INT", t.pid)
      array = []
      o.each do |line|
        array = line.shellsplit if line =~ /txtvers/
      end
      array.each do |pair|
        # remove entry inserted by Bonjour and pdl which is hardwired
        txt.push pair.strip if pair !~ /^UUID/ if pair !~ /^pdl/
      end
    }

    # # Add Airprint txt fields
    txt.push('pdl=application/pdf,image/urf')
    txt.push('URF=none')

    fd.write "#!/bin/bash\n\n"
    fd.write "dns-sd -R \"#{r} airprint\" _ipp._tcp,_universal . 631"
    txt.each do |p|
      pair = p.split(/=/, 2)
      fd.write " \\\n\t#{pair[0]}='#{pair[1]}'"
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

if ARGV.count != 0 or cmd.count > 1
  puts "Bad command"
  exit
end

# require sudo to update /Library
isRoot = (Process.euid == 0)
if (cmd.key? :install or cmd.key? :uninstall) and !isRoot
  puts "Run with sudo to install or uninstall"
  exit
end

ap = Airprint.new

# plist for LaunchControl
hostname = `hostname`.strip.gsub(/\..*$/,'')
revhost = "local.#{hostname}.airprintfix"
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
                  <string>/Library/LaunchDaemons/#{ap.script}</string>
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

if cmd.key? :uninstall
  system "launchctl unload #{launchfile}"
  rc = $?.exitstatus
  puts "Uninstalling #{ap.script} from #{launchlib}"
  File.delete File.expand_path ap.script, launchlib
  puts "Uninstalling #{launchfile} from #{launchlib}"
  File.delete File.expand_path launchfile, launchlib
  exit rc
end

# determine existing printers
printers = ap.browse
count = printers.count
if count == 0
  puts "No shared printers were found"
  exit
end

# if not installing, create files in the working directory
wd = cmd.key?(:install) ? launchlib : "."

# write script to register them
bg = (count > 1)
f = File.expand_path(ap.script, wd)
File.open f, 'w', 0755 do |fd|
  printers.each { |r| ap.expand fd, r, bg }
end

# write a plist file to launch it
File.open File.expand_path(launchfile, wd), 'w', 0644 do |fd|
  fd.write plist
end

if cmd.key? :install
  plist = File.expand_path(launchfile, wd)
  system "launchctl load -w #{plist}"
  rc = $?.exitstatus
  puts (rc == 0) ? "Installed" : "Failed to install #{plist}, rc=#{rc}"
  exit rc
end

if cmd.key? :test
  puts "Registering printer, use CTRL-C when done"
  trap 'INT' do exit end
  system "/bin/bash #{ap.script}"
  exit $?.exitstatus
end

exit
