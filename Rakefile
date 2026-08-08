# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new

YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb', '-', 'README.md', 'LICENSE']
  t.options = %w[--no-private]
end

RuboCop::RakeTask.new do |task|
  task.patterns = ['lib/**/*.rb']
end

task default: :spec