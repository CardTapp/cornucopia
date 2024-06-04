# frozen_string_literal: true

require ::File.expand_path("../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("finder_diagnostics", File.dirname(__FILE__))

require "active_support/concern"

module Cornucopia
  module Capybara
    module FinderExtensions
      extend ActiveSupport::Concern

      def find(*args, **options, &block)
        retry_count = 0
        result      = nil

        support_options, normal_options = __cornucopia__extract_support_options(**options)

        begin
          retry_count += 1
          result      = super(*args, **normal_options, &block) if __cornucopia__call_super?(:find, *args, **normal_options, &block)
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          retry if __cornucopia__retry_finder?(retry_count, support_options)

          result = __cornucopia__analyze_finder(:find, support_options, *args, **normal_options, &block)
        rescue StandardError
          result = __cornucopia__analyze_finder(:find, support_options, *args, **normal_options, &block)
        end

        result
      end

      def all(*args, **options, &block)
        retry_count = 0
        result      = nil

        support_options, normal_options = __cornucopia__extract_support_options(**options)

        begin
          retry_count += 1
          result      = super(*args, **normal_options, &block) if __cornucopia__call_super?(:all, *args, **normal_options, &block)
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          retry if __cornucopia__retry_finder?(retry_count, support_options)

          result = __cornucopia__analyze_finder(:all, support_options, *args, **normal_options, &block)
        rescue StandardError
          result = __cornucopia__analyze_finder(:all, support_options, *args, **normal_options, &block)
        end

        result
      end

      private

      def __cornucopia__extract_support_options(**options)
        support_options = options.slice(:__cornucopia_no_analysis, :__cornucopia_retry_with_found)
        normal_options  = options.slice(*(options.keys - %i[__cornucopia_no_analysis __cornucopia_retry_with_found]))

        [support_options, normal_options]
      end

      def __cornucopia__analyze_finder(function_name, support_options, *args, **options, &block)
        return_value = nil
        error        = $!

        if !support_options[:__cornucopia_no_analysis] &&
            (Cornucopia::Util::Configuration.analyze_find_exceptions ||
                support_options[:__cornucopia_retry_with_found])
          # || support_options[:__cornucopia_alternate_retry])
          support_options.merge!({ __cornucopia_no_analysis: true })

          find_action = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(self,
                                                                                {},
                                                                                support_options,
                                                                                function_name,
                                                                                *args,
                                                                                **options,
                                                                                &block)

          if find_action.perform_analysis(Cornucopia::Util::Configuration.retry_with_found ||
                                              support_options[:__cornucopia_retry_with_found])
            #                                 Cornucopia::Util::Configuration.alternate_retry ||
            #                                     support_options[:__cornucopia_alternate_retry])
            return_value = find_action.simple_run({ __cornucopia_no_analysis: true }) rescue nil
            return_value ||= find_action.return_value
          else
            raise error
          end
        else
          raise error
        end

        return_value
      end

      def __cornucopia__retry_finder?(retry_count, support_options)
        retry_count <= Cornucopia::Util::Configuration.selenium_cache_retry_count &&
            !support_options[:__cornucopia_no_analysis]
      end

      def __cornucopia__call_super?(_function_name, *_args, **_normal_options, &_block)
        true
      end
    end
  end
end
