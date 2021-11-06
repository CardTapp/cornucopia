# frozen_string_literal: true

require ::File.expand_path("../lib/cornucopia/util/report_builder", File.dirname(__FILE__))

def generate_report_file(folder_name)
  generated_report = Cornucopia::Util::ReportBuilder.new_report(folder_name, "sample_report")
  rand(5..10).times do
    generated_report.within_section(Faker::Lorem.sentence) do |build_report|
      build_report.within_table do |table|
        build_table(table, 0)

        @last_val = Faker::Lorem.words(number: rand(1..4)).join("_")
        table.write_stats(@last_val, Faker::Lorem.sentence)
      end
    end
  end

  report_name = generated_report.report_base_page_name
  generated_report.close

  report_name
end

def build_table(table, level)
  rand(5..10).times do
    case rand(10)
      when 9
        if level < 3
          Cornucopia::Util::ReportTable.new(nested_table:       table,
                                            nested_table_label: Faker::Lorem.words(number: rand(1..4)).join("_")) do |sub_report|
            build_table(sub_report, level + 1)
          end
        else
          table.write_stats(Faker::Lorem.words(number: rand(1..4)).join("_"), Faker::Lorem.sentence)
        end

      when 2
        table.write_stats(Faker::Lorem.words(number: rand(1..4)).join("_"), Faker::Lorem.paragraph)

      when 3
        table.write_stats(Faker::Lorem.words(number: rand(1..4)).join("_"), Faker::Lorem.paragraphs(number: rand(5..10)).join("\n\n"))

      else
        table.write_stats(Faker::Lorem.words(number: rand(1..4)).join("_"), Faker::Lorem.sentence)
    end
  end
end