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

