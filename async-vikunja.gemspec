# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Nathan Kidd.

version = File.read(File.expand_path("lib/async/vikunja/version.rb", __dir__))[/VERSION = "([^"]+)"/, 1]

Gem::Specification.new do |spec|
  spec.name = "async-vikunja"
  spec.version = version
  spec.authors = ["Nathan Kidd"]
  spec.email = ["nathankidd@hey.com"]
  spec.license = "MIT"

  spec.summary = "An asynchronous Ruby client for the Vikunja API."
  spec.homepage = "https://github.com/n-at-han-k/async-vikunja"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob(
    ["lib/**/*", "license.md", "README.md"],
    File::FNM_DOTMATCH,
    base: __dir__,
  )

  spec.require_paths = ["lib"]

  spec.add_dependency "async-rest", "~> 0.20"

  spec.add_dependency "gem_kit", "~> 0.2"
end
