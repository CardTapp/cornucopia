# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require "faker"
require 'capybara'
require 'capybara/rspec'
require 'selenium-webdriver'
require 'site_prism'
require 'rack/file'

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
# require File.expand_path("../../config/environment", __FILE__)
require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'
# require 'rspec/autorun'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# # Checks for pending migrations before tests are run.
# # If you are not using ActiveRecord, you can remove this line.
# ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path                               = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures                 = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order                                      = "random"
end

require ::File.expand_path("../lib/cornucopia/util/configuration", File.dirname(__FILE__))

Capybara.default_driver = :selenium_chrome
Capybara.javascript_driver = :selenium_chrome
# Capybara.default_driver = :selenium_chrome_headless
# Capybara.javascript_driver = :selenium_chrome_headless
Capybara.server = :webrick

# Cornucopia::Util::Configuration.seed = 1
# Cornucopia::Util::Configuration.order_seed = 1

RSpec.configure do |config|
  config.around(:each) do |example|
    @test_seed_value = Cornucopia::Util::Configuration.seed ||
        100000000000000000000000000000000000000 + Random.new.rand(899999999999999999999999999999999999999)

    srand(@test_seed_value)

    example.run

    if (example.exception)
      puts("random seed for testing was: #{@test_seed_value}")
    end
  end
end

require ::File.expand_path("../lib/cornucopia/site_prism/element_extensions", File.dirname(__FILE__))
require ::File.expand_path("../lib/cornucopia/capybara/finder_extensions", File.dirname(__FILE__))
require ::File.expand_path("../lib/cornucopia/capybara/matcher_extensions", File.dirname(__FILE__))
require ::File.expand_path("pages/cornucopia_report_app", File.dirname(__FILE__))
require ::File.expand_path("sample_report", File.dirname(__FILE__))