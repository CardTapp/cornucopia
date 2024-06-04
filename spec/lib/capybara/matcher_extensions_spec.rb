# frozen_string_literal: true

require "rails_helper"
require ::File.expand_path("../../../lib/cornucopia/capybara/matcher_extensions", File.dirname(__FILE__))

describe Cornucopia::Capybara::MatcherExtensions, type: :feature do
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

  describe "#__cornucopia_assert_selector_function" do
    it "should retry if a Selenium cache error is thrown" do
      index_page = CornucopiaReportApp.index_page

      index_page.load base_folder: "sample_report"

      index_page.contents do |contents_frame|
        found_elements = contents_frame.assert_selector("a", __cornucopia_no_analysis: true)

        num_retries = rand(1..(Cornucopia::Util::Configuration.selenium_cache_retry_count - 1))
        time_count  = num_retries
        num_calls   = 0

        allow(contents_frame.page.document).
            to receive(:__cornucopia__call_super?) do |function_name, *args|
          next true if function_name != :assert_selector

          num_calls += 1

          if time_count > 0
            time_count -= 1
            raise Selenium::WebDriver::Error::StaleElementReferenceError.new
          end

          expect(args).to be == ["a"]
          true
        end

        second_found = contents_frame.assert_selector("a")

        allow(contents_frame.page.document).to receive(:__cornucopia__call_super?).and_call_original

        # I realize that this is almost like testing that the stub worked, which we don't need to test.
        # However, we are really testing that the results returned by the stub are passed back all the way
        # Which we do need to test.
        expect(second_found).to be == found_elements
        expect(time_count).to be == 0
        expect(num_calls).to be == num_retries + 1
      end
    end

    it "should call __cornucopia__analyze_selector if it cannot resolve the stale reference" do
      index_page = CornucopiaReportApp.index_page

      index_page.load base_folder: "sample_report"

      index_page.contents do |contents_frame|
        found_elements = contents_frame.assert_selector("a", __cornucopia_no_analysis: true)

        # Because we are over riding the original call, we just stub this out
        # because it cannot work properly.
        expect(contents_frame.page.document).
            to receive(:__cornucopia__analyze_selector).
                   and_return(found_elements)

        allow(contents_frame.page.document).
            to receive(:__cornucopia__call_super?) do |function_name|
          next true if function_name != :assert_selector

          raise Selenium::WebDriver::Error::StaleElementReferenceError.new
        end

        second_found = contents_frame.assert_selector("a")

        allow(contents_frame.page.document).to receive(:__cornucopia__call_super?).and_call_original

        # I realize that this is almost like testing that the stub worked, which we don't need to test.
        # However, we are really testing that the results returned by the stub are passed back all the way
        # Which we do need to test.
        expect(second_found).to be == found_elements
      end
    end

    it "should call __cornucopia__analyze_selector if an exception is thrown" do
      index_page = CornucopiaReportApp.index_page

      index_page.load base_folder: "sample_report"

      index_page.contents do |contents_frame|
        found_elements = contents_frame.assert_no_selector("notfound .report-block", __cornucopia_no_analysis: true)

        # Because we are over riding the original call, we just stub this out
        # because it cannot work properly.
        expect(contents_frame.page.document).
            to receive(:__cornucopia__analyze_selector).
                   and_return(found_elements)

        allow(contents_frame.page.document).to receive(:__cornucopia__call_super?) do |function_name|
          next true if function_name != :assert_no_selector
          raise "This is an error"
        end

        second_found = contents_frame.assert_no_selector(".report-block")

        allow(contents_frame.page.document).to receive(:__cornucopia__call_super?).and_call_original

        # I realize that this is almost like testing that the stub worked, which we don't need to test.
        # However, we are really testing that the results returned by the stub are passed back all the way
        # Which we do need to test.
        expect(second_found).to be == found_elements
      end
    end
  end

  def get_object(object_type)
    case (object_type)
      when :page
        ::Capybara.page

      when :document
        ::Capybara.page.document

      when :body
        ::Capybara.page.document.find("html")
    end
  end

  [:page, :document, :body].each do |object_type|
    describe "#__cornucopia__analyze_selector for #{object_type}" do
      it "does nothing if this is called from the analysis function" do
        index_page = CornucopiaReportApp.index_page

        index_page.load base_folder: "sample_report"

        Cornucopia::Util::Configuration.analyze_find_exceptions = true

        expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).not_to receive(:new)

        expect { get_object(object_type).assert_selector "boody", __cornucopia_no_analysis: true }.
            to raise_error(::Capybara::ExpectationNotMet)
      end

      it "does nothing if this is called from the analysis function no_selector" do
        index_page = CornucopiaReportApp.index_page

        index_page.load base_folder: "sample_report"

        Cornucopia::Util::Configuration.analyze_find_exceptions = true

        expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).not_to receive(:new)

        expect { get_object(object_type).assert_no_selector "body", __cornucopia_no_analysis: true }.
            to raise_error(::Capybara::ExpectationNotMet)
      end

      it "does nothing if configuration is turned off" do
        begin
          index_page = CornucopiaReportApp.index_page

          index_page.load base_folder: "sample_report"

          Cornucopia::Util::Configuration.analyze_selector_exceptions = false

          expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).not_to receive(:new)

          expect { get_object(object_type).assert_selector "boody" }.to raise_error(::Capybara::ExpectationNotMet)
        ensure
          Cornucopia::Util::Configuration.analyze_selector_exceptions = true
        end
      end

      it "does nothing if configuration is turned off no_selector" do
        begin
          index_page = CornucopiaReportApp.index_page

          index_page.load base_folder: "sample_report"

          Cornucopia::Util::Configuration.analyze_selector_exceptions = false

          expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).not_to receive(:new)

          expect { get_object(object_type).assert_no_selector "body" }.to raise_error(::Capybara::ExpectationNotMet)
        ensure
          Cornucopia::Util::Configuration.analyze_selector_exceptions = true
        end
      end

      it "calls perform analysis with values from the configuration and returns the results" do
        begin
          index_page = CornucopiaReportApp.index_page

          index_page.load base_folder: "sample_report"

          Cornucopia::Util::Configuration.analyze_selector_exceptions = true

          the_obj        = get_object(object_type)
          stubbed_finder = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(the_obj, {}, {}, "boody")
          found_body     = the_obj.assert_selector("body")

          expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).to receive(:new).and_return(stubbed_finder)

          retry_found                                            = [true, false].sample
          # retry_alt   = [true, false].sample

          Cornucopia::Util::Configuration.retry_match_with_found = retry_found
          # Cornucopia::Util::Configuration.alternate_retry  = retry_alt

          retry_found                                            = retry_found || nil
          # retry_alt   = retry_alt || nil

          expect(stubbed_finder).to receive(:perform_analysis).with(retry_found).and_return true
          expect(stubbed_finder).to receive(:return_value).and_return found_body

          expect(the_obj.assert_selector("boody")).to be == found_body
        ensure
          Cornucopia::Util::Configuration.retry_match_with_found = false
          # Cornucopia::Util::Configuration.alternate_retry  = false
        end
      end

      it "calls perform analysis with values from the configuration and returns the results no_selector" do
        begin
          index_page = CornucopiaReportApp.index_page

          index_page.load base_folder: "sample_report"

          Cornucopia::Util::Configuration.analyze_selector_exceptions = true

          the_obj        = get_object(object_type)
          stubbed_finder = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(the_obj, {}, {}, "body")
          found_body     = the_obj.assert_no_selector("boody")

          expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).to receive(:new).and_return(stubbed_finder)

          retry_found                                            = [true, false].sample
          # retry_alt   = [true, false].sample

          Cornucopia::Util::Configuration.retry_match_with_found = retry_found
          # Cornucopia::Util::Configuration.alternate_retry  = retry_alt

          retry_found                                            = retry_found || nil
          # retry_alt   = retry_alt || nil

          expect(stubbed_finder).to receive(:perform_analysis).with(retry_found).and_return true
          expect(stubbed_finder).to receive(:return_value).and_return found_body

          expect(the_obj.assert_no_selector("body")).to be == found_body
        ensure
          Cornucopia::Util::Configuration.retry_match_with_found = false
          # Cornucopia::Util::Configuration.alternate_retry  = false
        end
      end

      it "re-raises the last error if the analysis doesn't find anything" do
        begin
          index_page = CornucopiaReportApp.index_page

          index_page.load base_folder: "sample_report"

          Cornucopia::Util::Configuration.analyze_selector_exceptions = true

          the_obj        = get_object(object_type)
          stubbed_finder = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(the_obj, {}, {}, "boody")
          # found_body     = the_obj.assert_selector("boody")

          expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).to receive(:new).and_return(stubbed_finder)

          retry_found                                            = [true, false].sample
          # retry_alt   = [true, false].sample

          Cornucopia::Util::Configuration.retry_match_with_found = retry_found
          # Cornucopia::Util::Configuration.alternate_retry  = retry_alt

          retry_found                                            = retry_found || nil
          # retry_alt   = retry_alt || nil

          expect(stubbed_finder).to receive(:perform_analysis).with(retry_found).and_return false

          expect { (the_obj.assert_selector("boody")) }.to raise_error(::Capybara::ExpectationNotMet)
        ensure
          Cornucopia::Util::Configuration.retry_match_with_found = false
          # Cornucopia::Util::Configuration.alternate_retry  = false
        end
      end

      it "re-raises the last error if the analysis doesn't find anything no_selector" do
        begin
          index_page = CornucopiaReportApp.index_page

          index_page.load base_folder: "sample_report"

          Cornucopia::Util::Configuration.analyze_selector_exceptions = true

          the_obj        = get_object(object_type)
          stubbed_finder = Cornucopia::Capybara::FinderDiagnostics::FindAction.new(the_obj, {}, {}, "body")
          # found_body     = the_obj.assert_no_selector("body")

          expect(Cornucopia::Capybara::FinderDiagnostics::FindAction).to receive(:new).and_return(stubbed_finder)

          retry_found                                            = [true, false].sample
          # retry_alt   = [true, false].sample

          Cornucopia::Util::Configuration.retry_match_with_found = retry_found
          # Cornucopia::Util::Configuration.alternate_retry  = retry_alt

          retry_found                                            = retry_found || nil
          # retry_alt   = retry_alt || nil

          expect(stubbed_finder).to receive(:perform_analysis).with(retry_found).and_return false

          expect { (the_obj.assert_no_selector("body")) }.to raise_error(::Capybara::ExpectationNotMet)
        ensure
          Cornucopia::Util::Configuration.retry_match_with_found = false
          # Cornucopia::Util::Configuration.alternate_retry  = false
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

      describe "ignore_has_selector_errors = false" do
        before(:example) do
          Cornucopia::Util::Configuration.ignore_has_selector_errors = true
        end

        after(:example) do
          Cornucopia::Util::Configuration.ignore_has_selector_errors = true
        end

        it "finds a has_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_selector?("\#select-box")).to be_truthy
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey
        end

        it "does not find a has_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_selector?("\#select-box-not-there")).to be_falsey
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey
        end

        it "finds a has_no_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_no_selector?("\#select-box-not-there")).to be_truthy
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey
        end

        it "does not find a has_no_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_no_selector?("\#select-box")).to be_falsey
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey
        end
      end

      describe "ignore_has_selector_errors = false" do
        before(:example) do
          Cornucopia::Util::Configuration.ignore_has_selector_errors = false
        end

        after(:example) do
          Cornucopia::Util::Configuration.ignore_has_selector_errors = true
        end

        it "finds a has_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_selector?("\#select-box")).to be_truthy
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey
        end

        it "does not find a has_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_selector?("\#select-box-not-there")).to be_falsey
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_truthy
        end

        it "finds a has_no_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_no_selector?("\#select-box-not-there")).to be_truthy
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey
        end

        it "does not find a has_no_selector? item and does not create a report" do
          expect(::Capybara.current_session.has_no_selector?("\#select-box")).to be_falsey
          expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_truthy
        end
      end
    end
  end
end
