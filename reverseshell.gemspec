Gem::Specification.new() do |s|
    s.name = "reverse-shell"
    s.version = "1.4.0"
    s.summary = "A tool for generating backdoor"
    s.files = ["bin/reverse-shell.rb"]
    s.authors = ["Krish Pranav"]
    s.email = ""
    s.executables << "reverse-shell.rb"
    s.homepage = "https://github.com/krishpranav/rb-reverse-shell"
    s.required_ruby_version = ">= 2.7.1"
    s.requirements << "A GNU/Linux or BSD operating system. Optional requirements are GCC (for C payloads), OpenJDK (for Java payloads) and Rust (for Rust payloads)."
end
