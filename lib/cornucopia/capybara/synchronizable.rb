# frozen_string_literal: true

require ::File.expand_path("../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("finder_diagnostics", File.dirname(__FILE__))

require "active_support/concern"

module Cornucopia
  module Capybara
    module Synchronizable
      extend ActiveSupport::Concern

      # This function uses Capybara's synchronize function to evaluate a block until
      # it becomes true.
      def synchronize_test(seconds = nil, options = {}, &block)
        seconds ||= ::Capybara.respond_to?(:default_max_wait_time) ? ::Capybara.default_max_wait_time : ::Capybara.default_wait_time

        document.synchronize(seconds, **options) do
          raise ::Capybara::ElementNotFound unless block.yield
        end
      end
    end
  end
end
