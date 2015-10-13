@@ -0,0 +1,225 @@
#!/usr/bin/ruby
#
#


# Let's have some variable.
input_dir = '/tmp/BL'
output_dir = '/etc/bind/rpz'

zone_file = '/etc/bind/zone.rpz'

# Here your named header
# You can change it
$zone_header = "$TTL    604800
@ IN SOA localhost.local. hostmaster.local. (
	$SERIAL$	; Serial
	604800		; Refresh
	86400		; Retry
	2419200		; Expire
	604800		; Negative Cache TTL
);

@       IN      NS      localhost.local.
@       IN      A       127.0.0.1
@       IN      AAAA    ::1

"


# List of shalla's file to parse
rpz = [
	'adv',
	'aggressive',
	'alcohol',
	'anonvpn',
#	'automobile/bikes',
#	'automobile/boats',
#	'automobile/cars',
#	'automobile/planes',
#	'chat',
	'costtraps',
#	'dating',
#	'downloads',
	'drugs',
	'dynamic',
#	'education/schools',
#	'finance/banking',
#	'finance/insurance',
#	'finance/moneylending',
#	'finance/other',
#	'finance/realestate',
	'finance/trading',
	'fortunetelling',
#	'forum',
	'gamble',
#	'government',
	'hacking',
#	'hobby/cooking',
	'hobby/games-misc',
	'hobby/games-online',
#	'hobby/gardening',
#	'hobby/pets',
#	'homestyle',
#	'hospitals',
#	'imagehosting',
#	'isp',
#	'jobsearch',
#	'library',
#	'military',
#	'models',
#	'movies',
#	'music',
#	'news',
#	'podcasts',
#	'politics',
	'porn',
#	'radiotv',
#	'recreation/humor',
#	'recreation/martialarts',
#	'recreation/restaurants',
#	'recreation/sports',
#	'recreation/travel',
#	'recreation/wellness',
	'redirector',
#	'religion',
	'remotecontrol',
	'ringtones',
#	'science/astronomy',
#	'science/chemistry',
#	'searchengines',
	'sex/education',
	'sex/lingerie',
#	'shopping',
#	'socialnet',
	'spyware',
#	'tracker',
#	'updatesites',
	'urlshortener',
	'violence',
	'warez',
	'weapons',
#	'webmail',
#	'webphone',
#	'webradio',
#	'webtv',
]

# List of domains to remove from shalla's list
$dns_ok = [
	'proxad.net',
	'zone-telechargement.com',
	'libertyland.tv',
	'list-manage.com',
	'mailchimp.com',
	'googleadservices.com',
	'teamviewer.com',
	'play.google.com',
	'dl-protect.com',
	'boursorama.com'
]

# Save in 'filename' the list of domains in RPZ format
#-----------------------------------------------------------------------------
def write_rpz_domain(fd, domain)
	if domain[-1] == '.' then
		domain = domain[0..-2]
	end
	if domain[0] == '.' then
		domain = domain[1..-1]
	end
	return unless /[\.]/.match(domain)
	fd.write(domain + " IN CNAME .\n")
	fd.write("*." + domain + " IN CNAME .\n")
end

# Parse a shalla input file and write its content in a new RPZ file.
#  - Removes all characters after / (including '/')
#  - removes all IP address (not usable by RPZ)
#-----------------------------------------------------------------------------
def convert_file(input, output)
	nb = 0
	fd = File.new(output, "w")

	File.foreach(input) { |address|
		address.chop!
		if not /^\d+\.\d+\.\d+\.\d+$/.match(address) then
			if not $dns_ok.include?(address) then
				write_rpz_domain(fd, address)
				nb = nb + 1
			end
		end
	}
	fd.close
	nb
end

# Reads the old zone file and looks for the current serial
# Returns the serial if found
# The SOA line must be of the form :
# @ IN SOA ... (
# and the serial must be on the following line
#-----------------------------------------------------------------------------
def get_zone_serial(file)
	found_soa = false
	File.foreach(file) { |line|
		if not found_soa then
			found_soa = true if /^@\s+IN\s+SOA/.match(line)
		else
			if /^\s*(\d{10})\s+/.match(line) then
				return $1
			end
		end
	}
end

# Increment the serial of zone file.
# If same day, only increment counter, else use the new day...
#-----------------------------------------------------------------------------
def inc_zone_serial(s)
	now = Time.new
	/(\d{4})(\d{2})(\d{2})(\d{2})/.match(s)
	y = $1.to_i
	m = $2.to_i
	d = $3.to_i
	c = $4.to_i
	c = (y != now.year or m != now.month or d != now.day) ? 1 : c + 1
	sprintf("%d%02d%02d%02d", now.year, now.month, now.day, c)
end

# Generates a new zone.rpz file in /etc/bind
# Backup the file and increments the serial
# Provide one line per include of RPZ list file made from shalla domains list
#-----------------------------------------------------------------------------
def gen_zone_file(f, outputs)
	serial = get_zone_serial(f)
	if serial then
		File.rename(f, f + '.bak')
		new_serial = inc_zone_serial(serial)
		fd = File.new(f, 'w')
		fd.write($zone_header.gsub("$SERIAL$", new_serial))
		fd.write("\n")
		fd.write("$INCLUDE \"/etc/bind/rpz/local\";\n\n")
		outputs.each { |out|
			fd.write("$INCLUDE \"#{out}\";\n")
		}
	else
		puts("No serial found in #{f}")
	end
end

total = 0
outputs= Array.new
#-----------------------------------------------------------------------------
rpz.each { |dir|
	input = input_dir + '/' + dir + '/domains'
	output = output_dir + '/' + dir.gsub('/', '-')
	outputs.push output
	nb = convert_file(input, output)
	total = total + nb
	puts("Parsed #{nb} entries in file #{input}")
}
puts("Total number of entries: #{total}")

gen_zone_file(zone_file, outputs)
