lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio/load_flexibility_measures/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-load-flexibility-measures'
  spec.version       = OpenStudio::LoadFlexibilityMeasures::VERSION
  spec.authors       = ['Karl Heine', 'Ryan Meyer']
  spec.email         = ['karl.heine@nrel.gov', 'ryan.meyer@nrel.gov']

  spec.summary       = 'library and measures for OpenStudio for load flexibility applications.'
  spec.description   = 'library and measures for OpenStudio for load flexibility applications.'
  spec.homepage      = 'https://openstudio.net'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.7.0'

  spec.add_dependency 'bundler', '~> 2.1'
  spec.add_dependency 'openstudio-extension', '~> 0.5.1'
  spec.add_dependency 'openstudio-standards', '~> 0.2.16.rc2'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop-performance', '~> 1.11.3'
end
