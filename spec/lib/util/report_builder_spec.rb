# frozen_string_literal: true

require "rails_helper"
require ::File.expand_path("../../../lib/cornucopia/util/report_builder", File.dirname(__FILE__))

describe Cornucopia::Util::ReportBuilder do
  let(:test_names) do
    rand(3..5).times.map do
      Faker::Lorem.sentence
    end
  end
  let(:section_names) do
    test_names.length.times.map do
      Faker::Lorem.sentence
    end
  end
  let(:current_report) { Cornucopia::Util::ReportBuilder.new_report }
  let(:custom_report) { Cornucopia::Util::ReportBuilder.new_report("cool_report", "diag_reports") }

  report_variation_settings = [
      { report:       :current_report,
        index_folder: "cornucopia_report",
        sub_folder:   "cornucopia_report" },
      { report:       :custom_report,
        index_folder: "diag_reports",
        sub_folder:   "cool_report" }
  ]

  # Make sure that all tests start clean and get cleaned up afterwards...
  around(:each) do |example|
    expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey
    expect(File.directory?(Rails.root.join("diag_reports/"))).to be_falsey

    begin
      example.run
    ensure
      if (Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report"))
        Cornucopia::Util::ReportBuilder.current_report.close
      end

      FileUtils.rm_rf Rails.root.join("cornucopia_report/")
      FileUtils.rm_rf Rails.root.join("diag_reports/")
    end
  end

  describe "#on_close" do
    around(:each) do |example|
      num_close_calls = Cornucopia::Util::ReportBuilder.class_variable_get("@@on_close_blocks").length

      example.run

      while num_close_calls != Cornucopia::Util::ReportBuilder.class_variable_get("@@on_close_blocks").length
        Cornucopia::Util::ReportBuilder.class_variable_get("@@on_close_blocks").pop
      end
    end

    it "calls each on_close block" do
      report_results = []

      Cornucopia::Util::ReportBuilder.on_close do
        report_results << 1
      end

      Cornucopia::Util::ReportBuilder.on_close do
        report_results << 2
      end

      Cornucopia::Util::ReportBuilder.on_close do
        report_results << 3
      end

      Cornucopia::Util::ReportBuilder.current_report.close

      expect(report_results).to be == [1, 2, 3]
      expect(Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report")).not_to be
    end

    it "calls each on_close block even if an exception is thrown" do
      report_results = []

      Cornucopia::Util::ReportBuilder.on_close do
        report_results << 1
        raise "1"
      end

      Cornucopia::Util::ReportBuilder.on_close do
        report_results << 2
        raise "2"
      end

      Cornucopia::Util::ReportBuilder.on_close do
        report_results << 3
        raise "3"
      end

      expect do
        Cornucopia::Util::ReportBuilder.current_report.close
      end.to raise_exception

      expect(report_results).to be == [1, 2, 3]
      expect(Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report")).not_to be
    end
  end

  describe "#escape_string" do
    it "makes a string html_safe" do
      expect(Cornucopia::Util::ReportBuilder.escape_string("test_value")).to be_html_safe
    end

    it "escapes html characters" do
      expect(Cornucopia::Util::ReportBuilder.escape_string("<test_value>")).to be == "&lt;test_value&gt;"
    end
  end

  describe "#format_code_refs" do
    it "does not alter a string without refs" do
      sample_string = "This is a sample string /fred/george.html:45"

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be == sample_string
    end

    it "ensures that the string is html_safe" do
      sample_string = "This is a sample string /fred/george.html:45"

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be_html_safe
    end

    it "formats the refs in a string" do
      sample_string = "This is a sample string ./features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445 > :in `block (2 levels) in <top (required)>'"
      result_string = "This is a sample string ./ <span class=\"cornucopia-app-file\">features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445</span>  &gt; :in `block (2 levels) in &lt;top (required)&gt;&#39;"

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be == result_string
    end

    it "formats the refs in a string but not the : after unless it has a number" do
      sample_string = "This is a sample string ./features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb :in `block (2 levels) in <top (required)>'"
      result_string = "This is a sample string ./ <span class=\"cornucopia-app-file\">features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb</span>  :in `block (2 levels) in &lt;top (required)&gt;&#39;"

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be == result_string
    end

    it "formats the refs in a string starting with features" do
      sample_string = "features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb : 445 > :in `block (2 levels) in <top (required)>'"
      result_string = " <span class=\"cornucopia-app-file\">features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb : 445</span>  &gt; :in `block (2 levels) in &lt;top (required)&gt;&#39;"

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be == result_string
    end

    it "formats the refs in a string starting with spec" do
      sample_string = "spec/admin2/step_definitions/daily_email_deal_scheduling_steps.rb : 445 > :in `block (2 levels) in <top (required)>'"
      result_string = " <span class=\"cornucopia-app-file\">spec/admin2/step_definitions/daily_email_deal_scheduling_steps.rb : 445</span>  &gt; :in `block (2 levels) in &lt;top (required)&gt;&#39;"

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be == result_string
    end

    it "formats the refs root refs in a string" do
      sample_string = "This is a sample string c:/bizarro/features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445 > :in `block (2 levels) in <top (required)>'"
      result_string = "This is a sample string c:/bizarro/ <span class=\"cornucopia-app-file\">features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445</span>  &gt; :in `block (2 levels) in &lt;top (required)&gt;&#39;"

      allow(Cornucopia::Util::ReportBuilder).to receive(:root_folder).and_return("c:/bizarro/")

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be == result_string
    end

    it "formats multiple refs root refs in a string" do
      sample_string = "This is a sample string c:/bizarro/features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445 > :in `block (2 levels) in <top (required)>'
This is a sample string c:/bizarro/features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445 > :in `block (2 levels) in <top (required)>'"
      result_string = "This is a sample string c:/bizarro/ <span class=\"cornucopia-app-file\">features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445</span>  &gt; :in `block (2 levels) in &lt;top (required)&gt;&#39;
This is a sample string c:/bizarro/ <span class=\"cornucopia-app-file\">features/admin2/step_definitions/daily_email_deal_scheduling_steps.rb:445</span>  &gt; :in `block (2 levels) in &lt;top (required)&gt;&#39;"

      allow(Cornucopia::Util::ReportBuilder).to receive(:root_folder).and_return("c:/bizarro/")

      expect(Cornucopia::Util::ReportBuilder.format_code_refs(sample_string)).to be == result_string
    end
  end

  describe "#root_folder" do
    it "returns the rails root if it is available" do
      expect(Cornucopia::Util::ReportBuilder.root_folder).to be == Rails.root
    end

    it "returns the pwd if Rails is not available" do
      expect(Object).to receive(:const_defined?).with("Rails").and_return false

      expect(Cornucopia::Util::ReportBuilder.root_folder).to be == FileUtils.pwd
    end
  end

  describe "#pretty_array" do
    let(:array_values) { [
        "Turner &amp; Hooch",
        "Barney Rubble",
        "Harvey"
    ] }

    it "ignores a non-array value" do
      expect(Cornucopia::Util::ReportBuilder.pretty_array("a string")).to be == "a string"
    end

    it "calls #pretty_format for a non-array value" do
      expect(Cornucopia::Util::ReportBuilder).to receive(:pretty_format).once.and_call_original

      expect(Cornucopia::Util::ReportBuilder.pretty_array("a string")).to be_html_safe
    end

    it "calls #pretty_format for each element in the array" do
      expect(Cornucopia::Util::ReportBuilder).to receive(:pretty_format).exactly(3).and_call_original

      formatted_code = Cornucopia::Util::ReportBuilder.pretty_array(array_values)

      expect(formatted_code).to be_html_safe
      expect(formatted_code).to be == "Turner &amp;amp; Hooch\nBarney Rubble\nHarvey"
    end

    it "calls #pretty_format on a sub-array after it is converted to a string" do
      expect(Cornucopia::Util::ReportBuilder).
          to receive(:pretty_format).
              with(anything, in_pretty_print: true).
              exactly(4).
              times.
              and_call_original

      array_values << [1, 2, 3]

      formatted_code = Cornucopia::Util::ReportBuilder.pretty_array(array_values)

      expect(formatted_code).to be_html_safe
      expect(formatted_code).to be == "Turner &amp;amp; Hooch\nBarney Rubble\nHarvey\n[1, 2, 3]"
    end

    it "doesn't call #pretty_format on values if told not to" do
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_format)

      array_values << [1, 2, 3]

      formatted_code = Cornucopia::Util::ReportBuilder.pretty_array(array_values, false)

      expect(formatted_code).to be_html_safe
      expect(formatted_code).to be == "Turner &amp; Hooch\nBarney Rubble\nHarvey\n[1, 2, 3]"
    end
  end

  describe "#pretty_object" do
    around(:each) do |example|
      orig_timeout = Cornucopia::Util::Configuration.print_timeout_min

      begin
        Cornucopia::Util::Configuration.print_timeout_min = 2
        example.run
      ensure
        Cornucopia::Util::Configuration.print_timeout_min = orig_timeout
      end
    end

    it "returns a string as-is" do
      test_object = "a string".dup

      expect(test_object).not_to receive(:pretty_inspect)
      expect(test_object).not_to receive(:to_s)
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      Cornucopia::Util::ReportBuilder.pretty_object(test_object)
    end

    it "calls pretty_inspect on most objects" do
      test_object = { a: "b" }

      expect(test_object).to receive(:pretty_inspect).and_call_original
      expect(test_object).not_to receive(:to_s)
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      Cornucopia::Util::ReportBuilder.pretty_object(test_object)
    end

    it "times out after a long time" do
      test_object = { a: "b" }

      expect(test_object).to receive(:pretty_inspect) { sleep 60 }
      expect(test_object).to receive(:to_s).and_call_original
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      expect(Cornucopia::Util::ReportBuilder.pretty_object(test_object)).to be == "{:a=>\"b\"}"
    end

    it "deals with exceptions" do
      test_object = { a: "b" }

      expect(test_object).to receive(:pretty_inspect) { raise "this is an error" }
      expect(test_object).to receive(:to_s) { raise "this is an error" }
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      expect(Cornucopia::Util::ReportBuilder.pretty_object(test_object)).to match /Rendering error =\>/
    end

    it "times out after a long time with t_s too" do
      test_object = { a: "b" }

      expect(test_object).to receive(:pretty_inspect) { sleep 60 }
      expect(test_object).to receive(:to_s) { sleep 60 }
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      expect(Cornucopia::Util::ReportBuilder.pretty_object(test_object)).to be == "Timed out rendering"
    end

    it "calls to_s after an exception is raised" do
      test_object = { a: "b" }

      expect(test_object).to receive(:pretty_inspect) { raise Exception.new("This is an error") }
      expect(test_object).to receive(:to_s).and_call_original
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      expect(Cornucopia::Util::ReportBuilder.pretty_object(test_object)).to be == "{:a=>\"b\"}"
    end

    it "times out after an exception is raised" do
      test_object = { a: "b" }

      expect(test_object).to receive(:pretty_inspect) { raise Exception.new("This is an error") }
      expect(test_object).to receive(:to_s) { sleep 60 }
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      expect(Cornucopia::Util::ReportBuilder.pretty_object(test_object)).to be == "Timed out rendering"
    end

    it "returns an array by formatting it" do
      test_object = [:a, "b"]

      expect(test_object).not_to receive(:pretty_inspect)
      expect(test_object).not_to receive(:to_s)
      expect(Cornucopia::Util::ReportBuilder).to receive(:pretty_array).and_call_original

      Cornucopia::Util::ReportBuilder.pretty_object(test_object)
    end

    it "returns an object that cannot be inspected as a string" do
      test_object = { a: "b" }

      expect(test_object).to receive(:respond_to?).and_return false

      expect(test_object).not_to receive(:pretty_inspect)
      expect(test_object).to receive(:to_s).and_call_original
      expect(Cornucopia::Util::ReportBuilder).not_to receive(:pretty_array)

      Cornucopia::Util::ReportBuilder.pretty_object(test_object)
    end
  end

  it "should create a new report" do
    orig_report = Cornucopia::Util::ReportBuilder.current_report
    report      = Cornucopia::Util::ReportBuilder.new_report

    expect(report).to_not be == orig_report

    alt_report = Cornucopia::Util::ReportBuilder.current_report

    expect(report).to be == alt_report
  end

  it "should create a new report if the current report doesn't match" do
    orig_report = Cornucopia::Util::ReportBuilder.current_report
    report      = Cornucopia::Util::ReportBuilder.current_report("cool_report", "diag_reports")

    expect(report).to_not be == orig_report

    alt_report = Cornucopia::Util::ReportBuilder.current_report("cool_report", "diag_reports")

    expect(report).to be == alt_report

    alt_report = Cornucopia::Util::ReportBuilder.current_report("cool_report")

    expect(report).to be == alt_report

    alt_report = Cornucopia::Util::ReportBuilder.current_report

    expect(report).to be == alt_report
  end

  describe "#folder_name_to_section_name" do
    it "returns a special value for cornucopia_report" do
      expect(Cornucopia::Util::ReportBuilder.folder_name_to_section_name("cornucopia_report")).
          to be == "Feature Tests"
    end

    it "returns a special value for diagnostics_rspec_report" do
      expect(Cornucopia::Util::ReportBuilder.folder_name_to_section_name("diagnostics_rspec_report")).
          to be == "RSPEC Tests"
    end

    it "returns the passed in value if nothing else" do
      value = Faker::Lorem.word
      expect(Cornucopia::Util::ReportBuilder.folder_name_to_section_name("#{value}")).to be == value
    end

    it "returns the basename of the passed in value" do
      value = Faker::Lorem.word
      expect(Cornucopia::Util::ReportBuilder.folder_name_to_section_name("#{Faker::Lorem.word}/#{value}")).
          to be == value
    end
  end

  describe "#build_index_section_item" do
    it "creates a list item with an anchor" do
      result_string = Cornucopia::Util::ReportBuilder.build_index_section_item("harold/fred/george.html")

      expect(result_string).to match /href=\"harold\/fred\/george.html\"/
      expect(result_string).to match /\>harold\/fred\</
      expect(result_string).to match /\<li\>/
      expect(result_string).to match /\<\/li\>/
    end
  end

  describe "#build_index_section" do
    it "creates a list item with an anchor" do
      a_title = Faker::Lorem.sentence
      strings = Faker::Lorem.sentences(number: 5)
      strings.map! { |string| string.gsub(" ", "/") }
      result_string = Cornucopia::Util::ReportBuilder.build_index_section(a_title, strings)

      expect(result_string).to match /#{a_title}/
      strings.each do |a_string|
        expect(result_string).to match /href=\"#{a_string}\"/
        expect(result_string).to match /\>#{File.dirname(a_string)}\</
      end
      expect(result_string).to match /\<ul.*?\>/
      expect(result_string).to match /\<\/ul\>/
    end
  end

  describe "#page_dump" do
    it "outputs a text area with the page html_encoded" do
      source_html = "<html>\n<body>\nThis is some &amp; awesome text</body>\n</html>"
      page_html   = Cornucopia::Util::ReportBuilder.page_dump(source_html)
      source_html = "".html_safe + source_html

      expect(page_html).to match /\>#{source_html}\</
      expect(page_html).to match /^\<textarea/
    end
  end

  report_variation_settings.each do |report_settings|
    index_folder  = Rails.root.join("#{report_settings[:index_folder]}/")
    report_folder = File.join(index_folder, "#{report_settings[:sub_folder]}/")

    describe "When using #{report_settings[:report]}" do
      it "should return a report" do
        expect(send(report_settings[:report]).is_a?(Cornucopia::Util::ReportBuilder)).to be_truthy
      end

      describe "#index_folder_name" do
        it "should create and return the folder for the base index file" do
          folder_name       = index_folder
          index_folder_name = nil

          expect(File.directory?(folder_name)).to be_falsey

          begin
            index_folder_name = send(report_settings[:report]).index_folder_name

            expect(index_folder_name.to_s).to be == folder_name.to_s
            expect(File.directory?(index_folder_name)).to be_truthy
          ensure
            FileUtils.rm_rf index_folder_name if index_folder_name
            FileUtils.rm_rf folder_name
          end
        end
      end

      describe "#delete_old_folders" do
        it "does nothing if there are too few old folders" do
          folder_name = index_folder

          expect(File.directory?(folder_name)).to be_falsey

          begin
            num_folders = rand(Cornucopia::Util::ReportBuilder::MAX_OLD_FOLDERS)
            (1..num_folders).to_a.each do |report_index|
              FileUtils.mkdir_p(File.join(folder_name, "#{report_settings[:sub_folder]}_#{report_index}"))
            end

            send(report_settings[:report]).delete_old_folders

            (1..num_folders).to_a.each do |report_index|
              expect(File.directory?(File.join(folder_name, "#{report_settings[:sub_folder]}_#{report_index}"))).to be_truthy
            end
          ensure
            FileUtils.rm_rf folder_name
          end
        end

        it "deletes the oldest folders (by name) till there are the right number of folders" do
          folder_name = index_folder

          expect(File.directory?(folder_name)).to be_falsey

          begin
            num_folders = Cornucopia::Util::ReportBuilder::MAX_OLD_FOLDERS + 1 + rand(4)
            (1..num_folders).to_a.each do |report_index|
              FileUtils.mkdir_p(File.join(folder_name, "#{report_settings[:sub_folder]}_#{report_index}"))
            end

            send(report_settings[:report]).delete_old_folders

            (1..num_folders - Cornucopia::Util::ReportBuilder::MAX_OLD_FOLDERS).to_a.each do |report_index|
              expect(File.directory?(File.join(folder_name, "#{report_settings[:sub_folder]}_#{report_index}"))).to be_falsey
            end
            (num_folders - Cornucopia::Util::ReportBuilder::MAX_OLD_FOLDERS + 1..num_folders).to_a.each do |report_index|
              expect(File.directory?(File.join(folder_name, "#{report_settings[:sub_folder]}_#{report_index}"))).to be_truthy
            end
          ensure
            FileUtils.rm_rf folder_name
          end
        end
      end

      it "returns the #report_base_page_name" do
        expect(send(report_settings[:report]).report_base_page_name).
            to be == File.join(report_folder, "index.html").to_s
      end

      it "returns the #report_test_base_page_name" do
        expect(send(report_settings[:report]).report_test_base_page_name).
            to be == File.join(report_folder, "test_1/index.html").to_s
      end

      it "returns the #index_base_page_name" do
        expect(send(report_settings[:report]).index_base_page_name).to be == File.join(index_folder, "index.html").to_s
      end

      it "returns the #report_contents_page_name" do
        expect(send(report_settings[:report]).report_contents_page_name).
            to be == File.join(report_folder, "report_contents.html").to_s
      end

      it "returns the #report_test_contents_page_name" do
        expect(send(report_settings[:report]).report_test_contents_page_name).
            to be == File.join(report_folder, "test_1/report_contents.html").to_s
      end

      it "returns the #index_contents_page_name" do
        expect(send(report_settings[:report]).index_contents_page_name).
            to be == File.join(index_folder, "report_contents.html").to_s
      end

      describe "#backup_report_folder" do
        it "renames the report folder" do
          test_time = Time.now
          report    = send(report_settings[:report])
          report.instance_variable_set("@report_folder_name", report_folder)
          expect(File).to receive(:ctime).with(File.join(report_folder, "index.html")).and_return(test_time)

          FileUtils.mkdir_p(report_folder)
          Cornucopia::Util::FileAsset.asset("index_base.html").add_file(File.join(report_folder, "index.html"))

          report.backup_report_folder

          expect(File.directory?(report_folder)).to be_falsey
          expect(File.directory?(File.join(index_folder, "#{report_settings[:sub_folder]}_#{test_time.strftime("%Y_%m_%d_%H_%M_%S")}/"))).to be_truthy

          FileUtils.rm_rf(report_folder)
        end

        it "deals with the unlikely event of a conflict" do
          test_time = Time.now
          report    = send(report_settings[:report])
          report.instance_variable_set("@report_folder_name", report_folder)
          expect(File).to receive(:ctime).with(report_folder).and_return(test_time)

          FileUtils.mkdir_p(report_folder)
          FileUtils.mkdir_p(File.join(index_folder, "#{report_settings[:sub_folder]}_#{test_time.strftime("%Y_%m_%d_%H_%M_%S")}/"))
          FileUtils.mkdir_p(File.join(index_folder, "#{report_settings[:sub_folder]}_#{test_time.strftime("%Y_%m_%d_%H_%M_%S")}_alt_1/"))
          FileUtils.mkdir_p(File.join(index_folder, "#{report_settings[:sub_folder]}_#{test_time.strftime("%Y_%m_%d_%H_%M_%S")}_alt_2/"))

          report.backup_report_folder

          expect(File.directory?(report_folder)).to be_falsey
          expect(File.directory?(File.join(index_folder, "#{report_settings[:sub_folder]}_#{test_time.strftime("%Y_%m_%d_%H_%M_%S")}_alt_1/"))).to be_truthy
          expect(File.directory?(File.join(index_folder, "#{report_settings[:sub_folder]}_#{test_time.strftime("%Y_%m_%d_%H_%M_%S")}_alt_2/"))).to be_truthy
          expect(File.directory?(File.join(index_folder, "#{report_settings[:sub_folder]}_#{test_time.strftime("%Y_%m_%d_%H_%M_%S")}_alt_3/"))).to be_truthy

          FileUtils.rm_rf(report_folder)
        end
      end

      describe "#rebuild_index_page" do
        around(:each) do |example|
          expect(File.directory?(Rails.root.join("coverage/"))).to be_falsey

          begin
            example.run
          ensure
            FileUtils.rm_rf Rails.root.join("coverage/")
          end
        end

        it "creates the index file" do
          current_report = send(report_settings[:report])

          current_report.rebuild_index_page

          expect(File.directory?(current_report.index_folder_name)).to be_truthy
          expect(File.exist?(current_report.index_base_page_name)).to be_truthy
          expect(File.exist?(File.join(current_report.index_folder_name, "cornucopia.css"))).to be_truthy
        end

        it "deletes the existing report_contents page" do
          current_report = send(report_settings[:report])

          FileUtils.mkdir_p current_report.index_folder_name
          Cornucopia::Util::FileAsset.asset("cornucopia.css").
              add_file(File.join(current_report.index_folder_name, "report_contents.html"))

          pre_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))

          current_report.rebuild_index_page

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).not_to be == pre_file

          expect(post_file).not_to match /coverage/i
        end

        it "adds coverage if it exists" do
          current_report = send(report_settings[:report])

          FileUtils.mkdir_p Rails.root.join("coverage")
          Cornucopia::Util::FileAsset.asset("cornucopia.css").add_file(Rails.root.join("coverage/index.html"))

          FileUtils.mkdir_p current_report.index_folder_name
          Cornucopia::Util::FileAsset.asset("cornucopia.css").
              add_file(File.join(current_report.index_folder_name, "report_contents.html"))

          pre_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))

          current_report.rebuild_index_page

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).not_to be == pre_file

          expect(post_file).to match /coverage/i
          expect(post_file).to match /coverage\/index.html/i
        end

        it "indexes folders properly" do
          current_report = send(report_settings[:report])
          base_folder    = current_report.index_folder_name

          folder_names       = []
          file_names         = []
          empty_folder_names = []
          folder_names << "cornucopia_report"
          folder_names << "diagnostics_rspec_report"

          rand(3..5).times do
            folder_names << "cornucopia_report_#{Faker::Lorem.word}"
            folder_names << "diagnostics_rspec_report_#{Faker::Lorem.word}"
            file_name = Faker::Lorem.word
            folder_names << file_name
            rand(3..5).times do
              folder_names << "#{file_name}_#{Faker::Lorem.word}"
            end

            file_name = Faker::Lorem.word
            empty_folder_names << file_name
            FileUtils.mkdir_p(File.join(base_folder, file_name))
            Cornucopia::Util::FileAsset.asset("more_info.js").add_file(File.join(base_folder, file_name, "other.html"))

            file_name = "#{Faker::Lorem.word}.html"
            file_names << file_name
            Cornucopia::Util::FileAsset.asset("more_info.js").add_file(File.join(base_folder, file_name))
          end

          folder_names.each do |folder_name|
            FileUtils.mkdir_p(File.join(base_folder, folder_name))
            Cornucopia::Util::FileAsset.asset("more_info.js").add_file(File.join(base_folder, folder_name, "index.html"))
          end

          FileUtils.mkdir_p Rails.root.join("coverage")
          Cornucopia::Util::FileAsset.asset("cornucopia.css").add_file(Rails.root.join("coverage/index.html"))

          FileUtils.mkdir_p current_report.index_folder_name
          Cornucopia::Util::FileAsset.asset("cornucopia.css").
              add_file(File.join(current_report.index_folder_name, "report_contents.html"))

          pre_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))

          current_report.rebuild_index_page

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).not_to be == pre_file

          expect(post_file).to match /\>..\/coverage\</i
          expect(post_file).to match /coverage\/index.html/i

          groups = {}
          folder_names.each do |folder_name|
            if folder_name =~ /cornucopia_report/
              group_name         = "cornucopia_report"
              groups[group_name] ||= []
              groups[group_name] << (post_file =~ /h4\>Feature Tests\</i) if groups[group_name].empty?
            elsif folder_name =~ /diagnostics_rspec_report/
              group_name         = "diagnostics_rspec_report"
              groups[group_name] ||= []
              groups[group_name] << (post_file =~ /h4\>RSPEC Tests\</i) if groups[group_name].empty?
            elsif folder_name =~ /_/
              group_name         = folder_name.split("_")[0]
              groups[group_name] ||= []
              groups[group_name] << (post_file =~ /h4\>#{group_name}\</i) if groups[group_name].empty?
            else
              group_name         = folder_name
              groups[group_name] ||= []
              groups[group_name] << (post_file =~ /h4\>#{group_name}\</i) if groups[group_name].empty?
            end
            groups[group_name] << (post_file =~ /\"#{folder_name}\/index.html\"/i)
            groups[group_name] << (post_file =~ /\>#{folder_name}\<\/a\>/i)
          end

          groups.each do |group_name, group_indexes|
            group_indexes.each do |index_value|
              expect(index_value).to be
              expect(index_value).to be >= 0
            end

            groups.each do |other_group_name, other_group_indexes|
              if other_group_name != group_name
                expect((group_indexes.min < other_group_indexes.min && group_indexes.max < other_group_indexes.min) ||
                           (group_indexes.min > other_group_indexes.max && group_indexes.max > other_group_indexes.max)).
                    to be_truthy
              end
            end
          end

          empty_folder_names.each do |file_name|
            expect(post_file).not_to match /#{file_name}\/other.html/i
          end

          file_names.each do |file_name|
            expect(post_file).not_to match /\/#{file_name}/i
          end
        end
      end

      describe "#rebuild_report_holder_page" do
        it "intializes report files" do
          current_report = send(report_settings[:report])

          expect(current_report).to receive(:initialize_report_files).and_call_original

          current_report.rebuild_report_holder_page

          expect(File.exist?(File.join(report_folder, "index.html"))).to be_truthy
          expect(File.exist?(File.join(report_folder, "report.js"))).to be_truthy
          expect(File.exist?(File.join(report_folder, "cornucopia.css"))).to be_truthy
        end

        it "creates the report folder" do
          current_report = send(report_settings[:report])

          current_report.rebuild_report_holder_page

          expect(File.directory?(report_folder)).to be_truthy
        end

        it "builds the holder file" do
          current_report = send(report_settings[:report])

          test_names  = []
          report_body = "".html_safe

          rand(1..5).times do
            test_name = Faker::Lorem.sentence
            test_names << test_name

            current_report.instance_variable_set(:@test_name, test_name)
            current_report.instance_variable_set(:@test_list_item, nil)

            report_body += current_report.test_list_item
          end

          current_report.instance_variable_set(:@report_body, report_body)

          current_report.rebuild_report_holder_page

          report_page = Capybara::Node::Simple.new(File.read(File.join(report_folder, "index.html")))

          expect(report_page.all(".coruncopia-report-link").length).to eq(test_names.length)
          expect(report_page.find("#report-display-document")).to be

          test_names.each_with_index do |test_name, test_index|
            expect(report_page.all(".coruncopia-report-link")[test_index].text).to eq(test_name)
          end
        end
      end

      describe "#test_list_item" do
        it "is html_safe?" do
          current_report = send(report_settings[:report])

          expect(current_report.test_list_item).to be_html_safe
        end

        it "creates a list item" do
          current_report = send(report_settings[:report])

          list_item = current_report.test_list_item
          expect(list_item).to match /\<a class=\"coruncopia-report-link\"/
          expect(list_item).to match /\<li\>/
          expect(list_item).to match /\<\/li\>/
        end
      end

      describe "#initialize_report_test_files" do
        it "should create the report test folder" do
          current_report = send(report_settings[:report])

          FileUtils.mkdir_p current_report.index_folder_name
          current_report.rebuild_index_page

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).not_to match /\>#{report_settings[:sub_folder]}\</

          current_report.initialize_report_test_files

          test_report_folder = current_report.report_test_folder_name
          expect(File.exist?(test_report_folder)).to be_truthy

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).to match /\>#{report_settings[:sub_folder]}\</

          expect(File.exist?(File.join(test_report_folder, "index.html"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "report_contents.html"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "collapse.gif"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "expand.gif"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "more_info.js"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "cornucopia.css"))).to be_truthy
        end
      end

      describe "#initialize_report_files" do
        it "should create the report folder" do
          current_report = send(report_settings[:report])

          FileUtils.mkdir_p current_report.index_folder_name
          current_report.rebuild_index_page

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).not_to match /\>#{report_settings[:sub_folder]}\</

          current_report.initialize_report_files

          test_report_folder = current_report.report_folder_name
          expect(File.exist?(test_report_folder)).to be_truthy

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).to match /\>#{report_settings[:sub_folder]}\</

          expect(File.exist?(File.join(test_report_folder, "index.html"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "report.js"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "cornucopia.css"))).to be_truthy
        end
      end

      describe "#initialize_basic_report_files" do
        it "should create the report folder" do
          current_report = send(report_settings[:report])

          FileUtils.mkdir_p current_report.index_folder_name
          current_report.rebuild_index_page

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).not_to match /\>#{report_settings[:sub_folder]}\</

          current_report.initialize_basic_report_files

          test_report_folder = current_report.report_folder_name
          expect(File.exist?(test_report_folder)).to be_truthy

          post_file = File.read(File.join(current_report.index_folder_name, "report_contents.html"))
          expect(post_file).to match /\>#{report_settings[:sub_folder]}\</

          expect(File.exist?(File.join(test_report_folder, "index.html"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "report_contents.html"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "collapse.gif"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "expand.gif"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "more_info.js"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "cornucopia.css"))).to be_truthy
        end
      end

      describe "#report_folder_name" do
        it "initializes the system to make room for the folder" do
          current_report = send(report_settings[:report])

          expect(current_report).to receive(:backup_report_folder).and_call_original
          expect(current_report).to receive(:delete_old_folders).and_call_original
          expect(current_report).not_to receive(:initialize_report_files)

          expect(current_report.report_folder_name.to_s).to be == Rails.root.join(report_settings[:index_folder],
                                                                                  report_settings[:sub_folder]).to_s + "/"
          expect(File.exist?(current_report.report_contents_page_name)).to be_falsey
        end
      end

      describe "#report_test_folder_name" do
        it "calls report_folder_name" do
          current_report = send(report_settings[:report])

          expect(current_report).to receive(:report_folder_name).and_call_original

          expect(current_report.report_test_folder_name.to_s).to be == Rails.root.join(report_settings[:index_folder],
                                                                                       report_settings[:sub_folder]).to_s + "/test_1"

          expect(File.exist?(current_report.report_test_contents_page_name)).to be_falsey
        end

        it "gets a different folder inside within_table" do
          current_report = send(report_settings[:report])

          expect(current_report.report_test_folder_name.to_s).to be == Rails.root.join(report_settings[:index_folder],
                                                                                       report_settings[:sub_folder]).to_s + "/test_1"

          current_report.within_test(Faker::Lorem.sentence) do
            expect(current_report.report_test_folder_name.to_s).to be == Rails.root.join(report_settings[:index_folder],
                                                                                         report_settings[:sub_folder]).to_s + "/test_2"
          end
        end
      end

      describe "#open_report_contents_file" do
        it "initializes the report_contents file" do
          current_report = send(report_settings[:report])
          expect(current_report).to receive(:initialize_basic_report_files).and_call_original
          write_contents = Faker::Lorem.paragraphs(number: rand(5..8)).join("\n\n")

          current_report.open_report_contents_file do |writer|
            writer.write(write_contents)
          end

          write_contents = "".html_safe + write_contents

          post_data = File.read(current_report.report_contents_page_name)
          expect(post_data).to match /#{write_contents}/
        end
      end

      describe "#open_report_test_contents_file" do
        it "initializes the report_contents file" do
          current_report = send(report_settings[:report])
          expect(current_report).to receive(:initialize_report_test_files).and_call_original
          write_contents = Faker::Lorem.paragraphs(number: rand(5..8)).join("\n\n")

          current_report.open_report_test_contents_file do |writer|
            writer.write(write_contents)
          end

          write_contents = "".html_safe + write_contents

          post_data = File.read(current_report.report_test_contents_page_name)
          expect(post_data).to match /#{write_contents}/
        end
      end

      describe "#close" do
        it "should create an empty report if nothing was reported" do
          current_report = send(report_settings[:report])
          current_report.close

          post_data = File.read(current_report.report_contents_page_name)
          expect(post_data).to match /No errors to report/i

          expect(Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report")).not_to be
        end

        it "should not call open_report_after_generation if nothing was reported" do
          expect(Cornucopia::Util::Configuration).not_to receive(:open_report_after_generation)

          current_report = send(report_settings[:report])
          current_report.close

          post_data = File.read(current_report.report_contents_page_name)
          expect(post_data).to match /No errors to report/i

          expect(Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report")).not_to be
        end

        it "should not create an empty report if something was reported" do
          current_report = send(report_settings[:report])

          section_name = Faker::Lorem.sentence
          current_report.within_section(section_name) do |report_object|
            expect(report_object.is_a?(Cornucopia::Util::ReportBuilder)).to be_truthy
          end

          current_report.close

          post_data = File.read(current_report.report_test_contents_page_name)
          expect(post_data).not_to match /No errors to report/i

          expect(Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report")).not_to be
        end

        it "should open the report if something was created" do
          current_report = send(report_settings[:report])

          expect(Cornucopia::Util::Configuration).to receive(:open_report_after_generation).and_return(true)
          expect(current_report).to receive(:system).and_return(nil)

          section_name = Faker::Lorem.sentence
          current_report.within_section(section_name) do |report_object|
            expect(report_object.is_a?(Cornucopia::Util::ReportBuilder)).to be_truthy
          end

          current_report.close

          post_data = File.read(current_report.report_test_contents_page_name)
          expect(post_data).not_to match /No errors to report/i

          expect(Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report")).not_to be
        end
      end

      describe "#test_succeeded" do
        it "deletes a sub-test as if nothing failed if it is the only one." do
          current_report = send(report_settings[:report])

          test_folder = nil
          test_file   = nil

          rand(1..3).times do
            current_report.within_test(test_names[0]) do
              current_report.within_section(section_names[0]) do |report_section|
                report_section.within_table do |report_table|
                  report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                end
              end

              test_folder = current_report.report_test_folder_name
              test_file   = current_report.report_base_page_name

              expect(File.exist?(test_file)).to be_truthy
              expect(File.directory?(test_folder)).to be_truthy

              current_report.test_succeeded

              expect(File.exist?(test_file)).to be_falsey
              expect(File.directory?(test_folder)).to be_falsey
            end
          end

          current_report.close

          expect(File.exist?(test_file)).to be_truthy
          expect(File.directory?(test_folder)).to be_falsey

          read_file = File.read(current_report.report_contents_page_name)
          expect(read_file).not_to match /#{test_names[0]}/
          expect(read_file).to match /No Errors to report/
        end

        it "deletes a sub-test as if it doesn't exist" do
          current_report = send(report_settings[:report])

          current_report.within_test(test_names[0]) do
            current_report.within_section(section_names[0]) do |report_section|
              report_section.within_table do |report_table|
                report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
              end
            end
          end

          test_folder = nil
          test_file   = nil

          rand(1..3).times do
            current_report.within_test(test_names[1]) do
              current_report.within_section(section_names[1]) do |report_section|
                report_section.within_table do |report_table|
                  report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                end
              end

              test_folder = current_report.report_test_folder_name
              test_file   = current_report.report_base_page_name

              expect(File.exist?(test_file)).to be_truthy
              expect(File.directory?(test_folder)).to be_truthy

              current_report.test_succeeded

              expect(File.exist?(test_file)).to be_truthy
              expect(File.directory?(test_folder)).to be_falsey
            end
          end

          current_report.close

          expect(File.exist?(test_file)).to be_truthy
          expect(File.directory?(test_folder)).to be_falsey

          read_file = File.read(current_report.report_base_page_name)
          expect(read_file).to match /#{test_names[0]}/
          expect(read_file).not_to match /#{test_names[1]}/
        end
      end

      describe "#within_test" do
        it "starts a test with a specific name" do
          backup = Cornucopia::Util::Configuration.backup_logs_on_failure
          begin
            Cornucopia::Util::Configuration.backup_logs_on_failure = true
            current_report = send(report_settings[:report])

            current_report.within_test(test_names[0]) do
              current_report.within_section(section_names[0]) do |report_section|
                report_section.within_table do |report_table|
                  report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                end
              end
            end

            current_report.close

            report_page = Capybara::Node::Simple.new(File.read(current_report.report_base_page_name))

            expect(report_page.all(".coruncopia-report-link").length).to eq 2
            expect(report_page.all(".coruncopia-report-link")[0].text).to eq test_names[0]
            expect(report_page.all(".coruncopia-report-link")[0]["href"]).to eq "test_1/index.html"
            expect(report_page.all(".coruncopia-report-link")[1].text).to eq "test.log"
            expect(report_page.all(".coruncopia-report-link")[1]["href"]).to eq "log_files/test.log"
          ensure
            Cornucopia::Util::Configuration.backup_logs_on_failure = backup
          end
        end

        it "doesn't output anything if nothing is written to a section or table" do
          current_report = send(report_settings[:report])

          current_report.within_test(test_names[0]) do
          end

          current_report.close

          report_page = Capybara::Node::Simple.new(File.read(current_report.report_contents_page_name))

          expect(report_page.all(".cornucopia-no-errors").length).to eq 1
          expect(report_page.all(".cornucopia-no-errors")[0].text).to eq "No Errors to report"
        end

        it "outputs multiple tests" do
          current_report = send(report_settings[:report])

          test_names.each_with_index do |test_name, test_index|
            current_report.within_test(test_name) do
              current_report.within_section(section_names[test_index]) do |report_section|
                report_section.within_table do |report_table|
                  report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                end
              end
            end
          end

          current_report.close

          report_page = Capybara::Node::Simple.new(File.read(current_report.report_base_page_name))

          expect(report_page.all(".coruncopia-report-link").length).to eq test_names.length

          test_names.each_with_index do |test_name, test_index|
            expect(report_page.all(".coruncopia-report-link")[test_index].text).to eq test_name
            expect(report_page.all(".coruncopia-report-link")[test_index]["href"]).to eq "test_#{test_index + 1}/index.html"
          end
          # expect(report_page.all(".coruncopia-report-link")[-1].text).to eq "test.log"
          # expect(report_page.all(".coruncopia-report-link")[-1]["href"]).to eq "log_files/test.log"
        end

        it "handles a test within a test as an independent test" do
          current_report = send(report_settings[:report])

          current_report.within_test(test_names[0]) do
            current_report.within_section(section_names[0]) do |report_section|
              report_section.within_table do |report_table|
                report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                current_report.within_test(test_names[1]) do
                  current_report.within_section(section_names[1]) do |report_section|
                    report_section.within_table do |report_table|
                      report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                    end
                  end
                end
              end
            end
          end

          current_report.close

          report_page = Capybara::Node::Simple.new(File.read(current_report.report_base_page_name))

          expect(report_page.all(".coruncopia-report-link").length).to eq 2
          expect(report_page.all(".coruncopia-report-link")[0].text).to eq test_names[0]
          expect(report_page.all(".coruncopia-report-link")[0]["href"]).to eq "test_1/index.html"
          expect(report_page.all(".coruncopia-report-link")[1].text).to eq test_names[1]
          expect(report_page.all(".coruncopia-report-link")[1]["href"]).to eq "test_2/index.html"
          # expect(report_page.all(".coruncopia-report-link")[2].text).to eq "test.log"
          # expect(report_page.all(".coruncopia-report-link")[2]["href"]).to eq "log_files/test.log"

          report_page = Capybara::Node::Simple.new(File.read(File.join(current_report.report_folder_name, "test_1/report_contents.html")))
          expect(report_page.all(".cornucopia-section-label").length).to eq 1
          expect(report_page.all(".cornucopia-section-label")[0].text).to eq section_names[0]

          report_page = Capybara::Node::Simple.new(File.read(File.join(current_report.report_folder_name, "test_2/report_contents.html")))
          expect(report_page.all(".cornucopia-section-label").length).to eq 1
          expect(report_page.all(".cornucopia-section-label")[0].text).to eq section_names[1]
        end

        it "restores to the old test if a test within a test" do
          current_report = send(report_settings[:report])

          current_report.within_test(test_names[0]) do
            current_report.within_section(section_names[0]) do |report_section|
              report_section.within_table do |report_table|
                report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                current_report.within_test(test_names[1]) do
                  current_report.within_section(section_names[1]) do |report_section|
                    report_section.within_table do |report_table|
                      report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                    end
                  end
                end
              end
            end

            current_report.within_section(section_names[2]) do |report_section|
              report_section.within_table do |report_table|
                report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
              end
            end
          end

          current_report.close

          report_page = Capybara::Node::Simple.new(File.read(current_report.report_base_page_name))

          expect(report_page.all(".coruncopia-report-link").length).to eq 2
          expect(report_page.all(".coruncopia-report-link")[0].text).to eq test_names[0]
          expect(report_page.all(".coruncopia-report-link")[0]["href"]).to eq "test_1/index.html"
          expect(report_page.all(".coruncopia-report-link")[1].text).to eq test_names[1]
          expect(report_page.all(".coruncopia-report-link")[1]["href"]).to eq "test_2/index.html"
          # expect(report_page.all(".coruncopia-report-link")[2].text).to eq "test.log"
          # expect(report_page.all(".coruncopia-report-link")[2]["href"]).to eq "log_files/test.log"

          report_page = Capybara::Node::Simple.new(File.read(File.join(current_report.report_folder_name, "test_1/report_contents.html")))
          expect(report_page.all(".cornucopia-section-label").length).to eq 2
          expect(report_page.all(".cornucopia-section-label")[0].text).to eq section_names[0]
          expect(report_page.all(".cornucopia-section-label")[1].text).to eq section_names[2]
        end

        it "numbers tests based on the tests that actually output something" do
          current_report = send(report_settings[:report])

          test_names.each_with_index do |test_name, test_index|
            if test_index == 0 || test_index == test_names.length - 1
              current_report.within_test(test_name) do
                current_report.within_section(section_names[test_index]) do |report_section|
                  report_section.within_table do |report_table|
                    report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
                  end
                end
              end
            end
          end

          current_report.close

          report_page = Capybara::Node::Simple.new(File.read(current_report.report_base_page_name))

          expect(report_page.all(".coruncopia-report-link").length).to eq 2

          expect(report_page.all(".coruncopia-report-link")[0].text).to eq test_names[0]
          expect(report_page.all(".coruncopia-report-link")[0]["href"]).to eq "test_1/index.html"
          expect(report_page.all(".coruncopia-report-link")[1].text).to eq test_names[-1]
          expect(report_page.all(".coruncopia-report-link")[1]["href"]).to eq "test_2/index.html"
          # expect(report_page.all(".coruncopia-report-link")[2].text).to eq "test.log"
          # expect(report_page.all(".coruncopia-report-link")[2]["href"]).to eq "log_files/test.log"
        end
      end

      describe "#within_section" do
        it "should output passed in text to the report file" do
          current_report = send(report_settings[:report])

          expect(current_report).to receive(:initialize_report_files).at_least(1).and_call_original

          section_name = Faker::Lorem.sentence
          current_report.within_section(section_name) do |report_object|
            expect(report_object.is_a?(Cornucopia::Util::ReportBuilder)).to be_truthy
          end

          post_data = File.read(current_report.report_test_contents_page_name)
          expect(post_data).to match /\>#{section_name}\</i
        end

        it "should always close the section if an exception is thrown" do
          current_report = send(report_settings[:report])

          expect(current_report).to receive(:initialize_report_files).at_least(1).and_call_original

          expect do
            section_name = Faker::Lorem.sentence
            current_report.within_section(section_name) do |report_object|
              expect(report_object.is_a?(Cornucopia::Util::ReportBuilder)).to be_truthy
              raise Exception.new("This is an exception")
            end
          end.to raise_exception

          post_data = File.read(current_report.report_test_contents_page_name)
          expect(post_data[-1 * "\<\/div\>\n<div class=\"cornucopia-end-section\" />\n".length..-1]).to be == "\<\/div\>\n<div class=\"cornucopia-end-section\" />\n"
        end
      end

      describe "#within_table" do
        it "should output the table within a section" do
          current_report = send(report_settings[:report])

          section_name = "".html_safe + Faker::Lorem.sentence
          table_label  = "".html_safe + Faker::Lorem.sentence
          table_data   = "".html_safe + Faker::Lorem.paragraphs.join("\n")

          current_report.within_section(section_name) do |report_object|
            report_object.within_table do |report_table|
              report_table.write_stats(table_label, table_data)
            end
          end

          post_data = File.read(current_report.report_test_contents_page_name)
          expect(post_data[-1 * "\<\/div\>\n<div class=\"cornucopia-end-section\" />\n".length..-1]).to be == "\<\/div\>\n<div class=\"cornucopia-end-section\" />\n"
          expect(post_data).to match /\>\n#{table_label}\n\</
          expect(post_data).to match /\>#{table_data}\</
        end

        it "should output the table within a section even if an exception is thrown" do
          current_report = send(report_settings[:report])

          section_name = "".html_safe + Faker::Lorem.sentence
          table_label  = "".html_safe + Faker::Lorem.sentence
          table_data   = "".html_safe + Faker::Lorem.paragraphs.join("\n")

          expect do
            current_report.within_section(section_name) do |report_object|
              report_object.within_table do |report_table|
                report_table.write_stats(table_label, table_data)
                raise Exception.new("This is an exception")
              end
            end
          end.to raise_exception

          post_data = File.read(current_report.report_test_contents_page_name)
          expect(post_data[-1 * "\<\/div\>\n<div class=\"cornucopia-end-section\" />\n".length..-1]).to be == "\<\/div\>\n<div class=\"cornucopia-end-section\" />\n"
          expect(post_data).to match /\>\n#{table_label}\n\</
          expect(post_data).to match /\>#{table_data}\</
          expect(post_data).to match /This is an exception/
        end

        # noinspection RubyScope
        it "outputs the table in another table, and doesn't write anything" do
          current_report = send(report_settings[:report])
          mid_data       = ""

          current_report.within_section("Section") do |report_object|
            # noinspection RubyScope
            report_object.within_table do |report_table|
              report_object.within_table(report_table: report_table) do |sub_table|
                sub_table.write_stats "stat", "value"
              end

              mid_data = File.read(current_report.report_test_contents_page_name)
            end
          end

          current_report.close

          post_data = File.read(current_report.report_test_contents_page_name)

          expect(post_data).to match /\>\nstat\n\</
          expect(mid_data).not_to match /\>\nstat\n\</
        end
      end

      describe "#unique_folder_name" do
        it "returns the folder if there is no folder with that name" do
          current_report     = send(report_settings[:report])
          test_report_folder = current_report.report_folder_name

          new_folder = Faker::Lorem.word

          expect(current_report.unique_folder_name(new_folder)).to be == new_folder
        end

        it "returns a uniqe folder if there is a folder with that name" do
          current_report     = send(report_settings[:report])
          test_report_folder = current_report.report_test_folder_name

          new_folder  = Faker::Lorem.word
          num_folders = rand(5..10)

          FileUtils.mkdir_p File.join(test_report_folder, new_folder)
          num_folders.times do |folder_number|
            FileUtils.mkdir_p File.join(test_report_folder, "#{new_folder}_#{folder_number}")
          end

          expect(current_report.unique_folder_name(new_folder)).to be == "#{new_folder}_#{num_folders}"
        end
      end

      describe "#unique_file_name" do
        it "creates a unique file name if there are no files" do
          current_report     = send(report_settings[:report])
          test_report_folder = current_report.report_folder_name

          prefix  = Faker::Lorem.word
          postfix = Faker::Lorem.word

          expect(current_report.unique_file_name("#{prefix}.#{postfix}")).to be == "#{prefix}.#{postfix}"
        end

        it "creates a unique file name if there are some files already" do
          current_report     = send(report_settings[:report])
          test_report_folder = current_report.report_test_folder_name

          prefix    = Faker::Lorem.word
          postfix   = Faker::Lorem.word
          num_files = rand(3..5)

          FileUtils.mkdir_p test_report_folder
          Cornucopia::Util::FileAsset.asset("cornucopia.css").
              add_file(File.join(test_report_folder, "#{prefix}.#{postfix}"))
          (1..num_files).to_a.each do |file_index|
            Cornucopia::Util::FileAsset.asset("cornucopia.css").
                add_file(File.join(test_report_folder, "#{prefix}_#{file_index}.#{postfix}"))
          end

          expect(current_report.unique_file_name("#{prefix}.#{postfix}")).to be == "#{prefix}_#{num_files + 1}.#{postfix}"
        end
      end

      describe "#image_link" do
        it "moves the image file and creates an image element" do
          current_report     = send(report_settings[:report])
          test_report_folder = current_report.report_test_folder_name

          prefix  = Faker::Lorem.word
          postfix = Faker::Lorem.word

          FileUtils.mkdir_p test_report_folder
          Cornucopia::Util::FileAsset.asset("cornucopia.css").
              add_file(File.join(test_report_folder, "#{prefix}.#{postfix}"))

          expect(File.exist?(File.join(test_report_folder, "#{prefix}.#{postfix}"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "#{prefix}_1.#{postfix}"))).to be_falsey

          image_link = current_report.image_link(File.join(test_report_folder, "#{prefix}.#{postfix}"))

          expect(File.exist?(File.join(test_report_folder, "#{prefix}.#{postfix}"))).to be_falsey
          expect(File.exist?(File.join(test_report_folder, "#{prefix}_1.#{postfix}"))).to be_truthy

          expect(image_link).to be_html_safe
          expect(image_link).to match /^\<img/i
          expect(image_link).to match /src=\".\/#{prefix}_1.#{postfix}\"/i
        end
      end

      describe "#page_frame" do
        it "dumps the html to a file, and returns an iframe element" do
          current_report     = send(report_settings[:report])
          test_report_folder = current_report.report_test_folder_name
          source_html        = "<html>\n<body>\nThis is some &amp; awesome text</body>\n</html>"

          FileUtils.mkdir_p test_report_folder
          Cornucopia::Util::FileAsset.asset("cornucopia.css").add_file(File.join(test_report_folder, "page_dump.html"))

          expect(File.exist?(File.join(test_report_folder, "page_dump.html"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "page_dump_1.html"))).to be_falsey

          page_link = current_report.page_frame(source_html)

          expect(File.exist?(File.join(test_report_folder, "page_dump.html"))).to be_truthy
          expect(File.exist?(File.join(test_report_folder, "page_dump_1.html"))).to be_truthy

          expect(page_link).to be_html_safe
          expect(page_link).to match /\<iframe/i
          expect(page_link).to match /src=\"page_dump_1.html\"/i
          expect(File.read(File.join(test_report_folder, "page_dump_1.html"))).to be == source_html
        end
      end

      describe "#page_text" do
        it "outputs a textarea for page" do
          current_report = send(report_settings[:report])

          text_area_value = current_report.page_text("</textarea>")

          expect(text_area_value).to match /\&lt\;\/textarea\&gt\;/
          expect(text_area_value).to match /\<textarea/
          expect(text_area_value).to match /\<\/textarea\>/
        end
      end
    end
  end

  it "outputs multiple tests" do
    test_names.each_with_index do |test_name, test_index|
      current_report.within_test(test_name) do
        current_report.within_section(section_names[test_index]) do |report_section|
          report_section.within_table do |report_table|
            report_table.write_stats(Faker::Lorem.word, Faker::Lorem.sentence)
          end
        end
      end
    end

    current_report.close
    current_report.instance_variable_set(:@test_number, 0)

    report_page  = Capybara::Node::Simple.new(File.read(current_report.report_test_contents_page_name))
    report_table = CornucopiaReportApp.cornucopia_report_test_contents_page

    report_table.owner_node = report_page

    expect(report_table.errors.count).to eq 1
    section = report_table.errors[0]

    expect(section.find("p").text).to eq section_names[0]
    expect(section.name.text).to eq section_names[0]
  end
end
