# frozen_string_literal: true

require "rails_helper"
require ::File.expand_path("../../../lib/cornucopia/util/report_table", File.dirname(__FILE__))

describe Cornucopia::Util::ReportTable do
  describe "initialize" do
    it "calls open and close table around the block" do
      expect_any_instance_of(Cornucopia::Util::ReportTable).to receive(:open_table).once.and_call_original
      expect_any_instance_of(Cornucopia::Util::ReportTable).to receive(:close_table).once.and_call_original

      report_table = Cornucopia::Util::ReportTable.new() do |report_table|
        expect(report_table.is_a?(Cornucopia::Util::ReportTable)).to be_truthy
      end

      expect(report_table.full_table).to be == "<div class=\"cornucopia-table\">\n</div>\n"
    end

    it "can nest calls if necessary" do
      report_table = Cornucopia::Util::ReportTable.new() do |report_table|
        expect(report_table.is_a?(Cornucopia::Util::ReportTable)).to be_truthy
        expect(report_table).to receive(:close_table).once.and_call_original

        Cornucopia::Util::ReportTable.new(report_table: report_table) do |sub_report_table|
          expect(sub_report_table).to be == report_table
          expect(sub_report_table.is_a?(Cornucopia::Util::ReportTable)).to be_truthy
        end
      end

      expect(report_table.full_table).to be == "<div class=\"cornucopia-table\">\n</div>\n"
    end
  end

  describe "#open_table" do
    it "can customize the open statement" do
      report_table = Cornucopia::Util::ReportTable.new(table_prefix: "<div>\n") do |report_table|
      end

      expect(report_table.full_table).to be == "<div>\n</div>\n"
    end
  end

  describe "#close_table" do
    it "can customize the close statement" do
      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
      end

      expect(report_table.full_table).to be == "<div class=\"cornucopia-table\">\n<p>cool</p>\n</div>"
      expect(report_table.full_table).to be_html_safe
    end
  end

  describe "#write_stats" do
    it "raises an exception if the table is closed" do
      report_table = Cornucopia::Util::ReportTable.new do |table|
      end

      expect do
        report_table.write_stats("something", "something")
      end.to raise_exception
    end

    it "escapes the label" do
      expect(Cornucopia::Util::ReportBuilder).to receive(:escape_string).exactly(3).and_call_original

      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
        report_table.write_stats("&amp;", "This is some text")
      end

      expect(report_table.full_table).to match /\<div class=\"cornucopia-cell-label\"\>\n&amp;amp;\n\<\/div\>\n/
    end

    it "pretty prints the value" do
      expect(Cornucopia::Util::ReportBuilder).to receive(:pretty_format).once.and_call_original

      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
        report_table.write_stats("This is some text", "&amp;")
      end

      expect(report_table.full_table).to match /\<pre\>\<code\>&amp;amp;\<\/code\>\<\/pre\>\n/
    end

    it "can suppress the more info block" do
      expect(Cornucopia::Util::ReportBuilder).to receive(:pretty_format).once.and_call_original

      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
        report_table.write_stats("This is some text", "&amp;", prevent_shrink: true)
      end

      expect(report_table.full_table).to_not match /class=\"cornucopia-cell-more-data\"/
    end

    it "escapes the value if it doesn't pretty print" do
      expect(Cornucopia::Util::ReportBuilder).to receive(:escape_string).twice.and_call_original

      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
        report_table.write_stats("This is some text", "&amp;", do_not_pretty_print: true)
      end

      expect(report_table.full_table).to match /\<pre\>\<code\>&amp;amp;\<\/code\>\<\/pre\>\n/
    end

    it "can suppress the code block" do
      expect(Cornucopia::Util::ReportBuilder).to receive(:pretty_format).once.and_call_original

      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
        report_table.write_stats("This is some text", "&amp;", exclude_code_block: true)
      end

      expect(report_table.full_table).to_not match /\<pre\>\<code\>&amp;amp;\<\/code\>\<\/pre\>\n/
    end

    context "not_a_table" do
      it "does not print the label" do
        expect(Cornucopia::Util::ReportBuilder).to receive(:escape_string).exactly(3).and_call_original

        report_table = Cornucopia::Util::ReportTable.new(not_a_table: true) do |report_table|
          report_table.write_stats("&amp;", "This is some text")
        end

        expect(report_table.full_table).not_to match /\<div class=\"cornucopia-cell-label\"\>\n&amp;amp;\n\<\/div\>\n/
        expect(report_table.full_table).to match /\<div class=\"cornucopia-table\"\>\nThis is some text\<\/div\>\n/
      end

      it "outputs the text directly" do
        expect(Cornucopia::Util::ReportBuilder).to receive(:escape_string).exactly(3).and_call_original

        report_table = Cornucopia::Util::ReportTable.new(not_a_table: true) do |report_table|
          report_table.write_stats("&amp;", "This is some &amp; text")
        end

        expect(report_table.full_table).to match /\<div class=\"cornucopia-table\"\>\nThis is some &amp;amp; text\<\/div\>\n/
      end
    end

    it "calls a lambda" do
      custom_text = Faker::Lorem.sentence

      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
        report_table.write_stats("This is some text", "&amp;", format: ->(value) { custom_text.html_safe + value })
      end

      expect(report_table.full_table).to match /\<pre\>\<code\>#{"".html_safe + custom_text}&amp;amp;\<\/code\>\<\/pre\>\n/
    end

    it "a function on an object" do
      class TestClass
        def self.my_function(value)
          "This is some text also.".html_safe + "&amp;"
        end
      end

      report_table = Cornucopia::Util::ReportTable.new(table_postfix: "<p>cool</p>\n</div>") do |report_table|
        report_table.write_stats("This is some text", "&amp;", format_object: TestClass, format_function: :my_function)
      end

      expect(report_table.full_table).to match /\<pre\>\<code\>This is some text also.&amp;amp;\<\/code\>\<\/pre\>\n/
    end
  end

  describe "nested tables" do
    let(:pre_text) { "start_div" }
    let(:post_text) { "end_div" }

    it "nests tables" do
      nest_label   = "".html_safe + Faker::Lorem.sentence
      second_label = "".html_safe + Faker::Lorem.sentence
      second_body  = "".html_safe + Faker::Lorem.paragraphs(number: rand(3..5)).join("\n")

      report_table = nil
      Cornucopia::Util::ReportTable.new(table_prefix:  pre_text,
                                        table_postfix: post_text) do |first_table|
        report_table = first_table
        Cornucopia::Util::ReportTable.new(table_prefix:       pre_text,
                                          table_postfix:      post_text,
                                          nested_table:       first_table,
                                          nested_table_label: nest_label) do |second_table|
          second_table.write_stats second_label, second_body
        end
      end

      expect(report_table).to be
      expect(report_table.full_table).to match /#{second_label}/
      expect(report_table.full_table).to match /#{second_body}/
      expect(report_table.full_table).to match /#{nest_label}/
      expect(report_table.full_table.scan(/\<code\>/).length).to be == 1
      expect(report_table.full_table.scan(/start_div/).length).to be == 2
      expect(report_table.full_table.scan(/end_div/).length).to be == 2
      expect(report_table.full_table.scan(/cornucopia-cell-more-data/).length).to be == 2
      expect(report_table.full_table.scan(/cornucopia-row\"\>/).length).to be == 2
    end

    it "nests tables if they are not empty" do
      nest_label   = "".html_safe + Faker::Lorem.sentence
      second_label = "".html_safe + Faker::Lorem.sentence
      second_body  = "".html_safe + Faker::Lorem.paragraphs(number: rand(3..5)).join("\n")

      report_table = nil
      Cornucopia::Util::ReportTable.new(table_prefix:  pre_text,
                                        table_postfix: post_text) do |first_table|
        report_table = first_table
        Cornucopia::Util::ReportTable.new(table_prefix:         pre_text,
                                          table_postfix:        post_text,
                                          nested_table:         first_table,
                                          nested_table_label:   nest_label,
                                          suppress_blank_table: true) do |second_table|
          second_table.write_stats second_label, second_body
        end
      end

      expect(report_table).to be
      expect(report_table.full_table).to match /#{second_label}/
      expect(report_table.full_table).to match /#{second_body}/
      expect(report_table.full_table).to match /#{nest_label}/
      expect(report_table.full_table.scan(/\<code\>/).length).to be == 1
      expect(report_table.full_table.scan(/start_div/).length).to be == 2
      expect(report_table.full_table.scan(/end_div/).length).to be == 2
      expect(report_table.full_table.scan(/cornucopia-cell-more-data/).length).to be == 2
      expect(report_table.full_table.scan(/cornucopia-row\"\>/).length).to be == 2
    end

    it "does not nest tables if they are empty" do
      nest_label   = "".html_safe + Faker::Lorem.sentence
      second_label = "".html_safe + Faker::Lorem.sentence
      second_body  = "".html_safe + Faker::Lorem.paragraphs(number: rand(3..5)).join("\n")

      report_table = nil
      Cornucopia::Util::ReportTable.new(table_prefix:  pre_text,
                                        table_postfix: post_text) do |first_table|
        report_table = first_table
        Cornucopia::Util::ReportTable.new(table_prefix:         pre_text,
                                          table_postfix:        post_text,
                                          nested_table:         first_table,
                                          nested_table_label:   nest_label,
                                          suppress_blank_table: true) do |second_table|
        end
      end

      expect(report_table).to be
      expect(report_table.full_table).not_to match /#{second_label}/
      expect(report_table.full_table).not_to match /#{second_body}/
      expect(report_table.full_table).not_to match /#{nest_label}/
      expect(report_table.full_table.scan(/\<code\>/).length).to be == 0
      expect(report_table.full_table.scan(/start_div/).length).to be == 1
      expect(report_table.full_table.scan(/end_div/).length).to be == 1
      expect(report_table.full_table.scan(/cornucopia-cell-more-data/).length).to be == 0
      expect(report_table.full_table.scan(/cornucopia-row\"\>/).length).to be == 0
    end

    it "nests tables even if there is an exception" do
      nest_label   = "".html_safe + Faker::Lorem.sentence
      second_label = "".html_safe + Faker::Lorem.sentence
      second_body  = "".html_safe + Faker::Lorem.paragraphs(number: rand(3..5)).join("\n")

      report_table = nil
      expect do
        Cornucopia::Util::ReportTable.new(table_prefix:  pre_text,
                                          table_postfix: post_text) do |first_table|
          report_table = first_table
          Cornucopia::Util::ReportTable.new(table_prefix:       pre_text,
                                            table_postfix:      post_text,
                                            nested_table:       first_table,
                                            nested_table_label: nest_label) do |second_table|
            second_table.write_stats second_label, second_body
            raise Exception.new("This is an exception")
          end
        end
      end.to raise_error(Exception, "This is an exception")

      expect(report_table).to be
      expect(report_table.full_table).to match /#{second_label}/
      expect(report_table.full_table).to match /#{second_body}/
      expect(report_table.full_table).to match /#{nest_label}/
      expect(report_table.full_table).to match /This is an exception/
      expect(report_table.full_table.scan(/This is an exception/).length).to be == 1
      expect(report_table.full_table.scan(/\<code\>/).length).to be == 2
      expect(report_table.full_table.scan(/start_div/).length).to be == 2
      expect(report_table.full_table.scan(/end_div/).length).to be == 2
      expect(report_table.full_table.scan(/cornucopia-cell-more-data/).length).to be == 4
      expect(report_table.full_table.scan(/cornucopia-row\"\>/).length).to be == 3
    end

    it "nests tables even if there is an exception multiple levels deep" do
      nest_label   = "".html_safe + Faker::Lorem.sentence
      second_label = "".html_safe + Faker::Lorem.sentence
      second_body  = "".html_safe + Faker::Lorem.paragraphs(number: rand(3..5)).join("\n")

      report_table = nil
      expect do
        Cornucopia::Util::ReportTable.new(table_prefix:  pre_text,
                                          table_postfix: post_text) do |first_table|
          report_table = first_table
          Cornucopia::Util::ReportTable.new(table_prefix:       pre_text,
                                            table_postfix:      post_text,
                                            nested_table:       first_table,
                                            nested_table_label: nest_label) do |second_table|
            Cornucopia::Util::ReportTable.new(table_prefix:       pre_text,
                                              table_postfix:      post_text,
                                              nested_table:       second_table,
                                              nested_table_label: nest_label) do |third_table|
              third_table.write_stats second_label, second_body
              raise Exception.new("This is an exception")
            end
          end
        end
      end.to raise_error(Exception, "This is an exception")

      expect(report_table).to be
      expect(report_table.full_table).to match /#{second_label}/
      expect(report_table.full_table).to match /#{second_body}/
      expect(report_table.full_table).to match /#{nest_label}/
      expect(report_table.full_table).to match /This is an exception/
      expect(report_table.full_table.scan(/This is an exception/).length).to be == 1
      expect(report_table.full_table.scan(/\<code\>/).length).to be == 2
      expect(report_table.full_table.scan(/start_div/).length).to be == 3
      expect(report_table.full_table.scan(/end_div/).length).to be == 3
      expect(report_table.full_table.scan(/cornucopia-cell-more-data/).length).to be == 4
      expect(report_table.full_table.scan(/cornucopia-row\"\>/).length).to be == 4
    end
  end
end