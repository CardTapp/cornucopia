# frozen_string_literal: true

require "digest"
# require ::File.expand_path("../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("../util/report_builder", File.dirname(__FILE__))
require ::File.expand_path("../util/report_table", File.dirname(__FILE__))
require ::File.expand_path("page_diagnostics/window_iterator", File.dirname(__FILE__))

module Cornucopia
  module Capybara
    class PageDiagnostics
      @@dumped_pages = []

      Cornucopia::Util::ReportBuilder.on_close do
        Cornucopia::Capybara::PageDiagnostics.clear_dumped_pages
      end

      attr_accessor :allow_other_windows

      class << self
        # This outputs the details about the current Capybara page to
        # the current report.
        def dump_details(options = {})
          Cornucopia::Capybara::PageDiagnostics.new(options).dump_details
        end

        def dump_details_in_table(report, report_table, options = {})
          Cornucopia::Capybara::PageDiagnostics.new(options.merge(report: report, table: report_table)).dump_details
        end

        def clear_dumped_pages
          @@dumped_pages = []
        end
      end

      def initialize(options = {})
        @options             = options.clone
        @report              = @options.delete(:report)
        @table               = @options.delete(:table)
        @unsupported_list    ||= []
        @allow_other_windows = true

        @page_url         = "use accessor"
        @title            = "use accessor"
        @page_width       = "use accessor"
        @page_height      = "use accessor"
        @response_headers = "use accessor"
        @status_code      = "use accessor"
        @html_source      = "use accessor"
        @html_frame       = "use accessor"
        @screen_shot      = "use accessor"
        @html_file        = "use accessor"
        @browser_logs     = "use accessor"
        @browser_info     = "use accessor"
        @all_cookies      = "use accessor"
      end

      def can_dump_details?
        can_dump = false

        if Object.const_defined?("::Capybara") &&
            ::Capybara.send(:session_pool).present?
          my_page = ::Capybara.current_session

          if (my_page && my_page.current_url.present? && my_page.current_url != "about:blank")
            can_dump = !@@dumped_pages.include?(Digest::SHA2.hexdigest(my_page.html))
          end
        end

        can_dump
      rescue StandardError
        false
      end

      def dump_details
        if can_dump_details?
          if @report && @table
            dump_details_in_table
          else
            @report       = Cornucopia::Util::ReportBuilder.current_report
            section_title = @options[:section_label] || "Page Dump:"

            @report.within_section(section_title) do
              @table = nil
              dump_details_in_table
            end
          end
        end
      end

      def dump_details_in_table
        if can_dump_details?
          @session = ::Capybara.current_session
          @driver  = @session.driver

          @current_window = execute_driver_function(:current_window_handle, nil)
          @window_handles = execute_driver_function(:window_handles, [1]).clone

          configured_report = Cornucopia::Util::Configuration.report_configuration(:capybara_page_diagnostics)

          configured_report.add_report_objects(capybara: self)
          configured_report.generate_report(@report, report_table: @table)

          @@dumped_pages << Digest::SHA2.hexdigest(@session.html)
        end
      end

      def other_windows
        if @allow_other_windows
          Cornucopia::Capybara::PageDiagnostics::WindowIterator.new(@window_handles, @current_window, self)
        end
      end

      def execute_driver_function(function_symbol, unsupported_value, *args)
        value = unsupported_value

        @unsupported_list << function_symbol unless @driver.respond_to?(function_symbol)

        begin
          unless @unsupported_list.include?(function_symbol)
            value = @driver.send(function_symbol, *args)
          end
        rescue ::Capybara::NotSupportedByDriverError
          @unsupported_list << function_symbol
        end

        value
      end

      def execute_browser_function(function_symbol, unsupported_value, *args)
        value = unsupported_value

        unless @driver.browser.respond_to?(function_symbol) ||
            @driver.browser.manage.respond_to?(function_symbol)
          @unsupported_list << function_symbol unless @driver.browser.respond_to?(function_symbol)
        end

        begin
          unless @unsupported_list.include?(function_symbol)
            value = if @driver.browser.respond_to?(function_symbol)
                      @driver.browser.send(function_symbol, *args)
                    else
                      @driver.browser.manage.send(function_symbol, *args)
                    end
          end
        rescue ::Capybara::NotSupportedByDriverError
          @unsupported_list << function_symbol
        end

        value
      end

      def browser_logs
        value = execute_browser_function(:logs, nil)

        types = value.available_types
        types.each_with_object({}) { |type, hash| hash[type] = value.get(type) }
      end

      def browser_info
        execute_browser_function(:logs, nil)
      end

      def all_cookies
        execute_browser_function(:all_cookies, nil)
      end

      def page_url
        execute_driver_function(:current_url, nil)
      end

      def title
        execute_driver_function(:title, nil)
      end

      def page_width
        if @current_window
          value = execute_driver_function(:window_size, nil, @current_window)
          value[0] if value
        end
      end

      def page_height
        if @current_window
          value = execute_driver_function(:window_size, nil, @current_window)
          value[1] if value
        end
      end

      def response_headers
        execute_driver_function(:response_headers, nil)
      end

      def status_code
        execute_driver_function(:status_code, nil)
      end

      def html_source
        value = execute_driver_function(:html, nil)
        @report.page_text(value) if value
      end

      def html_frame
        value = execute_driver_function(:html, nil)
        @report.page_frame(value) if value
      end

      def screen_shot
        dir_name = File.join(@report.report_test_folder_name, "temporary_folder")

        begin
          page_name = @options[:screen_shot_name] || "screen_shot"
          page_name = page_name [Dir.pwd.length..-1] if page_name.start_with?(Dir.pwd)
          page_name = page_name [1..-1] if page_name.start_with?("/")
          page_name = page_name["features/".length..-1] if page_name.start_with?("features/")
          page_name = page_name.gsub(/[^a-z0-9_]/i, "_")
          page_name = page_name.gsub("__", "_")

          page_name = File.join(dir_name, "#{page_name}.png")

          FileUtils.mkdir_p dir_name

          execute_driver_function(:save_screenshot, nil, page_name)

          if File.exist?(page_name)
            @report.image_link(page_name)
          else
            "Could not save screen_shot."
          end
        ensure
          FileUtils.rm_rf dir_name
        end
      end

      def html_file
        dir_name = @report.unique_folder_name("html_save_file")
        FileUtils.mkdir_p File.join(@report.report_test_folder_name, dir_name)
        ::Capybara.current_session.
            save_page(File.join(@report.report_test_folder_name, dir_name, "__cornucopia_save_page.html"))
        "<a href=\"#{File.join(dir_name, "__cornucopia_save_page.html")}\" target=\"_blank\">Saved Page</a>".
            html_safe
      end
    end
  end
end
