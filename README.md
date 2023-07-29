## Installing Airprint server support on a Mac

### Quick and dirty install

Use the Terminal app to run the install script on the Mac with the printer to be
shared over airprint.  It obviously has to be on the same local network as the
iOS client.

Then to test the feature run (this also creates the shell file and plist file in
the current directory)

	./airprintfix.rb -t

The existing shared printers should now be available to iOS clients.  You will need to use `CTRL-C` to stop the server.  To install permanently run:

	sudo airprintfix.rb -i

The script will find existing shared printers and make them available over airprint.  Make sure printer sharing has been enabled in Printer Preferences.

The script has a -h option to get more information

	./airprintfix.rb -h

The rest of this document explains a manual install and details about how this
works.

## Manual Install

If you don't have Ruby installed and don't want to install Ruby or have
difficulty installing Ruby.

1. Make sure you have printer sharing enabled for your printer (System
   Preferences)
2. Copy the templates `airprintfix.sh` and `local.hostname.airprintfix.plist` to
   `/Library/LaunchDaemons`
3. Find your hostname (ignore any suffix after the first dot, for example `.local`)
```
hostname
```
4. Rename `/Library/LaunchDaemons/local.hostname.airprintfix.plist` by replacing
   the word `hostname` by your hostname from above
5. Edit the renamed file by replacing the word `hostname` on line 6 by your
   hostname from above
5. Find the name of your printer (the last column under `Instance` - press
   `CTRL-C` to exit):
```
dns-sd -B _ipp._tcp local
```
7. Find the printer details (copy your printer name from above - press `CTRL-C`
   to exit):
