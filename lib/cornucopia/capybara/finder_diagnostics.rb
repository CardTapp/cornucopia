# frozen_string_literal: true

require ::File.expand_path("../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("../util/report_builder", File.dirname(__FILE__))
require ::File.expand_path("finder_diagnostics/find_action", File.dirname(__FILE__))
require ::File.expand_path("finder_diagnostics/find_action/found_element", File.dirname(__FILE__))

module Cornucopia
  module Capybara
    class FinderDiagnostics
      # This function calls a "finder" function with the passed in arguments on the passed in object.
      # If the function succeeds, it doesn't do anything else.
      # If the function fails, it tries to figure out why, and provide diagnostic
      # information for further analysis.
      #
      # Parameters:
      #   test_object - the object to call the finder function on.  Examples could be:
      #     self
      #     page
      #     test_finder(:find, ...)
      #   function_name - this is the "finder" function to be called.  Examples could be:
      #     all
      #     find
      #     fill_in
      #     click_link
      #     select
      #     etc.
      #   args - the arguments that you would pass into the function normally.
      #   options - the options that you would pass into the function normally.
      #
      #  Usage:
      #   Instead of calling: <test_object>.<function> <args>, <options>
      #   you would call:     test_finder <test_object>, :<function>, <args>, <options>
      def self.test_finder(test_object, function_name, *args, **options, &block)
        Cornucopia::Capybara::FinderDiagnostics::FindAction.new(test_object, {}, {}, function_name, *args, **options, &block).run
      end

      # This takes the same arguments as the #test_finder function, but
      # it will always output a diagnostic report.
      #
      # This is for the times when the finder finds something, but you
      # think that it may be wrong, or for whatever reason, you want
      # more information about it to be output.
      def self.diagnose_finder(test_object, function_name, *args, **options, &block)
        find_action = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(test_object, {}, {}, function_name, *args, **options, &block)

        results = find_action.run
        results = results.to_a if function_name == :all
        find_action.generate_report "Diagnostic report on \"#{function_name.to_s}\":", nil

        results
      end
    end
  end
end
