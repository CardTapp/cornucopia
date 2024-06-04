# frozen_string_literal: true

require 'active_support/concern'

module Cornucopia
  module SitePrism
    module ClassExtensions
      def to_capybara_node
        @__corunucopia_base_node || super
      end
    end
  end
end
