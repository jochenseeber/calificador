# frozen_string_literal: true

LIB_DIR = File.join(__dir__, "lib")
$LOAD_PATH.unshift(LIB_DIR) unless $LOAD_PATH.include?(LIB_DIR)

require "calificador/version"
require "json"
require "pathname"

Gem::Specification.new do |spec|
  raise "RubyGems 2.0 or newer is required." unless spec.respond_to?(:metadata)

  spec.name = "calificador"
  spec.version = Calificador::VERSION
  spec.summary = "Concise and readable unit tests"

  spec.required_ruby_version = ">= 2.7"

  spec.authors = ["Jochen Seeber"]
  spec.email = ["jochen@seeber.me"]
  spec.homepage = "https://github.com/jochenseeber/calificador"

  spec.metadata["issue_tracker"] = "https://github.com/jochenseeber/calificador/issues"
  spec.metadata["documentation"] = "http://jochenseeber.github.com/calificador"
  spec.metadata["source_code"] = "https://github.com/jochenseeber/calificador"
  spec.metadata["wiki"] = "https://github.com/jochenseeber/calificador/wiki"

  spec.files = Dir[
    "*.gemspec",
    "*.md",
    "*.txt",
    "lib/**/*.rb",
  ]

  spec.require_paths = [
    "lib",
  ]

  spec.bindir = "cmd"
  spec.executables = spec.files.filter { |f| File.dirname(f) == "cmd" && File.file?(f) }.map { |f| File.basename(f) }

  spec.add_dependency "minitest", "~> 5.14"
  spec.add_dependency "zeitwerk", "~> 2.3"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "debase", "~> 0.2"
  spec.add_development_dependency "qed", "~> 2.9"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", ">= 0.85"
  spec.add_development_dependency "rubocop-rake", ">= 0.5.1"
  spec.add_development_dependency "ruby-debug-ide", "~> 0.7"
  spec.add_development_dependency "simplecov", "~> 0.18"
  spec.add_development_dependency "yard", "~> 0.9"
end
