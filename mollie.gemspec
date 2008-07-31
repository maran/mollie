require 'rubygems'
 
SPEC = Gem::Specification.new do |s|
   s.name = "Mollie"
   s.version = "0.0.1"
   s.author = "Tom-Eric Gerritsen"
   s.email = "tomeric@i76.nl"
   s.homepage = "http://github.com/i76/mollie/tree/master"
   s.platform = Gem::Platform::RUBY
   s.summary = "A library for sending SMSes using the Mollie.nl SMS gateway"
   candidates = Dir.glob("{bin,docs,lib,tests}/**/*")
   s.files = candidates.delete_if do |item|
      item.include?("CVS") || item.include?("rdoc")
   end
   s.require_path = "lib"
   s.autorequire = "mollie"
   s.has_rdoc = true
   s.extra_rdoc_files = ["README"]
end