# frozen_string_literal: true

require ::File.expand_path("../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("finder_diagnostics", File.dirname(__FILE__))

require "active_support/concern"

module Cornucopia
  module Capybara
    module MatcherExtensions
      extend ActiveSupport::Concern

      def assert_selector(*args, &block)
        retry_count    = 0
        result         = nil
        no_option_args = args.clone
        options        = no_option_args.pop if no_option_args.last.is_a?(Hash)
        options        ||= {}

        support_options, normal_options = __cornucopia__extract_selector_support_options(**options)

        begin
          retry_count += 1
          if __cornucopia__call_super?(:assert_selector, *no_option_args, **normal_options, &block)
            result = super(*no_option_args, normal_options, &block)
          end
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          retry if __cornucopia__retry_selector?(retry_count, support_options)

          result = __cornucopia__analyze_selector(:assert_selector, support_options, *no_option_args, **normal_options)
        rescue
          result = __cornucopia__analyze_selector(:assert_selector, support_options, *no_option_args, **normal_options)
        end

        result
      end

      def assert_no_selector(*args, &block)
        retry_count    = 0
        result         = nil
        no_option_args = args.clone
        options        = no_option_args.pop if no_option_args.last.is_a?(Hash)
        options        ||= {}

        support_options, normal_options = __cornucopia__extract_selector_support_options(**options)

        begin
          retry_count += 1
          if __cornucopia__call_super?(:assert_no_selector, *no_option_args, **normal_options, &block)
            result = super(*no_option_args, **normal_options, &block)
          end
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          retry if __cornucopia__retry_selector?(retry_count, support_options)

          result = __cornucopia__analyze_selector(:assert_no_selector, support_options, *no_option_args, **normal_options)
        rescue
          result = __cornucopia__analyze_selector(:assert_no_selector, support_options, *no_option_args, **normal_options)
        end

        result
      end

      def has_selector?(*args, **options, &block)
        new_args    = args.dup
        retry_count = 0
        result      = nil

        support_options, normal_options = __cornucopia__extract_selector_support_options(**options)

        begin
          retry_count += 1
          if __cornucopia__call_super?(:has_selector?, *new_args, **options, &block)
            __cornucopia_with_no_analysis do
              result = super(*new_args, **options, &block)

              unless Cornucopia::Util::Configuration.ignore_has_selector_errors
                result ||= __cornucopia__analyze_selector(:has_no_selector?, support_options, *new_args, **normal_options)
              end
            end
          end
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          retry if __cornucopia__retry_selector?(retry_count, support_options)

          result = __cornucopia__analyze_selector(:has_selector?, support_options, *new_args, **normal_options)
        rescue
          result = __cornucopia__analyze_selector(:has_selector?, support_options, *new_args, **normal_options)
        end

        result
      end

      def has_no_selector?(*args, **options, &block)
        new_args    = args.dup
        retry_count = 0
        result      = nil

        support_options, normal_options = __cornucopia__extract_selector_support_options(**options)

        begin
          retry_count += 1
          if __cornucopia__call_super?(:has_no_selector?, *new_args, **options, &block)
            __cornucopia_with_no_analysis do
              result = super(*new_args, **options, &block)

              unless Cornucopia::Util::Configuration.ignore_has_selector_errors
                result ||= __cornucopia__analyze_selector(:has_no_selector?, support_options, *new_args, **normal_options)
              end
            end
          end
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          retry if __cornucopia__retry_selector?(retry_count, support_options)

          result = __cornucopia__analyze_selector(:has_no_selector?, support_options, *new_args, **normal_options)
        rescue
          result = __cornucopia__analyze_selector(:has_no_selector?, support_options, *new_args, **normal_options)
        end

        result
      end

      private

      attr_reader :__cornucopia_block_analysis

      def __cornucopia__call_super?(_funciton_name, *_args, **_options, &_block)
        true
      end

      def __cornucopia__extract_selector_support_options(**options)
        support_options = options.slice(:__cornucopia_no_analysis, :__cornucopia_retry_with_found)
        normal_options  = options.slice(*(options.keys - %i[__cornucopia_no_analysis __cornucopia_retry_with_found]))

        support_options[:__cornucopia_no_analysis] = true if __cornucopia_block_analysis

        [support_options, normal_options]
      end

      def __cornucopia__analyze_selector(function_name, support_options, *args, **options)
        return_value = nil
        error        = $!

        if !support_options[:__cornucopia_no_analysis] &&
            (Cornucopia::Util::Configuration.analyze_selector_exceptions ||
                support_options[:__cornucopia_retry_with_found])
          support_options.merge!({ __cornucopia_no_analysis: true })

          find_action = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(self,
                                                                                {},
                                                                                support_options,
                                                                                function_name,
                                                                                *args,
                                                                                **options)

          if find_action.perform_analysis(Cornucopia::Util::Configuration.retry_match_with_found ||
                                              support_options[:__cornucopia_retry_with_found])
            return_value = find_action.simple_run({ __cornucopia_no_analysis: true }) rescue nil
            return_value ||= find_action.return_value
          else
            raise error if error
          end
        else
          raise error if error
        end

        return_value
      end

      def __cornucopia__retry_selector?(retry_count, support_options)
        retry_count <= Cornucopia::Util::Configuration.selenium_cache_retry_count &&
            !support_options[:__cornucopia_no_analysis]
      end

      def __cornucopia_with_no_analysis
        orig_block = __cornucopia_block_analysis

        begin
          @__cornucopia_block_analysis = true
          yield
        ensure
          @__cornucopia_block_analysis = orig_block
        end
      end
    end
  end
end
