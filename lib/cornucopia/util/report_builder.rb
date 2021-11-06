# frozen_string_literal: true

require "timeout"
require ::File.expand_path('file_asset', File.dirname(__FILE__))
require ::File.expand_path('pretty_formatter', File.dirname(__FILE__))
require ::File.expand_path('report_table', File.dirname(__FILE__))
# require ::File.expand_path('configuration', File.dirname(__FILE__))

module Cornucopia
  module Util
    class ReportBuilder
      @@current_report  = nil
      @@on_close_blocks = []

      MAX_OLD_FOLDERS = 5

      class TestDataHolder
      end

      class << self
        def current_report(folder_name = nil, parent_folder = nil)
          if (@@current_report &&
              ((parent_folder && @@current_report.instance_variable_get(:@parent_folder_name) != parent_folder) ||
                  (folder_name && @@current_report.instance_variable_get(:@base_folder_name) != folder_name)))
            @@current_report.close
            @@current_report = nil
          end

          folder_name   ||= Cornucopia::Util::Configuration.base_folder
          parent_folder ||= Cornucopia::Util::Configuration.base_folder

          @@current_report ||= Cornucopia::Util::ReportBuilder.new(folder_name, parent_folder)
        end

        def new_report(folder_name = nil, parent_folder = nil)
          if (@@current_report)
            @@current_report.close
            @@current_report = nil
          end

          @@current_report = Cornucopia::Util::ReportBuilder.new(folder_name, parent_folder)
        end

        def escape_string(value)
          value = value.to_s
          value = value + "" if value.frozen?
          "".html_safe + value.force_encoding("UTF-8")
        end

        def format_code_refs(value)
          safe_text = Cornucopia::Util::ReportBuilder.escape_string(value)

          safe_text = safe_text.gsub(/(#{Cornucopia::Util::ReportBuilder.root_folder}|\.\/|(?=(?:^features|^spec)\/))([^\:\r\n &]*(?: *\: *[0-9]+)?)/,
                                     "\\1 <span class=\"cornucopia-app-file\">\\2</span> ").html_safe

          safe_text
        end

        def pretty_array(array, format_sub_items = true)
          if (array.is_a?(Array))
            array.map do |value|
              # This is not expected to be called on an array of arrays,
              # block this and just convert sub-arrays to strings.
              format_value = value
              format_value = value.to_s if value.is_a?(Array)

              if format_sub_items
                Cornucopia::Util::ReportBuilder.pretty_format(format_value, in_pretty_print: true).rstrip
              else
                # "".html_safe + format_value
                format_value
              end
            end.join("\n").html_safe
          else
            Cornucopia::Util::ReportBuilder.pretty_format(array)
          end
        end

        # I've seen some objects with pretty_inspect get stuck in an infinite loop (or close to it),
        # so they take literally hours to print.  This function uses Timeout to prevent this.
        # either the class prints quickly, or we kill it and try something else.
        #
        # If the something else doesn't work, we just give up...
        def pretty_object(value, options = {})
          timed_out    = false
          return_value = nil

          begin
            begin
              timeout_length = Cornucopia::Util::Configuration.print_timeout_min
              if Object.const_defined?("Capybara")
                default_time = ::Capybara.respond_to?(:default_max_wait_time) ? ::Capybara.default_max_wait_time : ::Capybara.default_wait_time
                timeout_length = [timeout_length, default_time].max
              end
              if Object.const_defined?("Rails")
                timeout_length = [timeout_length, 30].max if Rails.env.development?
              end

              Timeout::timeout(timeout_length) do
                if value.is_a?(String)
                  return_value = value
                elsif value.is_a?(Array)
                  return_value = Cornucopia::Util::ReportBuilder.pretty_array(value, !options[:in_pretty_print])
                elsif value.respond_to?(:pretty_inspect)
                  return_value = value.pretty_inspect
                else
                  return_value = value.to_s
                end
              end
            rescue Timeout::Error
              timed_out = true
            end
          rescue Exception
          end

          # If it timed out or threw an exception, try .to_s
          # That may also timeout or throw an exception, and if it does, give up.
          if timed_out || !return_value
            begin
              Timeout::timeout(timeout_length) do
                return_value = value.to_s
              end
            rescue Timeout::Error
              return_value = "Timed out rendering"
            rescue => error
              return_value = "Rendering error => #{error.to_s}\n#{error.backtrace.join("\n")}"
            end
          end

          return_value
        end

        def pretty_format(value, options = {})
          pretty_text = value

          pretty_text = Cornucopia::Util::ReportBuilder.pretty_object(pretty_text, options)
          pretty_text = Cornucopia::Util::ReportBuilder.escape_string(pretty_text)
          pretty_text = Cornucopia::Util::PrettyFormatter.format_string(pretty_text)
          pretty_text = Cornucopia::Util::ReportBuilder.format_code_refs(pretty_text)

          pretty_text
        end

        def build_index_section_item(path_name)
          item_path = "".html_safe

          item_path << "  <li>\n".html_safe
          item_path << "    <a href=\"#{path_name}\" target=\"_blank\">".html_safe
          item_path << File.dirname(path_name)
          item_path << "</a>\n".html_safe
          item_path << "  </li>\n".html_safe

          item_path
        end

        def build_index_section(section_name, section_items)
          section = "".html_safe

          section << "<div class=\"report-block\">".html_safe
          section << "  <h4>".html_safe
          section << section_name
          section << "</h4>\n".html_safe
          section << "  <ul class=\"index-list\">\n".html_safe

          section << Cornucopia::Util::ReportBuilder.build_index_section_item(section_items.shift)
          section_items.reverse.each do |section_item|
            section << Cornucopia::Util::ReportBuilder.build_index_section_item(section_item)
          end

          section << "  </ul>\n".html_safe
          section << "</div>\n".html_safe

          section
        end

        def folder_name_to_section_name(folder_name)
          case File.basename(folder_name)
            when Cornucopia::Util::Configuration.base_folder
              "Feature Tests"
            when "diagnostics_rspec_report"
              "RSPEC Tests"
            else
              File.basename(folder_name)
          end
        end

        def root_folder
          if Object.const_defined?("Rails")
            Rails.root
          else
            FileUtils.pwd
          end
        end

        def page_dump(page_html)
          "<textarea class=\"cornucopia-page-dump\">#{Cornucopia::Util::ReportBuilder.escape_string(page_html)}</textarea>\n".html_safe
        end

        def on_close(&block)
          @@on_close_blocks << block
        end
      end

      def initialize(folder_name = nil, parent_folder = nil)
        @parent_folder_name      = parent_folder || Cornucopia::Util::Configuration.base_folder
        @base_folder_name        = folder_name || Cornucopia::Util::Configuration.base_folder
        @report_title            = folder_name || Cornucopia::Util::Configuration.base_folder
        @test_name               = "unknown_test"
        @section_number          = 0
        @test_number             = 0
        @report_body             = "".html_safe
        @report_folder_name      = nil
        @index_folder_name       = nil
        @report_test_folder_name = nil
        @test_list_item          = nil
      end

      # This does nothing in a normal report because reports are built as you go.
      # If nothing has been reported though, this will create a report indicating that
      # nothing happened.
      def close
        exceptions = []

        if @@on_close_blocks
          @@on_close_blocks.each do |on_close_block|
            begin
              on_close_block.yield
            rescue
              exceptions << $!
            end
          end
        end

        if File.exist?(report_base_page_name)
          if Cornucopia::Util::Configuration.backup_logs_on_failure
            backup_log_files
          end

          if Cornucopia::Util::Configuration.open_report_after_generation(@base_folder_name)
            # `open #{report_base_page_name}` rescue nil
            system("open #{report_base_page_name}") rescue nil
          end
        else
          open_report_contents_file do |write_file|
            write_file.write %Q[<p class=\"cornucopia-no-errors\">No Errors to report</p>]
            write_file.write "\n"
          end
        end

        if self == @@current_report
          @@current_report = nil
        end

        exceptions.each do |exception|
          raise exception
        end
      end

      def report_folder_name
        unless @report_folder_name
          @report_folder_name = File.join(index_folder_name, "#{@base_folder_name}/")

          backup_report_folder
          delete_old_folders
        end

        @report_folder_name
      end

      def report_test_folder_name
        unless @report_test_folder_name
          @test_number             += 1
          @report_test_folder_name = File.join(report_folder_name, "test_#{@test_number}")
        end

        @report_test_folder_name
      end

      def index_folder_name
        unless @index_folder_name
          @index_folder_name = File.join(Cornucopia::Util::ReportBuilder.root_folder, "#{@parent_folder_name}/")

          FileUtils.mkdir_p @index_folder_name
        end

        @index_folder_name
      end

      def backup_report_folder
        if Dir.exist?(@report_folder_name)
          if File.exist?(File.join(@report_folder_name, "index.html"))
            update_time = File.ctime(File.join(@report_folder_name, "index.html"))
          else
            update_time = File.ctime(@report_folder_name)
          end

          # ensure the name is unique...
          new_sub_dir = File.join(index_folder_name, "#{@base_folder_name}_#{update_time.strftime("%Y_%m_%d_%H_%M_%S")}").to_s
          index       = 0
          while Dir.exist?(new_sub_dir)
            if new_sub_dir[-1 * "_alt_#{index}".length..-1] == "_alt_#{index}"
              new_sub_dir = new_sub_dir[0..-1 * "_alt_#{index}".length - 1]
            end

            index       += 1
            new_sub_dir += "_alt_#{index}"
          end

          FileUtils.mv @report_folder_name,
                       new_sub_dir
        end
      end

      def delete_old_folders
        old_directories = Dir[File.join(index_folder_name, "#{@base_folder_name}_*")].
            map { |dir| File.directory?(dir) ? dir : nil }.compact.sort

        if Array.wrap(old_directories).length > MAX_OLD_FOLDERS
          old_directories.each_with_index do |dir, index|
            break if index >= old_directories.length - MAX_OLD_FOLDERS

            FileUtils.rm_rf dir
          end
        end
      end

      def rebuild_index_page
        index_folder = index_folder_name

        FileUtils.mkdir_p index_folder_name
        FileUtils.rm_rf index_contents_page_name

        FileAsset.asset("index_base.html").create_file(File.join(index_folder, "index.html"))
        FileAsset.asset("index_contents.html").add_file(File.join(index_folder, "report_contents.html"))
        FileAsset.asset("cornucopia.css").add_file(File.join(index_folder, "cornucopia.css"))

        index_file = "".html_safe
        if File.exist?(File.join(Cornucopia::Util::ReportBuilder.root_folder, "coverage/index.html"))
          index_file << Cornucopia::Util::ReportBuilder.build_index_section("Coverage", ["../coverage/index.html"])
        end

        last_folder = nil
        group_items = []
        Dir[File.join(@index_folder_name, "*")].sort.each do |directory_item|
          if File.directory?(directory_item) && File.exist?(File.join(directory_item, "index.html"))
            directory_item = directory_item[@index_folder_name.to_s.length..-1]

            if last_folder
              if directory_item =~ /^#{last_folder}_/
                group_items << File.join(directory_item, "index.html")
              else
                unless group_items.empty?
                  index_file << Cornucopia::Util::ReportBuilder.build_index_section(
                      Cornucopia::Util::ReportBuilder.folder_name_to_section_name(last_folder), group_items)
                end

                last_folder = directory_item
                group_items = [File.join(last_folder, "index.html")]
              end
            else
              last_folder = directory_item
              group_items = [File.join(last_folder, "index.html")]
            end
          end
        end

        unless group_items.empty?
          index_file << Cornucopia::Util::ReportBuilder.build_index_section(
              Cornucopia::Util::ReportBuilder.folder_name_to_section_name(last_folder), group_items)
        end

        File.open(index_contents_page_name, "a:UTF-8") do |write_file|
          write_file << index_file
        end
      end

      def rebuild_report_holder_page
        initialize_report_files

        report_folder = report_folder_name

        FileUtils.mkdir_p report_folder_name
        FileUtils.rm_rf report_base_page_name

        report_holder_body = FileAsset.asset("report_holder.html").body
        FileAsset.asset("report.js").add_file(File.join(report_folder, "report.js"))
        FileAsset.asset("cornucopia.css").add_file(File.join(report_folder, "cornucopia.css"))

        File.open(File.join(report_folder, "index.html"), "w+") do |write_file|
          write_file << report_holder_body % { report_list: @report_body, report_title: @report_title }
        end
      end

      def report_base_page_name
        File.join(report_folder_name, "index.html")
      end

      def report_contents_page_name
        File.join(report_folder_name, "report_contents.html")
      end

      def report_test_base_page_name
        File.join(report_test_folder_name, "index.html")
      end

      def report_test_contents_page_name
        File.join(report_test_folder_name, "report_contents.html")
      end

      def index_base_page_name
        File.join(index_folder_name, "index.html")
      end

      def index_contents_page_name
        File.join(index_folder_name, "report_contents.html")
      end

      def initialize_report_files
        support_folder_name = report_folder_name

        FileUtils.mkdir_p @report_folder_name

        unless File.exist?(report_base_page_name)
          # use a different base index file.
          FileAsset.asset("report_holder.html").add_file(File.join(support_folder_name, "index.html"))
          rebuild_index_page
        end

        FileAsset.asset("report.js").add_file(File.join(support_folder_name, "report.js"))
        FileAsset.asset("cornucopia.css").add_file(File.join(support_folder_name, "cornucopia.css"))
      end

      def initialize_basic_report_files
        support_folder_name = report_folder_name

        FileUtils.mkdir_p @report_folder_name

        unless File.exist?(report_base_page_name)
          # use a different base index file.
          FileAsset.asset("report_base.html").add_file(File.join(support_folder_name, "index.html"))
          rebuild_index_page
        end

        FileAsset.asset("report_contents.html").add_file(File.join(support_folder_name, "report_contents.html"))
        FileAsset.asset("collapse.gif").add_file(File.join(support_folder_name, "collapse.gif"))
        FileAsset.asset("expand.gif").add_file(File.join(support_folder_name, "expand.gif"))
        FileAsset.asset("more_info.js").add_file(File.join(support_folder_name, "more_info.js"))
        FileAsset.asset("cornucopia.css").add_file(File.join(support_folder_name, "cornucopia.css"))
      end

      def body_list_item(name, path)
        body_list_item = "<li>\n".html_safe
        body_list_item += "<a class=\"coruncopia-report-link\" href=\"#{path}\" target=\"_blank\">".html_safe
        body_list_item += name
        body_list_item += "</a>\n".html_safe
        body_list_item += "</li>\n".html_safe

        body_list_item
      end

      def test_list_item
        if @test_list_item
          nil
        else
          folder_name = File.basename(report_test_folder_name)

          @test_list_item = body_list_item(@test_name, File.join(folder_name, "index.html"))

          @test_list_item
        end
      end

      def initialize_report_test_files
        @report_body += test_list_item.to_s

        support_folder_name = report_test_folder_name

        FileUtils.mkdir_p @report_test_folder_name

        unless File.exist?(report_test_base_page_name)
          FileAsset.asset("report_base.html").add_file(File.join(support_folder_name, "index.html"))
          rebuild_report_holder_page
        end

        FileAsset.asset("report_contents.html").add_file(File.join(support_folder_name, "report_contents.html"))
        FileAsset.asset("collapse.gif").add_file(File.join(support_folder_name, "collapse.gif"))
        FileAsset.asset("expand.gif").add_file(File.join(support_folder_name, "expand.gif"))
        FileAsset.asset("more_info.js").add_file(File.join(support_folder_name, "more_info.js"))
        FileAsset.asset("cornucopia.css").add_file(File.join(support_folder_name, "cornucopia.css"))
      end

      def open_report_contents_file(&block)
        initialize_basic_report_files

        File.open(report_contents_page_name, "a:UTF-8", &block)
      end

      def open_report_test_contents_file(&block)
        initialize_report_test_files

        File.open(report_test_contents_page_name, "a:UTF-8", &block)
      end

      def test_succeeded
        if @report_test_folder_name
          FileUtils.rm_rf report_test_folder_name
          @report_body.gsub!(@test_list_item, "")

          if @report_body.blank?
            FileUtils.rm_rf report_base_page_name
            FileUtils.rm_rf File.join(report_folder_name, "report.js")
            FileUtils.rm_rf File.join(report_folder_name, "cornucopia.css")
            @report_body = "".html_safe
          else
            rebuild_report_holder_page
          end

          @test_number -= 1
        end
      end

      def start_test(stack_object, test_name)
        test_data =
            {
                orig_test_name:      @test_name,
                orig_test_folder:    @report_test_folder_name,
                orig_test_list_item: @test_list_item,
                orig_section_number: @section_number
            }

        stack_object.instance_variable_set(:@report_builder_test_start_data, test_data)

        @test_name               = test_name
        @report_test_folder_name = nil
        @test_list_item          = nil
        @section_number          = 0
      end

      def end_test(stack_object)
        test_data = stack_object.instance_variable_get(:@report_builder_test_start_data)

        @section_number          = test_data[:orig_section_number]
        @test_name               = test_data[:orig_test_name]
        @report_test_folder_name = test_data[:orig_test_folder]
        @test_list_item          = test_data[:orig_test_list_item]
      end

      def within_test(test_name, &block)
        test_data_holder = TestDataHolder.new

        begin
          start_test(test_data_holder, test_name)

          block.yield
        ensure
          end_test(test_data_holder)
        end
      end

      def within_section(section_text, &block)
        begin
          open_report_test_contents_file do |write_file|
            write_file.write "<div class=\"cornucopia-section #{((@section_number += 1) % 2) == 1 ? "cornucopia-even" : "cornucopia-odd"}\">\n"
            write_file.write "<p class=\"cornucopia-section-label\">#{Cornucopia::Util::ReportBuilder.escape_string(section_text)}</p>\n".
                                 dup.force_encoding("UTF-8")
          end
          block.yield self
        ensure
          open_report_test_contents_file do |write_file|
            write_file.write "</div>\n"
            write_file.write "<div class=\"cornucopia-end-section\" />\n"
          end
        end
      end

      def within_hidden_table(options={}, &block)
        table_pre = "<div class=\"cornucopia-show-hide-section\">\n".dup
        table_pre << "  <div class=\"cornucopia-table\">\n"
        table_pre << "    <div class=\"cornucopia-row\">\n"
        table_pre << "      <div class=\"cornucopia-cell-data\">\n"
        table_pre << "        <a class =\"cornucopia-additional-details\" href=\"#\">More Details...</a>\n"
        table_pre << "      </div>\n"
        table_pre << "    </div>\n"
        table_pre << "  </div>\n"
        table_pre << "  <div class=\"cornucopia-additional-details hidden\">\n"
        table_pre = table_pre.html_safe

        table_post = "  </div>\n".dup
        table_post << "</div>\n"
        table_post = table_post.html_safe

        within_table(table_prefix:         table_pre,
                     table_postfix:        table_post,
                     report_table:         nil,
                     nested_table:         options.delete(:nested_table),
                     nested_table_label:   options.delete(:nested_table_label),
                     not_a_table:          table_pre,
                     suppress_blank_table: table_pre) do |outer_report_table|
          block.yield outer_report_table
        end
      end

      def within_table(options = {}, &block)
        report_table         = nil
        options_report_table = options[:report_table]

        begin
          Cornucopia::Util::ReportTable.new(options) do |table|
            report_table = table
            block.yield(report_table)
          end
        ensure
          if report_table && !options_report_table
            open_report_test_contents_file do |write_file|
              write_file.write report_table.full_table.force_encoding("UTF-8")
            end
          end
        end
      end

      def image_link(image_file_name)
        dest_file_name = unique_file_name(File.basename(image_file_name))

        FileUtils.mv image_file_name, File.join(report_test_folder_name, dest_file_name)

        "<img class=\"cornucopia-section-image\" src=\"./#{dest_file_name}\" />".html_safe
      end

      def page_text(page_html)
        padded_frame("<textarea class=\"cornucopia-page-dump\">#{Cornucopia::Util::ReportBuilder.escape_string(page_html)}</textarea>\n".html_safe)
      end

      def page_frame(page_html)
        dump_file_name = unique_file_name("page_dump.html")

        File.open(File.join(report_test_folder_name, dump_file_name), "w:UTF-8") do |dump_file|
          page_text = page_html.to_s
          page_text = page_text + "" if page_text.frozen?
          dump_file.write page_text.force_encoding("UTF-8")
        end

        padded_frame("<iframe src=\"#{dump_file_name}\" class=\"cornucopia-sample-frame\" sandbox></iframe>\n".html_safe)
      end

      def padded_frame(padded_text)
        padded_val = "<div class=\"padded-frame\">".html_safe
        padded_val << padded_text
        padded_val << "</div>".html_safe
      end

      def unique_file_name(file_base_name, base_folder = nil)
        file_parts = file_base_name.split(".")
        base_name  = file_parts[0..-2].join(".")
        extension  = file_parts[-1]

        base_folder ||= report_test_folder_name

        unique_num = 1
        num_string = ""
        while File.exist?(File.join(base_folder, "#{base_name}#{num_string}.#{extension}"))
          num_string = "_#{unique_num}"
          unique_num += 1
        end

        "#{base_name}#{num_string}.#{extension}"
      end

      def unique_folder_name(folder_base_name, base_folder = nil)
        unique_num = 1
        num_string = ""

        base_folder ||= report_test_folder_name

        while File.exist?(File.join(base_folder, "#{folder_base_name}#{num_string}"))
          num_string = "_#{unique_num}"
          unique_num += 1
        end

        "#{folder_base_name}#{num_string}"
      end

      def backup_log_files
        log_folder = unique_folder_name "log_files", report_folder_name

        Cornucopia::Util::LogCapture.backup_log_files File.join(report_folder_name, log_folder)

        log_files = Dir[File.join(report_folder_name, log_folder, "**", "*")]
        log_files.each do |log_file|
          @report_body += body_list_item(File.basename(log_file), log_file[report_folder_name.length..-1])
        end

        rebuild_report_holder_page
      end
    end
  end
end
