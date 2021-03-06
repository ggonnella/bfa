require "rake/testtask"

$bfaversion = 1.1

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

desc "Build gem"
task :build do
  system("gem build bfa.gemspec")
end

desc "Install gem"
task :install => :build do
  system("gem install bfa")
end

desc "Rm files created by rake build"
task :clean do
  system("rm -f bfa-*.gem")
end

# make documentation generation tasks
# available only if yard gem is installed
begin
  require "yard"
  YARD::Tags::Library.define_tag("Developer notes", :developer)
  YARD::Rake::YardocTask.new do |t|
    t.files   = ['lib/**/*.rb']
    t.stats_options = ['--list-undoc']
  end
rescue LoadError
end

desc "Create a PDF documentation"
task :pdf do
  system("yard2.0 --one-file -o pdfdoc")
  system("wkhtmltopdf cover pdfdoc/cover.html "+
                     "toc "+
                     "pdfdoc/index.html "+
                     "--user-style-sheet pdfdoc/print.css "+
                     "pdfdoc/bfa-api-#$bfaversion.pdf")
end

task :enable_assertions do
  Dir.glob("lib/**/*.rb").each do |filename|
    system('sed "s/\(\s*\)# <assert> \(.*\)/'+
           '\1raise \"Assertion failed\" unless \2/" -i '+
           filename)
  end
end

task :disable_assertions do
  Dir.glob("lib/**/*.rb").each do |filename|
    system('sed "s/\(\s*\)raise \"Assertion failed\" '+
           'unless \(.*\)/\1# <assert> \2/" -i '+
           filename)
  end
end

task :enable_debug do
  Dir.glob("lib/**/*.rb").each do |filename|
    system('sed "s/\(\s*\)# <debug> \(.*\)/'+
           '\1STDERR.puts \"# debug: \"+\2/" -i '+
           filename)
  end
end

task :disable_debug do
  Dir.glob("lib/**/*.rb").each do |filename|
    system('sed "s/\(\s*\)STDERR.puts \"# debug: \"+\(.*\)'+
           '/\1# <debug> \2/" -i '+
           filename)
  end
end
