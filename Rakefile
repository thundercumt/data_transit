# 
# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.
 

require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rubygems/package_task'
require 'rdoc/task'
require 'rake/testtask'

spec = Gem::Specification.new do |s|
  s.name = 'data_transit'
  s.version = '0.2.0'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README', 'LICENSE']
  s.summary = 'a ruby gem/app used to migrate between databases, supporting customized migration procedure'
  s.description = 'data_transit relies on activerecord to generate database Models on the fly. Tt is executed within a database transaction, and should any error occur during data transit, it will cause the transaction to rollback. So don\'t worry about introducing dirty data into your target database'
  s.author = 'thundercumt'
  s.email = 'thundercumt@126.com'
  s.homepage = 'https://github.com/thundercumt/data_transit'
  s.executables << "data_transit"
  s.files = %w(LICENSE README Rakefile Database.yml) + Dir.glob("{bin,lib,spec}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
end

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

Rake::RDocTask.new do |rdoc|
  files =['README', 'LICENSE', 'lib/**/*.rb']
  rdoc.rdoc_files.add(files)
  rdoc.main = "README" # page to start on
  rdoc.title = "Data_Transit Docs"
  rdoc.rdoc_dir = 'doc/rdoc' # rdoc output folder
  rdoc.options << '--line-numbers'
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*.rb']
end
