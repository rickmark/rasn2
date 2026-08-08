# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in rasn1.gemspec
gemspec

gem 'bundler'

group :development do
  gem 'debug'
  gem 'ruby-lsp', require: false
  gem 'ruby-lsp-rspec', require: false
  gem 'yard'
end

group :test do
  gem 'rspec'
  gem 'simplecov'
end

group :development, :test do
  gem 'rake'
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
end
