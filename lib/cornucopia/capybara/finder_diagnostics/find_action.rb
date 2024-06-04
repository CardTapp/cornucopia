# frozen_string_literal: true

require ::File.expand_path("../../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("../../util/report_builder", File.dirname(__FILE__))
require ::File.expand_path("find_action/found_element", File.dirname(__FILE__))

module Cornucopia
  module Capybara
    class FinderDiagnostics
      # At the end of the day, almost everything in Capybara calls all to find the element that needs
      # to be worked on.  The main difference is if it is synchronized or not.
      #
      # The FindAction class also uses all, but it is never synchronized, and its primary purpose
      # is really to output a bunch of diagnostic information to try to help you do a postmortem on
      # just what is happening.
      #
      # A lot of things could be happening, so a lot of information is output, not all of which is
      # relevant or even useful in every situation.
      #
      # The first thing output is the error (the problem)
      # Then what action was being tried is output (context)
      #
      # In case the problem was with finding the desired element, a list of all elements which
      # could be found using the passed in parameters is output.
      #
      # In case the problem was with context (inside a within block on purpose or accidentally)
      # a list of all other elements which could be found on the page using the passed in
      # parameters is output.
      #
      # In case the problem is something else, we output a screenshot and the page HTML.
      #
      # In case the problem has now solved itself, we try the action again.  (This has a very low
      # probability of working as this basically devolves to just duplicating what Capybara is already doing,
      # but it seems like it is worth a shot at least...)
      #
      # In case the problem is a driver bug (specifically Selenium which has some known issues) and
      # is in fact why I even bother trying to do this, try performing the action via javascript.
      # NOTE:  As noted in many blogs this type of workaround is not generally a good idea as it can
      #        result in false-positives.  However since Selenium is buggy, this is the
      #        best solution I have other than going to capybara-webkit or poltergeist
      class FindAction
        @@diagnosed_finders = {}

        Cornucopia::Util::ReportBuilder.on_close do
          Cornucopia::Capybara::FinderDiagnostics::FindAction.clear_diagnosed_finders
        end

        # Clears the class variable @@diagnosed_finders between tests if called.
        # This is done so that finder analysis is called at least once per test.
        def self.clear_diagnosed_finders
          @@diagnosed_finders = {}
        end

        attr_accessor :return_value
        attr_accessor :support_options

        def initialize(test_object, report_options, support_options, function_name, *args, **options, &block)
          @test_object     = test_object
          @function_name   = function_name
          @args            = args
          @block           = block
          @support_options = support_options
          @options         = options
          @report_options  = report_options || {}

          @report_options[:report] ||= Cornucopia::Util::ReportBuilder.current_report
        end

        def run
          begin
            simple_run
          rescue
            error = $!
            if perform_analysis(support_options[:__cornucopia_retry_with_found])
              # Cornucopia::Util::Configuration.alternate_retry)
              @return_value
            else
              raise error
            end
          end
        end

        def simple_run(cornucopia_args = {})
          simple_run_args    = args.clone
          simple_run_options = options.clone.merge(cornucopia_args)

          test_object.send(function_name, *simple_run_args, **simple_run_options)
        end

        # def can_dump_details?(attempt_retry, attempt_alternate_retry)
        def can_dump_details?(attempt_retry)
          can_dump = false

          if (Object.const_defined?("Capybara"))
            can_dump = !@@diagnosed_finders.keys.include?(dump_detail_args(attempt_retry))
          end

          can_dump
        end

        def capybara_session
          if Object.const_defined?("::Capybara") &&
              ::Capybara.send(:session_pool).present?
            my_page = ::Capybara.current_session

            my_page if (my_page && my_page.current_url.present? && my_page.current_url != "about:blank")
          end
        rescue StandardError
          nil
        end

        # def dump_detail_args(attempt_retry, attempt_alternate_retry)
        def dump_detail_args(attempt_retry)
          check_args = search_args.clone
          my_page    = capybara_session

          check_args << options.clone
          check_args << !!attempt_retry
          # check_args << !!attempt_alternate_retry

          if (my_page && my_page.current_url.present? && my_page.current_url != "about:blank")
            check_args << Digest::SHA2.hexdigest(my_page.html)
          end

          check_args
        end

        # def perform_retry(attempt_retry, attempt_alternate_retry, report, report_table)
        def perform_retry(attempt_retry, report, report_table)
          retry_successful = false

          if attempt_retry && retry_action_with_found_element(report, report_table)
            retry_successful = true
            # else
            #   if attempt_alternate_retry && alternate_action_with_found_element(report, report_table)
            #     retry_successful = true
            #   end
          end

          retry_successful
        end

        # def perform_analysis(attempt_retry, attempt_alternate_retry)
        def perform_analysis(attempt_retry)
          retry_successful = false

          time = Benchmark.measure do
            puts "  Cornucopia::FinderDiagnostics::perform_analysis" if Cornucopia::Util::Configuration.benchmark

            if can_dump_details?(attempt_retry)
              generate_report "An error occurred while processing \"#{function_name.to_s}\":",
                              $! do |report, report_table|
                retry_successful = perform_retry(attempt_retry, report, report_table)
              end

              dump_args                      = dump_detail_args(attempt_retry)
              @@diagnosed_finders[dump_args] = { tried: true }
            else
              retry_successful = perform_retry(attempt_retry, nil, nil)
            end
          end

          puts "  Cornucopia::FinderDiagnostics::perform_analysis time: #{time}" if Cornucopia::Util::Configuration.benchmark

          retry_successful
        end

        def generate_report(message, error = nil, &block)
          if report_options[:report] && report_options[:table]
            generate_report_in_table report_options[:table], error, &block
          else
            report_options[:report] ||= Cornucopia::Util::ReportBuilder.current_report
            report_options[:table]  = nil

            report_options[:report].within_section(message) do |_report|
              generate_report_in_table report_options[:table], error, &block
            end
          end
        end

        def generate_report_in_table(table, error = nil, &block)
          report_options[:table] = table

          init_search_args
          all_elements
          all_other_elements
          guessed_types

          configured_report = Cornucopia::Util::Configuration.report_configuration(:capybara_finder_diagnostics)

          configured_report.add_report_objects(finder: self, exception: error)
          configured_report.generate_report(report_options[:report], report_table: report_options[:table], &block)
        end

        def retry_action_with_found_element report, report_table
          return_result = false
          result        = "Failed"

          case function_name.to_s
            when "assert_selector"
              if found_element
                @return_value = true
                return_result = true
                result        = "Found"
              end

            when "assert_no_selector"
              unless found_element
                @return_value = true
                return_result = true
                result        = "Not Found"
              end

            when "find", "all"
              if found_element
                result = "Success"

                @return_value = found_element

                return_result = true
              end
          end

          report_table.write_stats "Retrying action:", result if report_table && return_result

          return_result
        end

        # def alternate_action_with_found_element report, report_table
        #   return_result = false
        #
        #   result = "Could not attempt to try the action through an alternate method."
        #   if found_element &&
        #       ::Capybara.current_session.respond_to?(:evaluate_script)
        #     begin
        #       native_id = get_attribute found_element, "id"
        #       if (native_id)
        #         case function_name.to_s
        #           when "click_link_or_button", "click_link", "click_button"
        #             @return_value = ::Capybara.current_session.evaluate_script("$(\"\##{native_id}\")[0].click()")
        #           when "fill_in"
        #             @return_value = ::Capybara.current_session.evaluate_script("$(\"\##{native_id}\")[0].val(\"#{options[:with]}\")")
        #           when "choose", "check"
        #             @return_value = ::Capybara.current_session.evaluate_script("$(\"\##{native_id}\")[0].val(\"checked\", true)")
        #           when "uncheck"
        #             @return_value = ::Capybara.current_session.evaluate_script("$(\"\##{native_id}\")[0].val(\"checked\", false)")
        #           when "select"
        #             @return_value = ::Capybara.current_session.evaluate_script("$(\"\##{native_id}\")[0].val(\"selected\", true)")
        #           when "unselect"
        #             @return_value = ::Capybara.current_session.evaluate_script("$(\"\##{native_id}\")[0].val(\"selected\", false)")
        #           else
        #             result = "Could not decide what to do with #{function_name}"
        #             raise new Exception("unknown action")
        #         end
        #
        #         return_result = true
        #       end
        #     rescue
        #       result ||= "Still couldn't do the action - #{$!.to_s}."
        #     end
        #   end
        #
        #   report_table.write_stats "Trying alternate action:", result if report_table
        #   return_result
        # end

        def found_element
          if function_name.to_sym == :all
            all_elements.map(&:found_element)
          else
            if all_elements && all_elements.length == 1
              all_elements[0].try(:found_element)
            else
              nil
            end
          end
        end

        def all_elements
          unless @all_elements
            all_options = options.clone

            if all_options && all_options.has_key?(:from)
              from_within = nil

              report_options[:report].within_table(report_table: report_options[:table]) do |report_table|
                Cornucopia::Util::ReportTable.new(nested_table:       report_table,
                                                  nested_table_label: "Within block:") do |sub_report|
                  sub_report_options         = report_options.clone
                  sub_report_options[:table] = sub_report
                  from_within                = Cornucopia::Capybara::FinderDiagnostics::FindAction.
                      new(test_object,
                          sub_report_options,
                          {},
                          :find,
                          :select,
                          all_options[:from])

                  from_within.generate_report_in_table(sub_report, nil)
                end
              end

              from_element = from_within.found_element
              if search_args[0].is_a?(Symbol)
                search_args[0] = :option
              end
              all_options.delete(:from)

              unless from_element
                @all_elements = []
                return @all_elements
              end
            else
              from_element = test_object
            end

            begin
              @all_elements = from_element.all(*search_args, **all_options.merge(visible: false, __cornucopia_no_analysis: true)).to_a
            rescue
              @all_elements = []
            end

            if @all_elements
              @all_elements = @all_elements.map do |element|
                FoundElement.new(element)
              end.compact
            end
          end

          @all_elements
        end

        def all_other_elements
          unless @all_other_elements
            from_element = capybara_session
            all_options  = options.clone
            all_options.delete :from

            return unless from_element

            begin
              @all_other_elements = from_element.all(*search_args, **all_options.merge(visible: false, __cornucopia_no_analysis: true)).to_a
            rescue
              @all_other_elements = []
            end

            if @all_other_elements
              @all_other_elements = @all_other_elements.map do |element|
                FoundElement.new(element) unless all_elements.include?(element)
              end

              @all_other_elements = @all_other_elements - @all_elements
              @all_other_elements.compact!
            end
          end

          @all_other_elements
        end

        def search_args
          init_search_args
          @search_args
        end

        def options
          init_search_args
          @options
        end

        def init_search_args
          unless @search_args
            @search_args = args.clone

            if guessed_types.length > 0 && @search_args[0] != guessed_types[0]
              @search_args.insert(0, guessed_types[0])
            end
            if guessed_types.length <= 0 && @search_args[0] != ::Capybara.default_selector
              @search_args.insert(0, ::Capybara.default_selector)
            end
          end
        end

        # a list of guesses as to what kind of object is being searched for
        def guessed_types
          unless @guessed_types
            if search_args.length > 0
              if search_args[0].is_a?(Symbol)
                @guessed_types = [search_args[0]]
              else
                @guessed_types = %i[id css xpath link_or_button fillable_field radio_button checkbox select option
                                    file_field table field fieldset content].select do |test_type|
                  begin
                    test_object.all(test_type, *search_args, **options.merge(visible: false, __cornucopia_no_analysis: true)).length > 0
                  rescue
                    # Normally bad form, but for this function, we just don't want this to throw errors.
                    # We are only concerned with whatever actually succeeds.
                    false
                  end
                end
              end
            end
          end

          @guessed_types
        end

        private

        attr_reader :test_object,
                    :function_name,
                    :args,
                    :block,
                    :report_options
      end
    end
  end
end
