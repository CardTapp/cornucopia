require "spec_helper"
require ::File.expand_path("../../../lib/cornucopia/util/configuration", File.dirname(__FILE__))

describe "Cornucopia::Util::Configuration" do
  it "has a default seed value" do
    expect(Cornucopia::Util::Configuration.seed).not_to be
  end

  it "can set the seed value" do
    begin
      seed_value = rand(0..999999999999999999999999999)

      Cornucopia::Util::Configuration.seed = seed_value

      expect(Cornucopia::Util::Configuration.seed).to be == seed_value
    ensure
      Cornucopia::Util::Configuration.seed = nil
    end
  end

  describe "log files" do
    it "grabs logs by default" do
      expect(Cornucopia::Util::Configuration.grab_logs).to be_truthy
    end

    it "can set the seed value" do
      begin
        Cornucopia::Util::Configuration.grab_logs = false

        expect(Cornucopia::Util::Configuration.grab_logs).to be_falsey
      ensure
        Cornucopia::Util::Configuration.grab_logs = true
      end
    end

    it "has no custom files by default" do
      expect(Cornucopia::Util::Configuration.user_log_files).to be == {}
    end

    it "can add custom user log files" do
      begin
        num_lines   = rand(0..500)
        some_config = Faker::Lorem.sentence

        Cornucopia::Util::Configuration.add_log_file("test_log_file.log", { num_lines: num_lines, some_config: some_config })

        expect(Cornucopia::Util::Configuration.user_log_files).to be == {
                                                                      "test_log_file.log" => { num_lines: num_lines, some_config: some_config }
                                                                  }
      ensure
        Cornucopia::Util::Configuration.remove_log_file("test_log_file.log")
      end
    end

    it "can remove custom user log files" do
      begin
        num_lines   = rand(0..500)
        some_config = Faker::Lorem.sentence

        Cornucopia::Util::Configuration.add_log_file("test_log_file.log", { num_lines: num_lines, some_config: some_config })

        expect(Cornucopia::Util::Configuration.user_log_files).to be == {
                                                                      "test_log_file.log" => { num_lines: num_lines, some_config: some_config }
                                                                  }

        Cornucopia::Util::Configuration.remove_log_file("test_log_file.log")

        expect(Cornucopia::Util::Configuration.user_log_files).to be == {}
      ensure
        Cornucopia::Util::Configuration.remove_log_file("test_log_file.log")
      end
    end

    it "can change settings for custom user log files" do
      begin
        num_lines   = rand(0..500)
        some_config = Faker::Lorem.sentence

        Cornucopia::Util::Configuration.add_log_file("test_log_file.log", { num_lines: num_lines, some_config: some_config })

        expect(Cornucopia::Util::Configuration.user_log_files).to be == {
                                                                      "test_log_file.log" => { num_lines: num_lines, some_config: some_config }
                                                                  }

        num_lines = rand(501..1_000)

        Cornucopia::Util::Configuration.add_log_file("test_log_file.log", { num_lines: num_lines })

        expect(Cornucopia::Util::Configuration.user_log_files).to be == {
                                                                      "test_log_file.log" => { num_lines: num_lines, some_config: some_config }
                                                                  }
      ensure
        Cornucopia::Util::Configuration.remove_log_file("test_log_file.log")
      end
    end

    describe "#num_lines" do
      it "returns the default number of lines to fetch" do
        expect(Cornucopia::Util::Configuration.num_lines).to be == 500
      end

      it "returns the default number of lines to fetch it it isn't set for a fake file" do
        expect(Cornucopia::Util::Configuration.num_lines("fake_file.log")).to be == 500
      end

      it "returns the default number of lines to fetch it it isn't set for a file" do
        begin
          Cornucopia::Util::Configuration.add_log_file("test_log_file.log", { some_config: "nothing" })

          expect(Cornucopia::Util::Configuration.num_lines("test_log_file.log")).to be == 500
        ensure
          Cornucopia::Util::Configuration.remove_log_file("test_log_file.log")
        end
      end

      it "returns the number of lines for a specific file" do
        begin
          num_lines   = rand(0..500)
          some_config = Faker::Lorem.sentence

          Cornucopia::Util::Configuration.add_log_file("test_log_file.log", { num_lines: num_lines, some_config: some_config })

          expect(Cornucopia::Util::Configuration.num_lines("test_log_file.log")).to be == num_lines
        ensure
          Cornucopia::Util::Configuration.remove_log_file("test_log_file.log")
        end
      end

      it "can change the defualt number of lines" do
        begin
          new_default = rand(0..10_000_000)

          Cornucopia::Util::Configuration.default_num_lines = new_default

          expect(Cornucopia::Util::Configuration.num_lines).to be == new_default
          expect(Cornucopia::Util::Configuration.num_lines("fake_file.log")).to be == new_default
        ensure
          Cornucopia::Util::Configuration.default_num_lines = 500
        end
      end
    end
  end

  describe "configured_reports" do
    [:rspec, :cucumber, :spinach, :capybara_page_diagnostics].each do |report_type|
      it "has a #{report_type} report" do
        expect(Cornucopia::Util::Configuration.report_configuration(report_type)).to be
      end
    end
  end

  describe "#print_timeout_min" do
    it "#can read the default" do
      expect(Cornucopia::Util::Configuration.print_timeout_min).to be == 10
    end

    it "#can set the value" do
      begin
        rand_value                                        = rand(20..100)
        Cornucopia::Util::Configuration.print_timeout_min = rand_value

        expect(Cornucopia::Util::Configuration.print_timeout_min).to be == rand_value
      ensure
        Cornucopia::Util::Configuration.print_timeout_min = 10
      end
    end
  end

  describe "#selenium_cache_retry_count" do
    it "#can read the default" do
      expect(Cornucopia::Util::Configuration.selenium_cache_retry_count).to be == 5
    end

    it "#can set the value" do
      begin
        rand_value                                                 = rand(20..100)
        Cornucopia::Util::Configuration.selenium_cache_retry_count = rand_value

        expect(Cornucopia::Util::Configuration.selenium_cache_retry_count).to be == rand_value
      ensure
        Cornucopia::Util::Configuration.selenium_cache_retry_count = 5
      end
    end
  end

  describe "#analyze_find_exceptions" do
    it "#can read the default" do
      expect(Cornucopia::Util::Configuration.analyze_find_exceptions).to be_truthy
    end

    it "#can set the value" do
      begin
        Cornucopia::Util::Configuration.analyze_find_exceptions = false

        expect(Cornucopia::Util::Configuration.analyze_find_exceptions).to be_falsy
      ensure
        Cornucopia::Util::Configuration.analyze_find_exceptions = true
      end
    end
  end

  describe "#retry_with_found" do
    it "#can read the default" do
      expect(Cornucopia::Util::Configuration.retry_with_found).to be_falsy
    end

    it "#can set the value" do
      begin
        Cornucopia::Util::Configuration.retry_with_found = true

        expect(Cornucopia::Util::Configuration.retry_with_found).to be_truthy
      ensure
        Cornucopia::Util::Configuration.retry_with_found = false
      end
    end
  end

  describe "#auto_open_report_after_generation" do
    after(:each) do
      Cornucopia::Util::Configuration.class_variable_get(:@@configurations).open_report_settings = { default: false }
    end

    it "sets the default value if unspecified" do
      Cornucopia::Util::Configuration.auto_open_report_after_generation(true)
      expect(Cornucopia::Util::Configuration.class_variable_get(:@@configurations).open_report_settings)
          .to eq({ default: true })
    end

    it "sets the value of a specific report" do
      Cornucopia::Util::Configuration.auto_open_report_after_generation(true, "fred")
      expect(Cornucopia::Util::Configuration.class_variable_get(:@@configurations).open_report_settings).
          to eq({ default: false, "fred" => true })
    end
  end

  describe "#open_report_after_generation" do
  end

  # describe "#alternate_retry" do
  #   it "#can read the default" do
  #     expect(Cornucopia::Util::Configuration.alternate_retry).to be_falsy
  #   end
  #
  #   it "#can set the value" do
  #     begin
  #       Cornucopia::Util::Configuration.alternate_retry = true
  #
  #       expect(Cornucopia::Util::Configuration.alternate_retry).to be_truthy
  #     ensure
  #       Cornucopia::Util::Configuration.alternate_retry = false
  #     end
  #   end
  # end
end