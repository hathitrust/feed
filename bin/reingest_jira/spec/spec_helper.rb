require 'webmock/rspec'
require 'simplecov'
SimpleCov.start do 
  add_filter "/vendor/bundle"
end

require_relative '../reingest_jira'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end
end

WebMock.disable_net_connect!(allow_localhost: true)