```
dns-sd -L "printer name goes here" _ipp._tcp local
```
8. Edit `/Library/LaunchDaemons/airprintfix.sh` by replacing `<insert printer
   name here>` with the printer name on line 3 (keeping the suffix `airprint`)
   and adding all the printer details except `UUID`, and keeping `URF` which is
   required and the template `pdl` which must contain `image/urf`. Use single
   quotes around the values as shown in the template examples. Unquote any
   spaces or parentheses, etc., for example, replace `\(` by `(`. Ensure there
	 is a tab at the beginning of each line except the first line. Ensure there is
	 a backslash `\` at the end of each line except the last line
9. Execute the following commands (replacing the word `hostname` by your
   hostname from above)

```
chmod +x /Library/LaunchDaemons/airprintfix.sh
chmod go-w /Library/LaunchDaemons/airprintfix.sh
sudo chown root:wheel /Library/LaunchDaemons/local.hostname.airprintfix.plist
sudo launchctl load /Library/LaunchDaemons/local.hostname.airprintfix.plist
```

## Manual Uninstall

To uninstall run the following command (replacing the word `hostname` by your
   hostname from above) then delete `/Library/LaunchDaemons/airprintfix.sh` and
   the plist file as well.
```
sudo launchctl unload /Library/LaunchDaemons/local.hostname.airprintfix.plist
```

## How it works

### Airprint basics

* Airprint servers use CUPS aka IPP over tcp
	* This means you need to enable printer sharing in Prefences.
* They advertise themselves using Apple's **Bonjour** dynamic DNS
* Normal Apple print sharing uses the type **_ipp._tcp**
* They appear in the *local* domain (and also icloud.com if BackToMyMac is supported)
* You can see these services either
	* in terminal using the ugly command line utility dns-sd
	* A better way is to get the free Bonjour Browser app from the [here](http://www.tildesoft.com)
* You will see your shared printers under the _ipp._tcp type
	* The bold line is the printer name
	* the _keyword=_ lines are DNS TXT records advertising capabilities
	* *txtvers=1* is required and should be the first keyword pair.
	* *note=* is the subtitle shown below the printer name in choose printer dialogues
	* *qtotal=1* is the number of queues and is required
	* *rp=* is the queue name and is required.
	* *ty=* is the printer type and is optional
	* the *pdl=* keyword list the MIME types supported
* However airprint requires:
	* advertising with the **_ipp._tcp,_universal** subtype
	* advertising a pdl list including application/pdf and image/urf
	* there must be a URF= keyword though the value does not matter

### Running a Bonjour service

1. Make sure you have printer sharing enabled for your printer
2. Run [dns-sd](#dns-sd) or Bonjour Browser to find out the details of your printer and what TXT lines it advertises
3. Fire up whatever text editor you prefer (if you use Apple's TextEdit make sure it is in plain text mode in the preferences).
4. Paste into it the [dns script](#dnsscript)
	* The bits inside double asterisks are unique to your setup's TXT lines and should be changed to agree
	* Note each line (except the last) ends in a backspace to continue across multiple lines
	* Also spaces inside keyword values have to be protected by a backslash
	* The last line should replace the existing pdl
5. Save this in Documents as airprint.sh (in plain text format!)

To test it run Terminal.app from Applications/Utilities and type

	cd Documents
	sh airprint.sh

This will then hang.  While it is running the Mac should be acting as an Airprint server.  Try to print from some iOS app to verify this.  You can use CTRL-C to break the hang and exit to end the terminal session.



### Running automatically

To ensure the service runs at all times we need to have it run automatically in the background when the Mac boots.

6. Start another new document in your editor and paste in the [launch script](#launch)
7. Replace *hostname* in line 6 of the text with the Mac's actual hostname
8. Save this in Documents as local.*hostname*.airprint.plist replacing *hostname* with the Mac's actual hostname
9. Start another Document and paste in the [terminal script](#terminal).  Again swap out the hostname to your actual Mac's hostname.
10. Save it as t.sh
11. Fire up Terminal.app from Applications/Utilities
12. Type in sudo sh t.sh and enter your admin password when prompted
13. Try it out from iOS
14. Profit!

### The DNS script[dnsscript]

	dns-sd -R "name_to_be advertised" _ipp._tcp.,_universal . 631 \
		URF=none txtvers=1 qtotal=1 \
		rp=printers/"queue name" \
		note="descriptive text" \
		priority=0 \
		pdl=application/pdf,image/urf

* The text in quotes will need to be edited.  Any embedded blanks or newlines outside quotes need to be
protected with backslashes.
	* *"name to be advertised"* is the name you want to give to this print queue
	* *"queue name"* is the name the host computer gives to the queue, see printers page in preferences on the host
	* *descriptive text* is subtitle for the printer.  Enter any useful description here.

An example script might be:

	dns-sd -R "SamsungLaser@macmini airprint" _ipp._tcp.,_universal . 631 \
		URF=none txtvers=1 qtotal=1 \
		rp=printers/SamsungLaser \
		note="USB connected" \
		priority=0 \
		pdl=application/pdf,image/urf


### The launch script[launch]

	<?xml version='1.0' encoding='UTF-8'?>
	<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version='1.0'>
	<dict>
		<key>Label</key>
		<string>local.hostname.airprint</string>
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

### Terminal script[terminal]

	cd /Library/LaunchDaemons
	mv ~/Documents/airprintfix.sh .
	mv ~/Documents/local.hostname.plist .
	chmod +x airprintfix.sh
	chmod go-w airprintfix.sh
	sudo chown root:wheel /Library/LaunchDaemons/local.hostname.airprintfix.plist
	sudo launchctl load /Library/LaunchDaemons/local.hostname.airprintfix.plist

### Running dns-sd[dns-sd]

This annoying command line program only runs as a daemon so you need to use CTRL-C to break out.

To browse all IPP services on a machine

	dns-sd -B _ipp._tcp local

Typical output might be

	$ dns-sd -B _ipp._tcp local
	Browsing for _ipp._tcp.local
	DATE: ---Sun 17 Nov 2013---
	14:17:42.275  ...STARTING...
	Timestamp     A/R    Flags  if Domain               Service Type         Instance Name
	14:17:42.275  Add        3   4 local.               _ipp._tcp.           Samsung Laser macmini

To see more about a particular service you need to know the service name from the last column of the browse display

	dns-sd -L "name goes here" _ipp._tcp local

which will show the TXT output for that name

	$ dns-sd -L "Samsung ML-1630W Series @ macmini" _ipp._tcp local
	Lookup Samsung ML-1630W Series @ macmini._ipp._tcp.local
	DATE: ---Sun 17 Nov 2013---
	15:31:01.625  ...STARTING...
	15:31:02.087  Samsung\032ML-1630W\032Series\032@\032macmini._ipp._tcp.local. can be reached at macmini.local.:631 (interface 4)
	 txtvers=1 qtotal=1 rp=printers/Samsung_ML_1630W_Series ty=Samsung\ ML-1630W\ Series adminurl=https://macmini.local.:631/printers/Samsung_ML_1630W_Series note=macmini priority=0 product=\(Samsung\ ML-1630W\ Series\) pdl=application/octet-stream,application/pdf,application/postscript,image/jpeg,image/png,image/pwg-raster UUID=c0bd8783-3e06-30da-4657-11000328a59d TLS=1.2 printer-state=3 printer-type=0x9006

Note that this is a network printer on another machine.



### References

[Bonjour Browser download page](http://www.tildesoft.com)

[Apple Bonjour printer spec](https://developer.apple.com/bonjour/printing-specification/bonjourprinting-1.2.pdf)


