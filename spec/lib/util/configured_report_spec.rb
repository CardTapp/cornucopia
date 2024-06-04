# frozen_string_literal: true

require "rails_helper"
require ::File.expand_path("../../../lib/cornucopia/util/configured_report", File.dirname(__FILE__))

class SubTestClass
  @sub_basic_variable
  @sub_overridden_variable

  def initialize
    @sub_basic_variable      = "sub basic variable"
    @sub_overridden_variable = "sub overridden variable"
  end

  def sub_overridden_variable
    "sub processed variable"
  end
end

class TestPoint < Struct.new(:x, :y)
end

class TestClass
  @basic_variable
  @overridden_variable
  @sub_class_variable
  @hash_variable
  @nil_variable
  @struct_variable

  def initialize
    @basic_variable      = "basic variable"
    @overridden_variable = "overridden variable"
    @sub_class_variable  = SubTestClass.new
    @hash_variable       = {
        key_1:        "value",
        "another key" => "another value"
    }
    @array_variable      = [1, "b", :fred_sym]
    @nil_variable        = nil
    @struct_variable     = TestPoint.new(rand(0..1_000), rand(0..1_000))
  end

  def overridden_variable
    "processed variable"
  end
end

describe Cornucopia::Util::ConfiguredReport do
  let(:simple_report) { Cornucopia::Util::ConfiguredReport.new }
  let(:test) { TestClass.new }

  around(:each) do |example|
    expect(File.directory?(Rails.root.join("cornucopia_report/"))).to be_falsey

    begin
      example.run
    ensure
      Cornucopia::Util::ReportBuilder.current_report.close if (Cornucopia::Util::ReportBuilder.class_variable_get("@@current_report"))

      FileUtils.rm_rf Rails.root.join("cornucopia_report/")
    end
  end

  describe "#get_instance_variable" do
    it "gets the instance variable" do
      expect(simple_report.get_instance_variable(test, :@basic_variable, "basic_variable")).to be == "basic variable"
    end

    it "gets the getter function if there is one" do
      expect(simple_report.get_instance_variable(test, :@overridden_variable, "overridden_variable")).
          to be == "processed variable"
    end
  end

  describe "#split_full_field_symbol" do
    it "splits a list by __" do
      expect(simple_report.split_full_field_symbol(:var1__var2__var3)).to be == [:var1, :var2, :var3]
    end

    it "splits a list by __, and can handle varaibles with _" do
      expect(simple_report.split_full_field_symbol(:var1___var2__var3)).to be == [:var1, :_var2, :var3]
    end

    it "splits a list by __, and can handle varaibles with __" do
      expect(simple_report.split_full_field_symbol(:var1____var2__var3)).to be == [:var1, :__var2, :var3]
    end

    it "splits a list by __, and can handle varaibles with ____" do
      expect(simple_report.split_full_field_symbol(:var1______var2__var3)).to be == [:var1, :____var2, :var3]
    end

    it "can handle arbitrary _ and depths" do
      results = []

      rand(5..20).times do |index|
        sub_symbol = Faker::Lorem.word
        if rand(5) == 0 || index == 0
          sub_symbol = (("_" * rand(1..10)) + sub_symbol)
        end

        results << sub_symbol.to_sym
      end

      expect(simple_report.split_full_field_symbol(results.join("__").to_sym)).to be == results
    end
  end

  describe "#split_field_symbols" do
    it "returns [] when passed nil" do
      expect(simple_report.split_field_symbols(nil)).to be == []
    end

    it "calls #split_full_field_symbol for every element in an array" do
      results = []
      source  = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end
        results << { report_element: sub_results }
        source << sub_results.join("__")
      end

      expect(simple_report.split_field_symbols(source)).to be == results
    end
  end

  describe "#find_variable_in_set" do
    it "finds variables that are in the set" do
      results = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << { report_element: sub_results }
      end

      set_test = results.sample
      expect(simple_report.find_variable_in_set(results, set_test[:report_element][0..-2], set_test[:report_element][-1])).
          to be == set_test
    end

    it "does not find variables that are only partial matches" do
      results = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << { report_element: sub_results }
      end

      set_test = results.sample[:report_element]
      len      = rand(0..set_test.length - 3)

      expect(simple_report.find_variable_in_set(results, set_test[0..len], set_test[len + 1])).to be_falsey
    end

    it "does not find variables that are not in the set" do
      results = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << { report_element: sub_results }
      end

      # There is a slim, but statistically unlikely chance that
      # there will be another item in results with the first set
      # of words identical, except for the last word.
      # I'll take this risk.
      set_test = results.sample[:report_element]
      begin
        test_var = Faker::Lorem.word
      end while test_var == set_test[-1]

      expect(simple_report.find_variable_in_set(results, set_test[0..-2], test_var)).to be_falsey
    end

    it "is used by #expand_variable_inline?" do
      results = []
      source  = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << sub_results
        source << sub_results.join("__")
      end

      set_test                           = results.sample
      simple_report.expand_inline_fields = source
      expect(simple_report.expand_variable_inline?(set_test[0..-2], set_test[-1])).to be_truthy
    end

    it "is used by #expand_variable?" do
      results = []
      source  = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << sub_results
        source << sub_results.join("__")
      end

      set_test                           = results.sample
      simple_report.expand_inline_fields = source
      expect(simple_report.expand_variable?(set_test[0..-2], set_test[-1])).to be_truthy
    end

    it "is used by #expand_variable?" do
      results = []
      source  = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << sub_results
        source << sub_results.join("__")
      end

      set_test                    = results.sample
      simple_report.expand_fields = source
      expect(simple_report.expand_variable?(set_test[0..-2], set_test[-1])).to be_truthy
    end

    it "is used by #exclude_variable?" do
      results = []
      source  = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << sub_results
        source << sub_results.join("__")
      end

      set_test                     = results.sample
      simple_report.exclude_fields = source
      expect(simple_report.exclude_variable?(set_test[0..-2], set_test[-1])).to be_truthy
    end

    it "supports wildcards as the last field to match" do
      results = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << { report_element: sub_results }
      end

      # There is a slim, but statistically unlikely chance that
      # there will be another item in results with the first set
      # of words identical, except for the last word.
      # I'll take this risk.
      rand_pos                               = rand(0..results.length - 1)
      set_test                               = results[rand_pos][:report_element].clone
      results[rand_pos][:report_element][-1] = "*".to_sym

      expect(simple_report.find_variable_in_set(results, set_test[0..-2], set_test[-1])).to be_truthy
    end

    it "supports wildcards as any field to match" do
      results = []

      rand(5..20).times do
        sub_results = []
        rand(5..20).times do
          sub_symbol = Faker::Lorem.word
          if rand(5) == 0
            sub_symbol = (("_" * rand(1..10)) + sub_symbol)
          end

          sub_results << sub_symbol.to_sym
        end

        results << { report_element: sub_results }
      end

      # There is a slim, but statistically unlikely chance that
      # there will be another item in results with the first set
      # of words identical, except for the last word.
      # I'll take this risk.

      rand_pos = rand(0..results.length - 1)
      set_test = results[rand_pos][:report_element].clone

      results[rand_pos][:report_element][rand(0..results[rand_pos][:report_element].length - 1)] = "*".to_sym

      expect(simple_report.find_variable_in_set(results, set_test[0..-2], set_test[-1])).to be_truthy
    end
  end

  describe "#export_field_record" do
    it "doesn't crash if there is an exception" do
      string_val = "string"

      Cornucopia::Util::ReportTable.new do |report_table|
        allow(report_table).to receive(:write_stats).and_call_original
        expect(report_table).to receive(:write_stats).with(:string_val, "string", {}).and_raise(Exception, "This is an error")

        simple_report.export_field_record({ report_element: [:string_val] },
                                          string_val,
                                          :string_val,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).to match /Configured Report Error/
        expect(report_table.full_table).to match /This is an error/
      end
    end

    it "takes a passed in parent" do
      string_val = "string"

      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with(:string_val, "string", {})

        simple_report.export_field_record({ report_element: [:string_val] },
                                          string_val,
                                          :string_val,
                                          report_table,
                                          0,
                                          report_object_set: true)
      end
    end

    it "takes a parent that is an instance variable" do
      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with(:overridden_variable, "processed variable", {})

        simple_report.export_field_record({ report_element: [:test, :overridden_variable] },
                                          test,
                                          :test,
                                          report_table,
                                          1)
      end
    end

    it "deals with the variable we're fetching being the instance variable" do
      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with(:overridden_variable, "processed variable", {})

        simple_report.export_field_record({ report_element: [:test, :overridden_variable] },
                                          test,
                                          :test,
                                          report_table,
                                          1)
      end
    end

    it "outputs the variable .to_s" do
      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with(:overridden_variable, "processed variable", {})

        simple_report.export_field_record({ report_element: [:test, :overridden_variable, :to_s] },
                                          test,
                                          :test,
                                          report_table,
                                          1)
      end
    end

    it "finds the parent object if it is a member function" do
      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with(:overridden_variable, "processed variable", {})

        simple_report.export_field_record({ report_element: [:test, :overridden_variable] },
                                          test,
                                          :test,
                                          report_table,
                                          1)
      end
    end

    it "finds the parent object if it is accessible via []" do
      hash = { my_hash_key: "hash key" }
      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with(:my_hash_key, "hash key", {})

        simple_report.export_field_record({ report_element: [:hash, :my_hash_key] },
                                          hash,
                                          :hash,
                                          report_table,
                                          1)
      end
    end

    it "finds the parent object if it is an array index expanded" do
      array = [1, 2, 3]

      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with("0".to_sym, 1, {})

        simple_report.export_field_record({ report_element: [:array, 0.to_s.to_sym] },
                                          array,
                                          :array,
                                          report_table,
                                          1,
                                          { expanded_field: true })
      end
    end

    it "finds the parent object if it is an array index expanded inline and puts the right value out" do
      array                              = [1, 2, 3]
      simple_report.expand_inline_fields = [:array]

      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with("array[0]", 1, {})

        simple_report.export_field_record({ report_element: [:array, 0.to_s.to_sym] },
                                          array,
                                          :array,
                                          report_table,
                                          1)
      end
    end

    it "finds the parent object if it is an array index exported directly" do
      array = [1, 2, 3]

      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with("array[0]", 1, {})

        simple_report.export_field_record({ report_element: [:array, 0.to_s.to_sym] },
                                          array,
                                          :array,
                                          report_table,
                                          1)
      end
    end

    it "outputs an error if it cannot find the parent object" do
      Cornucopia::Util::ReportTable.new do |report_table|
        expect(report_table).to receive(:write_stats).with("ERROR", "Could not identify field: hash__my_hash_key while exporting hash__my_hash_key")

        simple_report.export_field_record({ report_element: [:hash, :my_hash_key] },
                                          test,
                                          :hash,
                                          report_table,
                                          1)
      end
    end

    it "expands leaf nodes" do
      report_result_table = nil
      Cornucopia::Util::ReportTable.new do |report_table|
        report_result_table         = report_table
        simple_report.expand_fields = [:test]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)
      end

      expect(report_result_table.full_table).to match(/\>\ntest\n\</)
      expect(report_result_table.full_table).to match(/\>\nbasic_variable\n\</)
      expect(report_result_table.full_table).to match(/\>basic variable\</)
      expect(report_result_table.full_table).to match(/\>\noverridden_variable\n\</)
      expect(report_result_table.full_table).to match(/\>processed variable\</)
      expect(report_result_table.full_table).to match(/@sub_basic_variable=/)
      expect(report_result_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
      expect(report_result_table.full_table).to match(/@sub_overridden_variable=/)
      expect(report_result_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
    end

    it "expands leaf nodes inline" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields        = [:test]
        simple_report.expand_inline_fields = [:test]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).not_to match(/\>\ntest\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).to match(/@sub_basic_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
        expect(report_table.full_table).to match(/@sub_overridden_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
      end
    end

    it "expands instance variables" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields = [:test]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).to match(/\>\ntest\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).to match(/@sub_basic_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
        expect(report_table.full_table).to match(/@sub_overridden_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
      end
    end

    it "expands instance variables inline" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields        = [:test, :test__sub_class_variable]
        simple_report.expand_inline_fields = [:test, :test__sub_class_variable]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).not_to match(/\>\ntest\n\</)
        expect(report_table.full_table).not_to match(/\>\n@sub_class_variable\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).to match(/\>\nsub_basic_variable\n\</)
        expect(report_table.full_table).to match(/\>sub basic variable\</)
        expect(report_table.full_table).to match(/\>\nsub_overridden_variable\n\</)
        expect(report_table.full_table).to match(/\>sub processed variable\</)
      end
    end

    it "excludes variables" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields  = [:test]
        simple_report.exclude_fields = [:test__sub_class_variable]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).to match(/\>\ntest\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).not_to match(/@sub_basic_variable=/)
        expect(report_table.full_table).not_to match(/\&quot\;sub basic variable\&quot\;/)
        expect(report_table.full_table).not_to match(/@sub_overridden_variable=/)
        expect(report_table.full_table).not_to match(/\&quot\;sub overridden variable\&quot\;/)
      end
    end

    it "outputs log files" do
      expect(Cornucopia::Util::LogCapture).to receive(:capture_logs).and_return(nil)

      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.export_field_record({ report_element: [:logs] },
                                          test,
                                          :logs,
                                          report_table,
                                          0)
      end
    end

    it "outputs diagnostics" do
      expect(Cornucopia::Capybara::PageDiagnostics).to receive(:dump_details_in_table).and_return(nil)

      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.export_field_record({ report_element: [:capybara_page_diagnostics] },
                                          test,
                                          :capybara_page_diagnostics,
                                          report_table,
                                          0)
      end
    end

    it "expands a hash" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields = [:test, :test__hash_variable]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).to match(/\>\ntest\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).to match(/@sub_basic_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
        expect(report_table.full_table).to match(/@sub_overridden_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
        expect(report_table.full_table).to match(/\>\nhash_variable\n\</)
        expect(report_table.full_table).to match(/\>\nkey_1\n\</)
        expect(report_table.full_table).to match(/\>value\</)
        expect(report_table.full_table).to match(/\>\nanother key\n\</)
        expect(report_table.full_table).to match(/\>another value\</)
      end
    end

    it "doesn't expand a field if it isn't directly exported" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields  = [:test, :test__hash_variable]
        simple_report.exclude_fields = [:test__hash_variable]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).to match(/\>\ntest\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).to match(/@sub_basic_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
        expect(report_table.full_table).to match(/@sub_overridden_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
        expect(report_table.full_table).not_to match(/\>\nhash_variable\n\</)
        expect(report_table.full_table).not_to match(/\>\nkey_1\n\</)
        expect(report_table.full_table).not_to match(/\>value\</)
        expect(report_table.full_table).not_to match(/\>\nanother key\n\</)
        expect(report_table.full_table).not_to match(/\>another value\</)
      end
    end

    it "expands an array" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields = [:test, :test__array_variable]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).to match(/\>\ntest\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).to match(/@sub_basic_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
        expect(report_table.full_table).to match(/@sub_overridden_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
        expect(report_table.full_table).to match(/\>\nhash_variable\n\</)
        expect(report_table.full_table).not_to match(/\>\nkey_1\n\</)
        expect(report_table.full_table).not_to match(/\>value\</)
        expect(report_table.full_table).not_to match(/\>\nanother key\n\</)
        expect(report_table.full_table).not_to match(/\>another value\</)
        expect(report_table.full_table).to match(/\>\narray_variable\n\</)
        expect(report_table.full_table).to match(/\>\n0\n\</)
        expect(report_table.full_table).to match(/\>1\n\</)
        expect(report_table.full_table).to match(/\>\n1\n\</)
        expect(report_table.full_table).to match(/\>b\</)
        expect(report_table.full_table).to match(/\>\n2\n\</)
        expect(report_table.full_table).to match(/\>:fred_sym\n\</)
        expect(report_table.full_table).to match(/\>\nstruct_variable\n\</)
        expect(report_table.full_table).not_to match(/\>\nx\n\</)
        expect(report_table.full_table).not_to match(/\>#{test.instance_variable_get(:@struct_variable).x}\n\</)
        expect(report_table.full_table).not_to match(/\>\ny\n\</)
        expect(report_table.full_table).not_to match(/\>#{test.instance_variable_get(:@struct_variable).y}\n\</)
      end
    end

    it "expands a structure" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields = [:test, :test__struct_variable]
        simple_report.export_field_record({ report_element: [:test] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).to match(/\>\ntest\n\</)
        expect(report_table.full_table).to match(/\>\nbasic_variable\n\</)
        expect(report_table.full_table).to match(/\>basic variable\</)
        expect(report_table.full_table).to match(/\>\noverridden_variable\n\</)
        expect(report_table.full_table).to match(/\>processed variable\</)
        expect(report_table.full_table).to match(/@sub_basic_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
        expect(report_table.full_table).to match(/@sub_overridden_variable=/)
        expect(report_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
        expect(report_table.full_table).to match(/\>\nhash_variable\n\</)
        expect(report_table.full_table).not_to match(/\>\nkey_1\n\</)
        expect(report_table.full_table).not_to match(/\>value\</)
        expect(report_table.full_table).not_to match(/\>\nanother key\n\</)
        expect(report_table.full_table).not_to match(/\>another value\</)
        expect(report_table.full_table).to match(/\>\narray_variable\n\</)
        expect(report_table.full_table).not_to match(/\>\n0\n\</)
        expect(report_table.full_table).not_to match(/\>1\n\</)
        expect(report_table.full_table).not_to match(/\>\n1\n\</)
        expect(report_table.full_table).not_to match(/\>b\</)
        expect(report_table.full_table).not_to match(/\>\n2\n\</)
        expect(report_table.full_table).not_to match(/\>:fred_sym\n\</)
        expect(report_table.full_table).to match(/\>\nstruct_variable\n\</)
        expect(report_table.full_table).to match(/\>\nx\n\</)
        expect(report_table.full_table).to match(/\>#{test.instance_variable_get(:@struct_variable).x}\n\</)
        expect(report_table.full_table).to match(/\>\ny\n\</)
        expect(report_table.full_table).to match(/\>#{test.instance_variable_get(:@struct_variable).y}\n\</)
      end
    end
  end

  describe "#add_report_objects" do
    it "adds report objects" do
      report = Cornucopia::Util::ConfiguredReport.new

      expect(report.instance_variable_get(:@report_objects)[:test_object]).not_to be
      expect(report.instance_variable_get(:@report_objects)[:another_object]).not_to be

      report.add_report_objects({ test_object: "a test object", another_object: "another object" })

      expect(report.instance_variable_get(:@report_objects)[:test_object]).to be == "a test object"
      expect(report.instance_variable_get(:@report_objects)[:another_object]).to be == "another object"
    end

    it "updates report objects" do
      report = Cornucopia::Util::ConfiguredReport.new

      expect(report.instance_variable_get(:@report_objects)[:test_object]).not_to be
      expect(report.instance_variable_get(:@report_objects)[:another_object]).not_to be

      report.add_report_objects({ test_object: "a test object", another_object: "another object" })

      expect(report.instance_variable_get(:@report_objects)[:test_object]).to be == "a test object"
      expect(report.instance_variable_get(:@report_objects)[:another_object]).to be == "another object"

      report.add_report_objects({ another_object: "still another object", third_object: "A third object" })

      expect(report.instance_variable_get(:@report_objects)[:test_object]).to be == "a test object"
      expect(report.instance_variable_get(:@report_objects)[:another_object]).to be == "still another object"
      expect(report.instance_variable_get(:@report_objects)[:third_object]).to be == "A third object"
    end
  end

  describe "#generate_report" do
    it "can generate a report" do
      report  = Cornucopia::Util::ReportBuilder.current_report
      builder = Cornucopia::Util::ConfiguredReport.new
      builder.add_report_objects({ fred: "fred", test: test })

      builder.expand_fields = [:test, :test__hash_variable]

      builder.min_fields = [:test]

      builder.generate_report(report)

      full_table = File.read(report.report_test_contents_page_name)

      expect(full_table).not_to match(/\"cornucopia-show-hide-section\"/)
      expect(full_table).to match(/\>\ntest\n\</)
      expect(full_table).to match(/\>\nbasic_variable\n\</)
      expect(full_table).to match(/\>basic variable\</)
      expect(full_table).to match(/\>\noverridden_variable\n\</)
      expect(full_table).to match(/\>processed variable\</)
      expect(full_table).to match(/@sub_basic_variable=/)
      expect(full_table).to match(/\&quot\;sub basic variable\&quot\;/)
      expect(full_table).to match(/@sub_overridden_variable=/)
      expect(full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
      expect(full_table).to match(/\>\nhash_variable\n\</)
      expect(full_table).to match(/\>\nkey_1\n\</)
      expect(full_table).to match(/\>value\</)
      expect(full_table).to match(/\>\nanother key\n\</)
      expect(full_table).to match(/\>another value\</)
    end

    it "allows adding to a report" do
      report  = Cornucopia::Util::ReportBuilder.current_report
      builder = Cornucopia::Util::ConfiguredReport.new
      builder.add_report_objects({ fred: "fred", test: test })

      builder.expand_fields = [:test, :test__hash_variable]

      builder.min_fields = [:test]

      builder.generate_report(report) do |in_report, table|
        table.write_stats("Something_Extra", "A value")
      end

      full_table = File.read(report.report_test_contents_page_name)

      expect(full_table).to match(/\"cornucopia-show-hide-section\"/)
      expect(full_table).to match(/\>\ntest\n\</)
      expect(full_table).to match(/\>\nSomething_Extra\n\</)
      expect(full_table).to match(/\>A value\</)
      expect(full_table).to match(/\>\nbasic_variable\n\</)
      expect(full_table).to match(/\>basic variable\</)
      expect(full_table).to match(/\>\noverridden_variable\n\</)
      expect(full_table).to match(/\>processed variable\</)
      expect(full_table).to match(/@sub_basic_variable=/)
      expect(full_table).to match(/\&quot\;sub basic variable\&quot\;/)
      expect(full_table).to match(/@sub_overridden_variable=/)
      expect(full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
      expect(full_table).to match(/\>\nhash_variable\n\</)
      expect(full_table).to match(/\>\nkey_1\n\</)
      expect(full_table).to match(/\>value\</)
      expect(full_table).to match(/\>\nanother key\n\</)
      expect(full_table).to match(/\>another value\</)
    end

    it "creates a sub-section for secondary information" do
      report  = Cornucopia::Util::ReportBuilder.current_report
      builder = Cornucopia::Util::ConfiguredReport.new
      builder.add_report_objects({ fred: "fred", test: test })

      builder.expand_fields = [:test, :test__hash_variable]

      builder.min_fields       = [:test__basic_variable]
      builder.exclude_fields   = [:test__basic_variable]
      builder.more_info_fields = [:test]

      builder.generate_report(report)

      full_table = File.read(report.report_test_contents_page_name)

      expect(full_table).to match(/\"cornucopia-show-hide-section\"/)
      expect(full_table).to match(/\>\ntest\n\</)
      expect(full_table).to match(/\>\nbasic_variable\n\</)
      expect(full_table).to match(/\>basic variable\</)
      expect(full_table).to match(/\>\noverridden_variable\n\</)
      expect(full_table).to match(/\>processed variable\</)
      expect(full_table).to match(/@sub_basic_variable=/)
      expect(full_table).to match(/\&quot\;sub basic variable\&quot\;/)
      expect(full_table).to match(/@sub_overridden_variable=/)
      expect(full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
      expect(full_table).to match(/\>\nhash_variable\n\</)
      expect(full_table).to match(/\>\nkey_1\n\</)
      expect(full_table).to match(/\>value\</)
      expect(full_table).to match(/\>\nanother key\n\</)
      expect(full_table).to match(/\>another value\</)
    end

    it "creates a report within an existing table" do
      report    = Cornucopia::Util::ReportBuilder.current_report
      the_table = nil

      Cornucopia::Util::ReportTable.new do |report_table|
        the_table = report_table

        builder = Cornucopia::Util::ConfiguredReport.new
        builder.add_report_objects({ fred: "fred", test: test })

        builder.expand_fields = [:test, :test__hash_variable]

        builder.min_fields       = [:test__basic_variable]
        builder.exclude_fields   = [:test__basic_variable]
        builder.more_info_fields = [:test]

        builder.generate_report(report, report_table: report_table)
      end

      report.close

      expect(the_table.full_table).not_to match(/\"cornucopia-show-hide-section\"/)
      expect(the_table.full_table).to match(/\>\ntest\n\</)
      expect(the_table.full_table).to match(/\>\nbasic_variable\n\</)
      expect(the_table.full_table).to match(/\>basic variable\</)
      expect(the_table.full_table).to match(/\>\noverridden_variable\n\</)
      expect(the_table.full_table).to match(/\>processed variable\</)
      expect(the_table.full_table).to match(/@sub_basic_variable=/)
      expect(the_table.full_table).to match(/\&quot\;sub basic variable\&quot\;/)
      expect(the_table.full_table).to match(/@sub_overridden_variable=/)
      expect(the_table.full_table).to match(/\&quot\;sub overridden variable\&quot\;/)
      expect(the_table.full_table).to match(/\>\nhash_variable\n\</)
      expect(the_table.full_table).to match(/\>\nkey_1\n\</)
      expect(the_table.full_table).to match(/\>value\</)
      expect(the_table.full_table).to match(/\>\nanother key\n\</)
      expect(the_table.full_table).to match(/\>another value\</)
    end

    it "does not export values that don't exist on the object" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields = [:test, :test__hash_variable]

        simple_report.export_field_record({ report_element: [:test,
                                                             :hash_variable,
                                                             :fake_hash_value] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).not_to match(/fake_hash_value/)
      end
    end
  end

  describe "leaf options" do
    describe "#find_leaf_options" do
      it "only finds an element in the array" do
        leaf_options  = []
        leaf_elements = rand(40..50).times.map { Faker::Lorem.word.to_sym }.uniq
        num_items     = rand(5..10)
        leaf_pos      = 0
        leaf_size     = (leaf_elements.size - 1) / num_items

        num_items.times do
          some_options = { some_option: Faker::Lorem.sentence }
          leaf_options << { report_element: leaf_elements[leaf_pos..leaf_pos + leaf_size - 1], report_options: some_options }
          leaf_pos += leaf_size
        end

        rand_item = rand(0..leaf_options.length - 1)

        simple_report.leaf_options = leaf_options
        expect(simple_report.find_leaf_options(leaf_options[rand_item])).to be == leaf_options[rand_item]
        expect(simple_report.find_leaf_options({ report_element: [leaf_elements[leaf_pos]] })).not_to be
      end

      it "ignores to_s" do
        leaf_options  = []
        leaf_elements = rand(40..50).times.map { Faker::Lorem.word.to_sym }.uniq
        num_items     = rand(5..10)
        leaf_pos      = 0
        leaf_size     = (leaf_elements.size - 1) / num_items

        num_items.times do
          some_options = { some_option: Faker::Lorem.sentence }
          leaf_options << { report_element: [*leaf_elements[leaf_pos..leaf_pos + leaf_size - 1], :to_s],
                            report_options: some_options }
          leaf_pos += leaf_size
        end

        rand_item = rand(0..leaf_options.length - 1)

        simple_report.leaf_options = leaf_options
        expect(simple_report.find_leaf_options(leaf_options[rand_item])).to be == leaf_options[rand_item]
        expect(simple_report.find_leaf_options({ report_element: [leaf_elements[leaf_pos]] })).not_to be
      end

      it "ignores array indexes" do
        leaf_options  = []
        leaf_elements = rand(40..50).times.map { Faker::Lorem.word.to_sym }.uniq
        num_items     = rand(5..10)
        leaf_pos      = 0
        leaf_size     = (leaf_elements.size - 1) / num_items

        num_items.times do
          some_options = { some_option: Faker::Lorem.sentence }
          leaf_options << { report_element: [*leaf_elements[leaf_pos..leaf_pos + leaf_size - 1], rand(0..1000).to_s.to_sym],
                            report_options: some_options }
          leaf_pos += leaf_size
        end

        rand_item = rand(0..leaf_options.length - 1)

        simple_report.leaf_options = leaf_options
        expect(simple_report.find_leaf_options(leaf_options[rand_item])).to be == leaf_options[rand_item]
        expect(simple_report.find_leaf_options({ report_element: [leaf_elements[leaf_pos]] })).not_to be
      end
    end

    it "uses leaf options" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.leaf_options = [{ report_element: [:key_1], report_options: { fake_options: true } }]

        expect(report_table).to receive(:write_stats).with(:key_1, "value", { fake_options: true })

        simple_report.export_field_record({ report_element: [:test,
                                                             :hash_variable,
                                                             :key_1] },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)
      end
    end

    it "uses node options over leaf options" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.leaf_options = [{ report_element: [:key_1], report_options: { fake_options: true } }]

        expect(report_table).to receive(:write_stats).with(:key_1, "value", { real_options: true })

        simple_report.export_field_record({ report_element: [:test,
                                                             :hash_variable,
                                                             :key_1],
                                            report_options: { real_options: true } },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)
      end
    end

    it "outputs a custom label" do
      Cornucopia::Util::ReportTable.new do |report_table|
        custom_label               = Faker::Lorem.word
        simple_report.leaf_options = [{ report_element: [:key_1], report_options: { fake_options: true } }]

        expect(report_table).
            to receive(:write_stats).with(custom_label, "value", { real_options: true, label: custom_label })

        simple_report.export_field_record({ report_element: [:test,
                                                             :hash_variable,
                                                             :key_1],
                                            report_options: { label: custom_label, real_options: true } },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)
      end
    end

    it "sends expand options to children nodes" do
      Cornucopia::Util::ReportTable.new do |report_table|
        simple_report.expand_fields = [:test, :test__hash_variable]
        simple_report.leaf_options  = [{ report_element: [:key_1], report_options: { fake_options: true } }]

        total_count = 0
        allow_any_instance_of(Cornucopia::Util::ReportTable).to receive(:write_stats) do |label, value, options|
          total_count += 1 if label == :key_1 && value == "value" && options == { real_options: true }
          total_count += 1 if label == "another key" && value == "another value"
        end.and_call_original

        simple_report.export_field_record({ report_element: [:test,
                                                             :hash_variable],
                                            report_options: { exclude_code_block: true } },
                                          test,
                                          :test,
                                          report_table,
                                          0,
                                          report_object_set: true)

        expect(report_table.full_table).not_to match /\<code\>/
      end
    end
  end
end
