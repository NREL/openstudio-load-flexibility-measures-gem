source 'http://rubygems.org'

gemspec

if File.exist?('../openstudio-standards')
  gem 'openstudio-standards', path: '../openstudio-standards'
else
  gem 'openstudio-standards', github: 'NREL/openstudio-standards', branch: 'master'
end
