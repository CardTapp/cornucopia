# frozen_string_literal: true

require "rails_helper"
require ::File.expand_path("../../../lib/cornucopia/util/report_builder", File.dirname(__FILE__))
require ::File.expand_path("../../../lib/cornucopia/capybara/page_diagnostics", File.dirname(__FILE__))
require ::File.expand_path("../../../lib/cornucopia/capybara/finder_diagnostics", File.dirname(__FILE__))

describe Cornucopia::Capybara::FinderDiagnostics, type: :feature do
  # Make sure that all tests start clean and get cleaned up afterwards...
  around(:example) do |example|
    expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey

    begin
      @file_name_1 = generate_report_file("report_1")

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

  before(:context) do
    @file_name_1   = generate_report_file("report_1")
    ::Capybara.app = Rack::File.new File.absolute_path(File.join(File.dirname(@file_name_1), "../.."))
  end

  it "does nothing if found" do
    index_page = CornucopiaReportApp.index_page

    index_page.load base_folder: "sample_report"

    tester = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(index_page, {}, {}, :find, "#base-contents")
    expect(tester).not_to receive(:perform_analysis)

    tester.run
  end

  it "runs a report if not found" do
    index_page = CornucopiaReportApp.index_page

    index_page.load base_folder: "sample_report"

    index_page.contents do |contents_frame|
      tester = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(contents_frame, {}, {}, :find, "#base-contentss")
      expect(tester).to receive(:perform_analysis).and_call_original

      expect { tester.run }.to raise_error(Capybara::ElementNotFound)
    end

    Cornucopia::Util::ReportBuilder.current_report.close

    report_page = CornucopiaReportApp.cornucopia_report_holder_page
    report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

    expect(report_page.tests.length).to be >= 1
    report_page.tests[0].click
    report_page.displayed_test do |test_page|
      test_page.contents do |contents_frame|
        expect(contents_frame.errors.length).to be == 1
        expect(contents_frame.errors[0].name.text).to be == "An error occurred while processing \"find\":"
        expect(contents_frame.errors[0].tables[0].rows.length).to be == 5
        expect(contents_frame.errors[0].tables[0].rows[0].labels[0].text).to be == "function_name"
        expect(contents_frame.errors[0].tables[0].rows[0].values[0].text).to be == ":find"
        expect(contents_frame.errors[0].tables[0].rows[1].labels[0].text).to be == "args[0]"
        expect(contents_frame.errors[0].tables[0].rows[1].values[0].text).to be == "#base-contentss"
        expect(contents_frame.errors[0].tables[0].rows[2].labels[0].text).to be == "search_args"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables.length).to be == 1
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows.length).to be == 2
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[0].labels[0].text).to be == "0"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[0].values[0].text).to be == ":css"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[1].labels[0].text).to be == "1"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[1].values[0].text).to be == "#base-contentss"
        expect(contents_frame.errors[0].tables[0].rows[3].labels[0].text).to be == "message"
        expect(contents_frame.errors[0].tables[0].rows[3].values[0].text).to be == "Unable to find css \"#base-contentss\""
        expect(contents_frame.errors[0].tables[0].rows[4].labels[0].text).to be == "backtrace"
        expect(contents_frame.errors[0].tables[0].rows[4].expands[0]).to be
        expect(contents_frame.errors[0].tables[0].rows[4].mores[0]).to be
        expect(contents_frame.errors[0].tables[0].rows[4].values[0].text.length).to be > 0

        contents_frame.errors[0].more_details.show_hide.click
        expect(contents_frame.errors[0].more_details.details.rows.length).to be == 12
        expect(contents_frame.errors[0].more_details.details.rows[0].labels[0].text).to be == "name"
        expect(contents_frame.errors[0].more_details.details.rows[0].values[0].text).to be == "Capybara::ElementNotFound"
        expect(contents_frame.errors[0].more_details.details.rows[1].labels[0].text).to be == "support_options"
        expect(contents_frame.errors[0].more_details.details.rows[1].values[0].text).to be == "{:__cornucopia_no_analysis=>true, :__cornucopia_retry_with_found=>nil}"
        expect(contents_frame.errors[0].more_details.details.rows[2].labels[0].text).to be == "page_url"
        expect(contents_frame.errors[0].more_details.details.rows[2].values[0].text).to match %r{sample_report/index\.html}
        expect(contents_frame.errors[0].more_details.details.rows[3].labels[0].text).to be == "title"
        expect(contents_frame.errors[0].more_details.details.rows[3].values[0].text).to be == "Diagnostics report list"
        expect(contents_frame.errors[0].more_details.details.rows[4].labels[0].text).to be == "screen_shot"
        expect(contents_frame.errors[0].more_details.details.rows[4].value_images[0][:src]).to match /\/screen_shot\.png/
        expect(contents_frame.errors[0].more_details.details.rows[5].labels[0].text).to be == "browser_info"
        expect(contents_frame.errors[0].more_details.details.rows[6].labels[0].text).to be == "browser_logs"
        expect(contents_frame.errors[0].more_details.details.rows[7].labels[0].text).to be == "html_file"
        expect(contents_frame.errors[0].more_details.details.rows[7].value_links[0][:href]).
            to match /html_save_file\/__cornucopia_save_page\.html/
        expect(contents_frame.errors[0].more_details.details.rows[8].labels[0].text).to be == "html_frame"
        expect(contents_frame.errors[0].more_details.details.rows[8].value_frames[0][:src]).
            to match /page_dump\.html/
        expect(contents_frame.errors[0].more_details.details.rows[9].labels[0].text).to be == "html_source"
        expect(contents_frame.errors[0].more_details.details.rows[9].value_textareas[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[10].labels[0].text).to be == "page_height"
        expect(contents_frame.errors[0].more_details.details.rows[10].values[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[11].labels[0].text).to be == "page_width"
        expect(contents_frame.errors[0].more_details.details.rows[11].values[0].text).to be
      end
    end
  end

  it "runs a report if too many found" do
    @file_name_1 = generate_report_file("report_1")

    index_page = CornucopiaReportApp.index_page

    index_page.load base_folder: "sample_report"

    total_tests = 0
    index_page.contents do |contents_frame|
      total_tests = contents_frame.all("a").length
      tester = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(contents_frame, {}, {}, :find, "a")
      expect(tester).to receive(:perform_analysis).and_call_original

      expect { tester.run }.to raise_error(Capybara::Ambiguous)
    end

    report_page = CornucopiaReportApp.cornucopia_report_holder_page
    report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

    expect(report_page.tests.length).to be >= 1

    report_page.tests[0].click
    report_page.displayed_test do |test_page|
      test_page.contents do |contents_frame|
        expect(contents_frame.errors.length).to be == 1
        expect(contents_frame.errors[0].name.text).to be == "An error occurred while processing \"find\":"
        expect(contents_frame.errors[0].tables[0].rows.length).to be == 5
        expect(contents_frame.errors[0].tables[0].rows[0].labels[0].text).to be == "function_name"
        expect(contents_frame.errors[0].tables[0].rows[0].values[0].text).to be == ":find"
        expect(contents_frame.errors[0].tables[0].rows[1].labels[0].text).to be == "args[0]"
        expect(contents_frame.errors[0].tables[0].rows[1].values[0].text).to be == "a"
        expect(contents_frame.errors[0].tables[0].rows[2].labels[0].text).to be == "search_args"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables.length).to be == 1
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows.length).to be == 2
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[0].labels[0].text).to be == "0"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[0].values[0].text).to be == ":css"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[1].labels[0].text).to be == "1"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[1].values[0].text).to be == "a"
        expect(contents_frame.errors[0].tables[0].rows[3].labels[0].text).to be == "message"
        expect(contents_frame.errors[0].tables[0].rows[3].values[0].text).to match /Ambiguous match, found .+ elements matching visible css "a"/
        expect(contents_frame.errors[0].tables[0].rows[4].labels[0].text).to be == "backtrace"
        expect(contents_frame.errors[0].tables[0].rows[4].expands[0]).to be
        expect(contents_frame.errors[0].tables[0].rows[4].mores[0]).to be
        expect(contents_frame.errors[0].tables[0].rows[4].values[0].text.length).to be > 0

        contents_frame.errors[0].more_details.show_hide.click
        expect(contents_frame.errors[0].more_details.details.rows.length).to be == 14
        expect(contents_frame.errors[0].more_details.details.rows[0].labels[0].text).to be == "name"
        expect(contents_frame.errors[0].more_details.details.rows[0].values[0].text).to be == "Capybara::Ambiguous"
        expect(contents_frame.errors[0].more_details.details.rows[1].labels[0].text).to be == "all_elements"
        expect(contents_frame.errors[0].more_details.details.rows[1].sub_tables.length).to eq 1
        expect(contents_frame.errors[0].more_details.details.rows[1].sub_tables[0].rows.length).to eq total_tests
        expect(contents_frame.errors[0].more_details.details.rows[2].labels[0].text).to be == "guessed_types"
        expect(contents_frame.errors[0].more_details.details.rows[2].values[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[3].labels[0].text).to be == "support_options"
        expect(contents_frame.errors[0].more_details.details.rows[3].values[0].text).to be == "{:__cornucopia_no_analysis=>true, :__cornucopia_retry_with_found=>nil}"
        expect(contents_frame.errors[0].more_details.details.rows[4].labels[0].text).to be == "page_url"
        expect(contents_frame.errors[0].more_details.details.rows[4].values[0].text).to match %r{sample_report/index\.html}
        expect(contents_frame.errors[0].more_details.details.rows[5].labels[0].text).to be == "title"
        expect(contents_frame.errors[0].more_details.details.rows[5].values[0].text).to be == "Diagnostics report list"
        expect(contents_frame.errors[0].more_details.details.rows[6].labels[0].text).to be == "screen_shot"
        expect(contents_frame.errors[0].more_details.details.rows[6].value_images[0][:src]).to match /\/screen_shot\.png/
        expect(contents_frame.errors[0].more_details.details.rows[7].labels[0].text).to be == "browser_info"
        expect(contents_frame.errors[0].more_details.details.rows[8].labels[0].text).to be == "browser_logs"
        expect(contents_frame.errors[0].more_details.details.rows[9].labels[0].text).to be == "html_file"
        expect(contents_frame.errors[0].more_details.details.rows[9].value_links[0][:href]).
            to match /html_save_file\/__cornucopia_save_page\.html/
        expect(contents_frame.errors[0].more_details.details.rows[10].labels[0].text).to be == "html_frame"
        expect(contents_frame.errors[0].more_details.details.rows[10].value_frames[0][:src]).
            to match /page_dump\.html/
        expect(contents_frame.errors[0].more_details.details.rows[11].labels[0].text).to be == "html_source"
        expect(contents_frame.errors[0].more_details.details.rows[11].value_textareas[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[12].labels[0].text).to be == "page_height"
        expect(contents_frame.errors[0].more_details.details.rows[12].values[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[13].labels[0].text).to be == "page_width"
        expect(contents_frame.errors[0].more_details.details.rows[13].values[0].text).to be
      end
    end
  end

  it "runs the finder when test_finder is called" do
    index_page = CornucopiaReportApp.index_page

    index_page.load base_folder: "sample_report"

    index_page.contents do |contents_frame|
      diag = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(contents_frame, {}, {}, :all, "a")
      expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).
          to receive(:new).
                 with(contents_frame, {}, {}, :all, "a").
                 and_return(diag)
      expect(diag).to receive(:run).and_call_original

      find_all = contents_frame.all("a")
      test_all = Cornucopia::Capybara::FinderDiagnostics.test_finder(contents_frame, :all, "a")

      expect(find_all.length).to be == test_all.length
    end
  end

  it "outputs an analysis when diagnose_finder is called" do
    index_page = CornucopiaReportApp.index_page

    index_page.load base_folder: "sample_report"

    total_tests = 0
    index_page.contents do |contents_frame|
      total_tests = contents_frame.all("a").length
      diag = Cornucopia::Capybara::FinderDiagnostics::FindAction.
          new(contents_frame, {}, {}, :all, :css, "a", visible: true)
      expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).
          to receive(:new).
                 with(contents_frame, {}, {}, :all, :css, "a", visible: true).
                 and_return(diag)
      expect(diag).to receive(:run).and_call_original
      expect(diag).to receive(:generate_report).and_call_original

      test_all = Cornucopia::Capybara::FinderDiagnostics.
          diagnose_finder(contents_frame, :all, :css, "a", visible: true)

      expect(total_tests).to be == test_all.length
    end

    report_page = CornucopiaReportApp.cornucopia_report_holder_page
    report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

    expect(report_page.tests.length).to be >= 1

    report_page.tests[0].click
    report_page.displayed_test do |test_page|
      test_page.contents do |contents_frame|
        expect(contents_frame.errors.length).to be == 1
        # this line is the same as the next one.  I added this line to test a line in the site-prims extentions.
        expect(contents_frame.errors[0].find("p").text).to be == "Diagnostic report on \"all\":"
        expect(contents_frame.errors[0].name.text).to be == "Diagnostic report on \"all\":"
        expect(contents_frame.errors[0].tables[0].rows.length).to be == 4
        expect(contents_frame.errors[0].tables[0].rows[0].labels[0].text).to be == "function_name"
        expect(contents_frame.errors[0].tables[0].rows[0].values[0].text).to be == ":all"
        expect(contents_frame.errors[0].tables[0].rows[1].labels[0].text).to be == "args[0]"
        expect(contents_frame.errors[0].tables[0].rows[1].values[0].text).to be == ":css"
        expect(contents_frame.errors[0].tables[0].rows[2].labels[0].text).to be == "search_args"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables.length).to be == 1
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows.length).to be == 2
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[0].labels[0].text).to be == "0"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[0].values[0].text).to be == ":css"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[1].labels[0].text).to be == "1"
        expect(contents_frame.errors[0].tables[0].rows[2].sub_tables[0].rows[1].values[0].text).to be == "a"
        expect(contents_frame.errors[0].tables[0].rows[3].labels[0].text).to be == "options"
        expect(contents_frame.errors[0].tables[0].rows[3].sub_tables.length).to be == 1
        expect(contents_frame.errors[0].tables[0].rows[3].sub_tables[0].rows.length).to be == 1
        expect(contents_frame.errors[0].tables[0].rows[3].sub_tables[0].rows[0].labels[0].text).to be == "visible"
        expect(contents_frame.errors[0].tables[0].rows[3].sub_tables[0].rows[0].values[0].text).to be == "true"

        contents_frame.errors[0].more_details.show_hide.click
        expect(contents_frame.errors[0].more_details.details.rows.length).to be == 13
        expect(contents_frame.errors[0].more_details.details.rows[0].labels[0].text).to be == "all_elements"
        expect(contents_frame.errors[0].more_details.details.rows[0].sub_tables.length).to eq 1
        expect(contents_frame.errors[0].more_details.details.rows[0].sub_tables[0].rows.length).to eq total_tests
        expect(contents_frame.errors[0].more_details.details.rows[1].labels[0].text).to be == "args"
        expect(contents_frame.errors[0].more_details.details.rows[1].sub_tables[0].rows[0].labels[0].text).to be == "1"
        expect(contents_frame.errors[0].more_details.details.rows[1].sub_tables[0].rows[0].values[0].text).to be == "a"
        expect(contents_frame.errors[0].more_details.details.rows[1].sub_tables[0].rows[1].labels[0].text).to be == "2"
        expect(contents_frame.errors[0].more_details.details.rows[1].sub_tables[0].rows[1].values[0].text).to be == "{:visible=>true}"
        expect(contents_frame.errors[0].more_details.details.rows[2].labels[0].text).to be == "guessed_types"
        expect(contents_frame.errors[0].more_details.details.rows[2].values[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[3].labels[0].text).to be == "page_url"
        expect(contents_frame.errors[0].more_details.details.rows[3].values[0].text).
            to match %r{sample_report/index\.html}
        expect(contents_frame.errors[0].more_details.details.rows[4].labels[0].text).to be == "title"
        expect(contents_frame.errors[0].more_details.details.rows[4].values[0].text).
            to be == "Diagnostics report list"
        expect(contents_frame.errors[0].more_details.details.rows[5].labels[0].text).to be == "screen_shot"
        expect(contents_frame.errors[0].more_details.details.rows[5].value_images[0][:src]).
            to match /\/screen_shot\.png/
        expect(contents_frame.errors[0].more_details.details.rows[6].labels[0].text).to be == "browser_info"
        expect(contents_frame.errors[0].more_details.details.rows[7].labels[0].text).to be == "browser_logs"
        expect(contents_frame.errors[0].more_details.details.rows[8].labels[0].text).to be == "html_file"
        expect(contents_frame.errors[0].more_details.details.rows[8].value_links[0][:href]).
            to match /html_save_file\/__cornucopia_save_page\.html/
        expect(contents_frame.errors[0].more_details.details.rows[9].labels[0].text).to be == "html_frame"
        expect(contents_frame.errors[0].more_details.details.rows[9].value_frames[0][:src]).
            to match /page_dump\.html/
        expect(contents_frame.errors[0].more_details.details.rows[10].labels[0].text).to be == "html_source"
        expect(contents_frame.errors[0].more_details.details.rows[10].value_textareas[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[11].labels[0].text).to be == "page_height"
        expect(contents_frame.errors[0].more_details.details.rows[11].values[0].text).to be
        expect(contents_frame.errors[0].more_details.details.rows[12].labels[0].text).to be == "page_width"
        expect(contents_frame.errors[0].more_details.details.rows[12].values[0].text).to be
      end
    end
  end

  context "with a sample test file" do
    let(:base_folder) { File.absolute_path(File.join(File.dirname(@file_name_1), "../..")) }

    before(:example) do
      Cornucopia::Util::FileAsset.new("../../../spec/fixtures/sample_page.html").
          create_file(File.join(base_folder, "sample_report/sample_file.html"))

      ::Capybara.current_session.visit("/sample_report/sample_file.html")
    end

    it "creates a report even with an invalid finder" do
      expect { ::Capybara.current_session.find(:css, "a:invalid('finder')") }.
          to raise_exception(Selenium::WebDriver::Error::InvalidSelectorError)

      report_page = CornucopiaReportApp.cornucopia_report_holder_page
      report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

      expect(report_page.tests.length).to be >= 1
      report_page.tests[0].click
      report_page.displayed_test do |test_page|
        test_page.contents do |contents_frame|
          expect(contents_frame.errors.length).to be == 1
          contents_frame.errors[0].more_details.show_hide.click
          expect(contents_frame.errors[0].more_details.details.rows.length).to eq 14
          expect(contents_frame.errors[0].more_details.details.rows[0].labels[0].text).to eq "name"
          expect(contents_frame.errors[0].more_details.details.rows[1].labels[0].text).to eq "args"
          expect(contents_frame.errors[0].more_details.details.rows[2].labels[0].text).to eq "guessed_types"
          expect(contents_frame.errors[0].more_details.details.rows[3].labels[0].text).to eq "support_options"
          expect(contents_frame.errors[0].more_details.details.rows[4].labels[0].text).to eq "page_url"
          expect(contents_frame.errors[0].more_details.details.rows[5].labels[0].text).to eq "title"
          expect(contents_frame.errors[0].more_details.details.rows[6].labels[0].text).to eq "screen_shot"
          expect(contents_frame.errors[0].more_details.details.rows[7].labels[0].text).to be == "browser_info"
          expect(contents_frame.errors[0].more_details.details.rows[8].labels[0].text).to be == "browser_logs"
          expect(contents_frame.errors[0].more_details.details.rows[9].labels[0].text).to eq "html_file"
          expect(contents_frame.errors[0].more_details.details.rows[10].labels[0].text).to eq "html_frame"
          expect(contents_frame.errors[0].more_details.details.rows[11].labels[0].text).to eq "html_source"
          expect(contents_frame.errors[0].more_details.details.rows[12].labels[0].text).to eq "page_height"
          expect(contents_frame.errors[0].more_details.details.rows[13].labels[0].text).to eq "page_width"
        end
      end
    end

    it "finds hidden elements during analysis" do
      base_object = ::Capybara.current_session.find(:css, "#hidden-div", visible: false)
      expect { base_object.find("input[type=button]") }.to raise_error(Capybara::ElementNotFound)

      report_page = CornucopiaReportApp.cornucopia_report_holder_page
      report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

      expect(report_page.tests.length).to be >= 1
      report_page.tests[0].click
      report_page.displayed_test do |test_page|
        test_page.contents do |contents_frame|
          expect(contents_frame.errors.length).to be == 1
          contents_frame.errors[0].more_details.show_hide.click
          expect(contents_frame.errors[0].more_details.details.rows[2].labels[0].text).to be == "all_other_elements"

          hidden_row_specs = contents_frame.errors[0].more_details.details.rows[1].sub_tables[0].rows[0].sub_tables[0].rows
          expect(hidden_row_specs[0].labels[0].text).to be == "elem_checked"
          expect(hidden_row_specs[1].labels[0].text).to be == "elem_id"
          expect(hidden_row_specs[1].values[0].text).to be == "hidden-cool-button"
          expect(hidden_row_specs[2].labels[0].text).to be == "elem_location"
          expect(hidden_row_specs[2].sub_tables[0].rows[0].labels[0].text).to be == "x"
          expect(hidden_row_specs[2].sub_tables[0].rows[1].labels[0].text).to be == "y"
          expect(hidden_row_specs[3].labels[0].text).to be == "elem_outerHTML"
          expect(hidden_row_specs[4].labels[0].text).to be == "elem_path"
          expect(hidden_row_specs[5].labels[0].text).to be == "elem_selected"
          expect(hidden_row_specs[6].labels[0].text).to be == "elem_tag_name"
          expect(hidden_row_specs[7].labels[0].text).to be == "elem_value"
          expect(hidden_row_specs[8].labels[0].text).to be == "elem_visible"
          expect(hidden_row_specs[8].values[0].text).to be == "false"
          expect(hidden_row_specs[9].labels[0].text).to be == "native_aria_meta_data"
          expect(hidden_row_specs[10].labels[0].text).to be == "native_class"
          expect(hidden_row_specs[11].labels[0].text).to be == "native_onclick"
          expect(hidden_row_specs[12].labels[0].text).to be == "native_size"
          expect(hidden_row_specs[12].sub_tables[0].rows[0].labels[0].text).to be == "width"
          expect(hidden_row_specs[12].sub_tables[0].rows[1].labels[0].text).to be == "height"
          expect(hidden_row_specs[13].labels[0].text).to be == "native_type"
          expect(hidden_row_specs[13].values[0].text).to be == "button"
        end
      end
    end

    it "finds selection options using the from option" do
      report = Cornucopia::Util::ReportBuilder.current_report

      report.within_section("an existing section") do |section|
        section.within_table do |table|
          table.write_stats "something", "a value"
          find_action = Cornucopia::Capybara::FinderDiagnostics::FindAction.
              new ::Capybara.current_session,
                  { report: report,
                    table:  table },
                  {},
                  :find,
                  "100",
                  from: "select-box"

          allow(find_action).to receive(:guessed_types).and_return([])

          find_action.generate_report("inside diagnostics") do |report, report_table|
            report_table.write_stats("inside", "value")
          end
        end
      end

      report.close

      report_page = CornucopiaReportApp.cornucopia_report_holder_page
      report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

      expect(report_page.tests.length).to be >= 1
      report_page.tests[0].click
      report_page.displayed_test do |test_page|
        test_page.contents do |contents_frame|
          expect(contents_frame.errors.length).to be == 1

          the_row = contents_frame.errors[0].tables[0].rows[0]
          expect(the_row.labels[0].text).to be == "something"
          expect(the_row.values[0].text).to be == "a value"

          the_row = contents_frame.errors[0].tables[0].rows[2]
          expect(the_row.labels[0].text).to be == "function_name"
          expect(the_row.values[0].text).to be == ":find"

          the_row = contents_frame.errors[0].tables[0].rows.last
          expect(the_row.labels[0].text).to be == "inside"
          expect(the_row.values[0].text).to be == "value"
        end
      end
    end

    it "deals with it if the from isn't found" do
      find_action = Cornucopia::Capybara::FinderDiagnostics::FindAction.
          new ::Capybara.current_session,
              {},
              {},
              :select,
              "100",
              from: "select-boxes"

      find_action.generate_report("inside diagnostics")

      report_page = CornucopiaReportApp.cornucopia_report_holder_page
      report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

      expect(report_page.tests.length).to be >= 1
      report_page.tests[0].click
      report_page.displayed_test do |test_page|
        test_page.contents do |contents_frame|
          expect(contents_frame.errors.length).to be == 1

          the_row = contents_frame.errors[0].tables[1].rows[0]
          expect(the_row.labels[0].text).to be == "function_name"
          expect(the_row.values[0].text).to be == ":select"
        end
      end
    end

    it "will retry with what it actually finds..." do
      begin
        Cornucopia::Util::Configuration.retry_with_found = true

        base_object = ::Capybara.current_session.find(:css, "#hidden-div", visible: false)
        button      = base_object.all("input[type=button]", count: 1)

        expect(button.length).to be == 1
        expect(button[0].class).to be == ::Capybara::Node::Element

        report_page = CornucopiaReportApp.cornucopia_report_holder_page
        report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

        expect(report_page.tests.length).to be >= 1
        report_page.tests[0].click
        report_page.displayed_test do |test_page|
          test_page.contents do |contents_frame|
            contents_frame.errors[0].more_details.show_hide.click
            expect(contents_frame.errors.length).to be == 1
            expect(contents_frame.errors[0].tables[0].rows.last.labels[0].text).not_to be == "Retrying action:"
            expect(contents_frame.errors[0].more_details.details.rows.last.labels[0].text).to be == "Retrying action:"
            expect(contents_frame.errors[0].more_details.details.rows.last.values[0].text).to be == "Success"
          end
        end
      ensure
        Cornucopia::Util::Configuration.retry_with_found = false
      end
    end

    describe "#retry_action_with_found_element" do
      it "find and it will appropriately handle the driver not supporting evaluate_script" do
        begin
          Cornucopia::Util::Configuration.retry_with_found = true

          base_object = ::Capybara.current_session.find(:css, "#hidden-div", visible: false)
          button      = base_object.find("input[type=button]")

          expect(button.class).to be == ::Capybara::Node::Element

          report_page = CornucopiaReportApp.cornucopia_report_holder_page
          report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

          expect(report_page.tests.length).to be >= 1
          report_page.tests[0].click
          report_page.displayed_test do |test_page|
            test_page.contents do |contents_frame|
              contents_frame.errors[0].more_details.show_hide.click
              expect(contents_frame.errors.length).to be == 1
              expect(contents_frame.errors[0].tables[0].rows.last.labels[0].text).not_to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.labels[0].text).to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.values[0].text).to be == "Success"
            end
          end
        ensure
          Cornucopia::Util::Configuration.retry_with_found = false
        end
      end

      it "first" do
        begin
          Cornucopia::Util::Configuration.retry_with_found = true

          allow_any_instance_of(::Capybara::Node::Element).to receive(:outerHTML).and_return(nil)

          expect(::Capybara.current_session).
              to receive(:evaluate_script).at_least(1).times.and_raise(::Capybara::NotSupportedByDriverError)
          expect_any_instance_of(::Selenium::WebDriver::Driver).
              to receive(:execute_script).at_least(1).times.and_raise(::Capybara::NotSupportedByDriverError)

          base_object = ::Capybara.current_session.find(:css, "#hidden-div", visible: false)
          button      = base_object.first("input[type='button']", count: 1)

          expect(button.class).to be == ::Capybara::Node::Element

          report_page = CornucopiaReportApp.cornucopia_report_holder_page
          report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

          expect(report_page.tests.length).to be >= 1
          report_page.tests[0].click
          report_page.displayed_test do |test_page|
            test_page.contents do |contents_frame|
              contents_frame.errors[0].more_details.show_hide.click
              expect(contents_frame.errors.length).to be == 1
              expect(contents_frame.errors[0].tables[0].rows.last.labels[0].text).not_to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.labels[0].text).to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.values[0].text).to be == "Success"
            end
          end
        ensure
          Cornucopia::Util::Configuration.retry_with_found = false
        end
      end

      it "works with assert_selector" do
        begin
          Cornucopia::Util::Configuration.retry_match_with_found = true

          allow_any_instance_of(::Capybara::Node::Element).to receive(:outerHTML).and_return(nil)

          expect(::Capybara.current_session).
              to receive(:evaluate_script).at_least(1).times.and_raise(::Capybara::NotSupportedByDriverError)
          expect_any_instance_of(::Selenium::WebDriver::Driver).
              to receive(:execute_script).at_least(1).times.and_raise(::Capybara::NotSupportedByDriverError)

          base_object = ::Capybara.current_session.find(:css, "#hidden-div", visible: false)
          button      = base_object.assert_selector("input[type='button']", count: 1)

          expect(button).to be true

          report_page = CornucopiaReportApp.cornucopia_report_holder_page
          report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

          expect(report_page.tests.length).to be >= 1
          report_page.tests[0].click
          report_page.displayed_test do |test_page|
            test_page.contents do |contents_frame|
              contents_frame.errors[0].more_details.show_hide.click
              expect(contents_frame.errors.length).to be == 1
              expect(contents_frame.errors[0].tables[0].rows.last.labels[0].text).not_to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.labels[0].text).to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.values[0].text).to be == "Found"
            end
          end
        ensure
          Cornucopia::Util::Configuration.retry_match_with_found = false
        end
      end

      it "works with assert_no_selector" do
        begin
          Cornucopia::Util::Configuration.retry_match_with_found = true

          allow_any_instance_of(::Capybara::Node::Element).to receive(:outerHTML).and_return(nil)

          allow(::Capybara.current_session).
              to receive(:evaluate_script).and_raise(::Capybara::NotSupportedByDriverError)
          allow_any_instance_of(::Selenium::WebDriver::Driver).
              to receive(:execute_script).and_raise(::Capybara::NotSupportedByDriverError)

          base_object       = ::Capybara.current_session.find(:css, "#hidden-div", visible: false)
          find_button       = base_object.all("#hidden-cool-button", count: 1, visible: false)
          empty_find_button = base_object.all("#hidden-cool-button", count: 1, visible: false)

          allow_any_instance_of(::Cornucopia::Capybara::FinderDiagnostics::FindAction).
              to receive(:all_elements).and_return []
          allow_any_instance_of(::Cornucopia::Capybara::FinderDiagnostics::FindAction).
              to receive(:all_other_elements).and_return []
          allow(empty_find_button).to receive(:size).and_return 0
          allow_any_instance_of(::Capybara::Node::Element).
              to receive(:all).
                     and_call_original
          allow_any_instance_of(::Capybara::Node::Element).
              to receive(:all).
                     with("Still cool!", { count: 1 }).
                     and_return(find_button)
          allow_any_instance_of(::Capybara::Node::Element).
              to receive(:all).
                     with(instance_of(Symbol), "Still cool!", { visible: false, __cornucopia_no_analysis: true }).
                     and_return(empty_find_button)
          allow_any_instance_of(::Capybara::Node::Element).
              to receive(:all).
                     with("Still cool!", { visible: false, __cornucopia_no_analysis: true }).
                     and_return(empty_find_button)

          button = base_object.assert_no_selector("Still cool!", count: 1)

          expect(button).to be true

          report_page = CornucopiaReportApp.cornucopia_report_holder_page
          report_page.load(report_name: "cornucopia_report", base_folder: "cornucopia_report")

          expect(report_page.tests.length).to be >= 1
          report_page.tests[0].click
          report_page.displayed_test do |test_page|
            test_page.contents do |contents_frame|
              contents_frame.errors[0].more_details.show_hide.click
              expect(contents_frame.errors.length).to be == 1
              expect(contents_frame.errors[0].tables[0].rows.last.labels[0].text).not_to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.labels[0].text).to be == "Retrying action:"
              expect(contents_frame.errors[0].more_details.details.rows.last.values[0].text).to be == "Not Found"
            end
          end
        ensure
          Cornucopia::Util::Configuration.retry_match_with_found = false
        end
      end

      it "finds selection options using the from option" do
        report = Cornucopia::Util::ReportBuilder.current_report

        module Cornucopia
          module Capybara
            class FinderDiagnostics
              def self.test_finder_stupid
                found_1 = FindAction::FoundElement.new(::Capybara.page.find("#select-box"))
                found_2 = FindAction::FoundElement.new(::Capybara.page.find("#select-box"))

                found_1 == found_2
              end

              def self.test_not_finder_stupid
                found_1 = FindAction::FoundElement.new(::Capybara.page.find("#select-box"))
                found_2 = FindAction::FoundElement.new(::Capybara.page.find("#multi-select-box"))

                found_1 == found_2
              end
            end
          end
        end

        expect(Cornucopia::Capybara::FinderDiagnostics.test_finder_stupid).to be_truthy
        expect(Cornucopia::Capybara::FinderDiagnostics.test_not_finder_stupid).to be_falsey
      end
    end
  end

  describe "FindAction" do
    it "returns perform_analysis's result" do
      index_page = CornucopiaReportApp.index_page

      index_page.load base_folder: "sample_report"

      index_page.contents do |contents_frame|
        tester     = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(contents_frame, {}, {}, :find, "#base-contentss")
        test_value = [nil, true, false, Faker::Lorem.sentence].sample

        expect(tester).to receive(:perform_analysis).and_return true
        tester.instance_variable_set(:@return_value, test_value)

        expect(tester.run).to eq test_value
      end
    end
  end
end
