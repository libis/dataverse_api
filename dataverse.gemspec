# frozen_string_literal: true

require_relative "lib/dataverse/version"

Gem::Specification.new do |spec|
  spec.name          = "dataverse"
  spec.version       = Dataverse::VERSION
  spec.authors       = ["Kris Dekeyser"]
  spec.email         = ["kris.dekeyser@libis.be"]

  spec.summary       = "Dataverse API."
  spec.description   = "Dataverse.org API wrapper."
  spec.homepage      = "https://rubygems.org/gems/dataverse"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/libis/dataverse_api"
  spec.metadata["changelog_uri"] = "https://github.com/libis/dataverse_api/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rest-client", "~> 2.0"
end
