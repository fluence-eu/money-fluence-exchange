# frozen_string_literal: true

require_relative 'lib/money/fluence/exchange/version'

Gem::Specification.new do |spec|
  spec.name = 'money-fluence-exchange'
  spec.version = Money::Fluence::Exchange::VERSION
  spec.authors = ['Jonathan PHILIPPE']
  spec.email = ['jphilippe@fluence.eu']

  spec.summary = 'Money gem exchange rate integration for Fluence'
  spec.description = 'Provides exchange rate functionality for the Money gem, tailored for Fluence applications.'
  spec.homepage = 'https://github.com/fluence-eu/money-fluence-exchange'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.pkg.github.com/fluence-eu'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/fluence-eu/money-fluence-exchange'
  spec.metadata['changelog_uri'] = 'https://github.com/fluence-eu/money-fluence-exchange/blob/main/CHANGELOG.md'
  spec.metadata['github_repo'] = 'https://github.com/fluence-eu/money-fluence-exchange'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'money', '~> 6.19'
end
