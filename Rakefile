# frozen_string_literal: true

require "bundler/gem_helper"
require "rake/clean"
require "rake/testtask"

Bundler::GemHelper.install_tasks

desc "Run tests"
task "test" => ["minitest:test", "qed:test"]

namespace "minitest" do
  desc "Run Minitest tests"
  Rake::TestTask.new do |t|
    t.pattern = "test/**/*_{test,spec}.rb"
    t.libs << "test"
    t.verbose = Rake.verbose
  end
end

namespace "qed" do
  desc "Run QED tests"
  task "test" do
    command = "qed -l bundler/setup -I lib -p coverage README.md demo"
    command += " -v" if Rake.verbose
    sh(command)
  end
end
