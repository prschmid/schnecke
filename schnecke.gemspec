# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'schnecke/version'

Gem::Specification.new do |spec|
  spec.name          = 'schnecke'
  spec.version       = Schnecke::VERSION
  spec.authors       = ['Patrick R. Schmid']
  spec.email         = ['prschmid@gmail.com']

  spec.summary       = 'Simple and straightforward way to add slugs to ' \
                       'ActiveRecod models.'
  spec.description   = 'A simple and straightforward way to add slugs to ' \
                       'ActiveRecod models.'
  spec.homepage      = 'https://github.com/prschmid/schnecke'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the
  # 'allowed_push_host' to allow pushing to a single host or delete this
  # section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/prschmid/schnecke'
    spec.metadata['changelog_uri'] = 'https://github.com/prschmid/schnecke'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency('activerecord', '> 4.2.0')
  spec.add_dependency('activesupport', '> 4.2.0')
  spec.metadata['rubygems_mfa_required'] = 'true'
end
