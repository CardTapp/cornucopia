# frozen_string_literal: true

require "rails_helper"
require 'rack/file'
require ::File.expand_path("../../../lib/cornucopia/util/report_builder", File.dirname(__FILE__))
require ::File.expand_path("../../../lib/cornucopia/capybara/page_diagnostics", File.dirname(__FILE__))
require ::File.expand_path("../../../lib/cornucopia/capybara/finder_extensions", File.dirname(__FILE__))
require ::File.expand_path("../../../lib/cornucopia/capybara/matcher_extensions", File.dirname(__FILE__))

describe Cornucopia::Capybara::PageDiagnostics, type: :feature do
  # Make sure that all tests start clean and get cleaned up afterwards...
  around(:example) do |example|
    expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey

    begin
      example.run
    ensure
      if (Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report"))
        Cornucopia::Util::ReportBuilder.current_report.close
      end

      ::Capybara.current_session.driver.window_handles.each do |handle|
        if handle != ::Capybara.current_session.driver.current_window_handle
          ::Capybara.current_session.driver.close_window(handle)
        end
      end

      FileUtils.rm_rf Rails.root.join("cornucopia_report/")
      FileUtils.rm_rf Rails.root.join("sample_report/")
    end
  end

  describe "#dump_page_details" do
    before(:context) do
      file_name_1 = generate_report_file("report_1")

      ::Capybara.app = Rack::File.new File.absolute_path(File.join(File.dirname(file_name_1), ".."))
    end

    it "does nothing if Capybara isn't open" do
      report = Cornucopia::Util::ReportBuilder.current_report

      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report)

      report.close

      report_text = File.read(report.report_contents_page_name)
      expect(report_text).to match /No Errors to report/
    end

    it "can open a page" do
      file_name_1 = generate_report_file("report_1")
      ::Capybara.current_session.visit("/report_1/#{File.basename(file_name_1)}")
      ::Capybara.page.has_text?(@last_val)

      report = Cornucopia::Util::ReportBuilder.current_report

      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report)

      report.close

      report_text = File.read(report.report_test_contents_page_name)
      expect(report_text).not_to match /No Errors to report/
      expect(report_text).to match /\>Page Dump:\</
      expect(report_text).to match /\>\npage_url\n\</
      expect(report_text).to match /\>\ntitle\n\</
      expect(report_text).to match /\>\nscreen_shot\n\</
      expect(report_text).to match /\<img/
      expect(report_text).to match /\>More Details...\</
      expect(report_text).to match /\>\nhtml_frame\n\</
      expect(report_text).to match /\<iframe/
      expect(report_text).to match /\>\nhtml_source\n\</
      expect(report_text).to match /\<textarea/
      expect(report_text).to match /\>\npage_height\n\</
      expect(report_text).to match /\>\npage_width\n\</
      expect(report_text).to match /\>\nhtml_file\n\</
    end

    it "can report on multiple pages" do
      file_name_1 = generate_report_file("report_1")

      ::Capybara.current_session.visit("/report_1/#{File.basename(file_name_1)}")
      ::Capybara.page.has_text?(@last_val)

      file_name_2 = generate_report_file("report_2")
      new_handle  = ::Capybara.window_opened_by { ::Capybara.current_session.driver.open_new_window }
      ::Capybara.current_session.switch_to_window(new_handle)
      ::Capybara.current_session.visit("/report_2/#{File.basename(file_name_2)}")
      ::Capybara.page.has_text?(@last_val)

      report = Cornucopia::Util::ReportBuilder.current_report

      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report)

      report.close

      report_text = File.read(report.report_test_contents_page_name)
      expect(report_text).not_to match /No Errors to report/
      expect(report_text).not_to match /\>\noptions\n\</
      expect(report_text).not_to match /\>\nreport\n\</
      expect(report_text).not_to match /\>\ntable\n\</
      expect(report_text).not_to match /\>\nunsupported_list\n\</
      expect(report_text).not_to match /\>\nallow_other_windows\n\</
      expect(report_text).not_to match /\>\niterating\n\</
      expect(report_text).not_to match /\>\nsession\n\</
      expect(report_text).not_to match /\>\ndriver\n\</
      expect(report_text).not_to match /\>\nwindow_handles\n\</
      expect(report_text).not_to match /\>\ncurrent_window\n\</
      expect(report_text.scan(/\>Page Dump:\</).length).to be == 1
      expect(report_text.scan(/\>\npage_url\n\</).length).to be == 2
      expect(report_text.scan(/\>\ntitle\n\</).length).to be == 2
      expect(report_text.scan(/\>\nscreen_shot\n\</).length).to be == 2
      expect(report_text.scan(/\"cornucopia-section-image\"/).length).to be == 2
      expect(report_text.scan(/\>More Details...\</).length).to be == 1
      expect(report_text.scan(/\>\nhtml_frame\n\</).length).to be == 2
      expect(report_text.scan(/\<iframe/).length).to be == 2
      expect(report_text.scan(/\>\nhtml_source\n\</).length).to be == 2
      expect(report_text.scan(/\<textarea/).length).to be == 2
      expect(report_text.scan(/\>\npage_height\n\</).length).to be == 2
      expect(report_text.scan(/\>\npage_width\n\</).length).to be == 2
      expect(report_text.scan(/\>\nhtml_file\n\</).length).to be == 2
    end

    it "only report on a page once" do
      file_name_1 = generate_report_file("report_1")
      ::Capybara.current_session.visit("/report_1/#{File.basename(file_name_1)}")
      ::Capybara.page.has_text?(@last_val)

      report = Cornucopia::Util::ReportBuilder.current_report

      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report)
      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report)

      report.close

      report_text = File.read(report.report_test_contents_page_name)
      expect(report_text).not_to match /No Errors to report/
      expect(report_text).not_to match /\>\noptions\n\</
      expect(report_text).not_to match /\>\nreport\n\</
      expect(report_text).not_to match /\>\ntable\n\</
      expect(report_text).not_to match /\>\nunsupported_list\n\</
      expect(report_text).not_to match /\>\nallow_other_windows\n\</
      expect(report_text).not_to match /\>\niterating\n\</
      expect(report_text).not_to match /\>\nsession\n\</
      expect(report_text).not_to match /\>\ndriver\n\</
      expect(report_text).not_to match /\>\nwindow_handles\n\</
      expect(report_text).not_to match /\>\ncurrent_window\n\</
      expect(report_text.scan(/\>Page Dump:\</).length).to be == 1
      expect(report_text.scan(/\>\npage_url\n\</).length).to be == 1
      expect(report_text.scan(/\>\ntitle\n\</).length).to be == 1
      expect(report_text.scan(/\>\nscreen_shot\n\</).length).to be == 1
      expect(report_text.scan(/\"cornucopia-section-image\"/).length).to be == 1
      expect(report_text.scan(/\>More Details...\</).length).to be == 1
      expect(report_text.scan(/\>\nhtml_frame\n\</).length).to be == 1
      expect(report_text.scan(/\<iframe/).length).to be == 1
      expect(report_text.scan(/\>\nhtml_source\n\</).length).to be == 1
      expect(report_text.scan(/\<textarea/).length).to be == 1
      expect(report_text.scan(/\>\npage_height\n\</).length).to be == 1
      expect(report_text.scan(/\>\npage_width\n\</).length).to be == 1
      expect(report_text.scan(/\>\nhtml_file\n\</).length).to be == 1
    end

    it "will report on page twice in it is in a new report." do
      file_name_1 = generate_report_file("report_1")
      ::Capybara.current_session.visit("/report_1/#{File.basename(file_name_1)}")
      ::Capybara.page.has_text?(@last_val)

      report = Cornucopia::Util::ReportBuilder.current_report
      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report)
      report.close

      report = Cornucopia::Util::ReportBuilder.current_report
      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report)
      report.close

      report_text = File.read(report.report_test_contents_page_name)
      expect(report_text).not_to match /No Errors to report/
      expect(report_text).not_to match /\>\noptions\n\</
      expect(report_text).not_to match /\>\nreport\n\</
      expect(report_text).not_to match /\>\ntable\n\</
      expect(report_text).not_to match /\>\nunsupported_list\n\</
      expect(report_text).not_to match /\>\nallow_other_windows\n\</
      expect(report_text).not_to match /\>\niterating\n\</
      expect(report_text).not_to match /\>\nsession\n\</
      expect(report_text).not_to match /\>\ndriver\n\</
      expect(report_text).not_to match /\>\nwindow_handles\n\</
      expect(report_text).not_to match /\>\ncurrent_window\n\</
      expect(report_text.scan(/\>Page Dump:\</).length).to be == 1
      expect(report_text.scan(/\>\npage_url\n\</).length).to be == 1
      expect(report_text.scan(/\>\ntitle\n\</).length).to be == 1
      expect(report_text.scan(/\>\nscreen_shot\n\</).length).to be == 1
      expect(report_text.scan(/\"cornucopia-section-image\"/).length).to be == 1
      expect(report_text.scan(/\>More Details...\</).length).to be == 1
      expect(report_text.scan(/\>\nhtml_frame\n\</).length).to be == 1
      expect(report_text.scan(/\<iframe/).length).to be == 1
      expect(report_text.scan(/\>\nhtml_source\n\</).length).to be == 1
      expect(report_text.scan(/\<textarea/).length).to be == 1
      expect(report_text.scan(/\>\npage_height\n\</).length).to be == 1
      expect(report_text.scan(/\>\npage_width\n\</).length).to be == 1
      expect(report_text.scan(/\>\nhtml_file\n\</).length).to be == 1
    end

    it "can take a section title" do
      file_name_1 = generate_report_file("report_1")
      ::Capybara.current_session.visit("/report_1/#{File.basename(file_name_1)}")
      ::Capybara.page.has_text?(@last_val)

      report = Cornucopia::Util::ReportBuilder.current_report

      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report, section_label: "Super cool report dump:")

      report.close

      report_text = File.read(report.report_test_contents_page_name)
      expect(report_text).not_to match /No Errors to report/
      expect(report_text.scan(/\>Super cool report dump:\</).length).to be == 1
    end

    it "can deal with it if the image cannot be exported" do
      file_name_1 = generate_report_file("report_1")
      ::Capybara.current_session.visit("/report_1/#{File.basename(file_name_1)}")
      ::Capybara.page.has_text?(@last_val)

      report = Cornucopia::Util::ReportBuilder.current_report

      allow_any_instance_of(Cornucopia::Capybara::PageDiagnostics).
          to receive(:execute_driver_function).and_call_original

      allow_any_instance_of(Cornucopia::Capybara::PageDiagnostics).
          to receive(:execute_driver_function).
                 with(:save_screenshot, nil, File.join(report.report_test_folder_name, "temporary_folder", "screen_shot.png")).
                 and_return nil

      Cornucopia::Capybara::PageDiagnostics.dump_details(report: report, section_label: "Super cool report dump:")

      report.close

      report_text = File.read(report.report_test_contents_page_name)
      expect(report_text).not_to match /No Errors to report/
      expect(report_text.scan(/\>Super cool report dump:\</).length).to be == 1
      expect(report_text).to match /Could not save screen_shot./
    end

    it "puts the details in an existing report table" do
      file_name_1 = generate_report_file("report_1")
      ::Capybara.current_session.visit("/report_1/#{File.basename(file_name_1)}")
      ::Capybara.page.has_text?(@last_val)

      report = Cornucopia::Util::ReportBuilder.current_report

      report.within_section("an existing section") do |section|
        section.within_table do |table|
          table.write_stats "something", "a value"
          Cornucopia::Capybara::PageDiagnostics.dump_details_in_table(report, table)
        end
      end

      report.close

      report_text = File.read(report.report_test_contents_page_name)
      expect(report_text).not_to match /No Errors to report/
      expect(report_text).to match /\>an existing section\</
      expect(report_text).to match /\>\nsomething\n\</
      expect(report_text).to match /\>a value\</
      expect(report_text).to match /\>\npage_url\n\</
      expect(report_text).to match /\>\ntitle\n\</
      expect(report_text).to match /\>\nscreen_shot\n\</
      expect(report_text).to match /\<img/
      expect(report_text).not_to match /\>More Details...\</
      expect(report_text).to match /\>\nhtml_frame\n\</
      expect(report_text).to match /\<iframe/
      expect(report_text).to match /\>\nhtml_source\n\</
      expect(report_text).to match /\<textarea/
      expect(report_text).to match /\>\npage_height\n\</
      expect(report_text).to match /\>\npage_width\n\</
      expect(report_text).to match /\>\nhtml_file\n\</
    end
  end
end
