# frozen_string_literal: true

require "rails_helper"
require ::File.expand_path("../../../lib/cornucopia/site_prism/element_extensions", File.dirname(__FILE__))

describe "SitePrism element_extensions" do
  class TestPage < ::SitePrism::Page
  end

  class TestSection < ::SitePrism::Section
  end

  [TestSection, TestPage].sample(2).each do |test_class|
    describe "#{test_class.name}" do
      let(:pre_name) { Faker::Lorem.word }
      let(:element_names) { Faker::Lorem.words(number: rand(3..10)).map(&:to_sym) }
      let(:class_element_names) { element_names + rand(3..10).times.map { Faker::Lorem.words(number: rand(2..3)).join("-") } }
      let(:increment) { rand(2..10) }
      let(:start_index) { rand(2..10) }
      let(:options) do
        Faker::Lorem.words(number: rand(3..10)).reduce({}) do |hash, option_name|
          hash[option_name] = Faker::Lorem.word
          hash
        end
      end

      describe "#patterned_elements" do
        it "works" do
          expect { test_class.send(:patterned_elements, "\##{pre_name}-%{element_name}", :element_1, :element_2) }.
              not_to raise_exception
        end

        it "requires %{element_name} in the pattern" do
          expect { test_class.send(:patterned_elements, "\##{pre_name}-", :element_1, :element_2) }.to raise_exception
        end

        it "works for 1 element" do
          expect(test_class).to receive(:element).with(element_names[0], "\##{pre_name}-#{element_names[0]}")

          test_class.send(:patterned_elements, "\##{pre_name}-%{element_name}", element_names[0])
        end

        it "calls element once for each element_name" do
          element_names.each do |element_name|
            expect(test_class).to receive(:element).with(element_name, "\##{pre_name}-#{element_name}")
          end

          test_class.send(:patterned_elements, "\##{pre_name}-%{element_name}", *element_names)
        end

        it "converts -'s to _" do
          element_names.each do |element_name|
            expect(test_class).to receive(:element).with(element_name.to_s.gsub("-", "_").to_sym,
                                                         "\##{pre_name}-#{element_name}")
          end

          test_class.send(:patterned_elements, "\##{pre_name}-%{element_name}", *element_names)
        end

        it "calls elements once for each element_name if element_array: true" do
          element_names.each do |element_name|
            expect(test_class).to receive(:elements).with(:xpath, element_name, "\##{pre_name}-#{element_name}")
          end

          test_class.send(:patterned_elements,
                          "\##{pre_name}-%{element_name}",
                          *element_names,
                          find_type:     :xpath,
                          element_array: true)
        end

        it "passes in :find_type" do
          element_names.each do |element_name|
            expect(test_class).to receive(:element).with(:xpath, element_name, "\##{pre_name}-#{element_name}")
          end

          test_class.send(:patterned_elements, "\##{pre_name}-%{element_name}", *element_names, find_type: :xpath)
        end

        it "passes in options" do
          element_names.each do |element_name|
            expect(test_class).to receive(:element).with(:xpath, element_name, "\##{pre_name}-#{element_name}", options)
          end

          test_class.send(:patterned_elements,
                          "\##{pre_name}-%{element_name}",
                          *element_names,
                          find_type:          :xpath,
                          additional_options: options)
        end
      end

      describe "#form_elements" do
        it "calls once per form item" do
          element_names.each do |element_name|
            expect(test_class).to receive(:element).with(element_name, "\##{pre_name}_#{element_name}")
          end

          test_class.send(:form_elements, pre_name.to_sym, *element_names)
        end

        it "calls elements once per form item" do
          element_names.each do |element_name|
            expect(test_class).to receive(:elements).with(element_name, "\##{pre_name}_#{element_name}")
          end

          test_class.send(:form_elements, pre_name.to_sym, *element_names, element_array: true)
        end

        it "ignores other options" do
          element_names.each do |element_name|
            expect(test_class).to receive(:elements).with(element_name, "\##{pre_name}_#{element_name}")
          end

          test_class.send(:form_elements, pre_name.to_sym, *element_names, find_type: :xpath, element_array: true)
        end
      end

      describe "#id_elements" do
        it "calls once per form item" do
          element_names.each do |element_name|
            expect(test_class).to receive(:element).with(element_name, "\##{element_name}")
          end

          test_class.send(:id_elements, *element_names)
        end

        it "calls elements once per form item" do
          element_names.each do |element_name|
            expect(test_class).to receive(:elements).with(element_name, "\##{element_name}")
          end

          test_class.send(:id_elements, *element_names, element_array: true)
        end

        it "ignores other options" do
          element_names.each do |element_name|
            expect(test_class).to receive(:elements).with(element_name, "\##{element_name}")
          end

          test_class.send(:id_elements, *element_names, find_type: :xpath, element_array: true)
        end
      end

      describe "#class_elements" do
        it "calls once per form item" do
          element_names.each do |element_name|
            expect(test_class).to receive(:element).with(element_name, ".#{element_name}")
          end

          test_class.send(:class_elements, *element_names)
        end

        it "calls elements once per form item" do
          element_names.each do |element_name|
            expect(test_class).to receive(:elements).with(element_name, ".#{element_name}")
          end

          test_class.send(:class_elements, *element_names, element_array: true)
        end

        it "ignores other options" do
          element_names.each do |element_name|
            expect(test_class).to receive(:elements).with(element_name, ".#{element_name}")
          end

          test_class.send(:class_elements, *element_names, find_type: :xpath, element_array: true)
        end
      end

      describe "#indexed_elements" do
        it "works" do
          expect { test_class.send(:indexed_elements, "\##{pre_name}-%{element_index}", :element_1, :element_2) }.
              not_to raise_exception
        end

        it "requires %{element_name} in the pattern" do
          expect { test_class.send(:indexed_elements, "\##{pre_name}-", :element_1, :element_2) }.to raise_exception
        end

        it "requires an increment" do
          expect { test_class.send(:indexed_elements, "\##{pre_name}-", :element_1, :element_2, increment: 0) }.
              to raise_exception
        end

        it "works for 1 element" do
          expect(test_class).to receive(:element).with(element_names[0], "\##{pre_name}-1")

          test_class.send(:indexed_elements, "\##{pre_name}-%{element_index}", element_names[0])
        end

        it "calls element once for each element_name" do
          element_names.each_with_index do |element_name, index|
            expect(test_class).to receive(:element).with(element_name, "\##{pre_name}-#{index + 1}")
          end

          test_class.send(:indexed_elements, "\##{pre_name}-%{element_index}", *element_names)
        end

        it "increments the counter" do
          element_names.each_with_index do |element_name, index|
            expect(test_class).to receive(:element).with(element_name, "\##{pre_name}-#{(increment * index) + 1}")
          end

          test_class.send(:indexed_elements, "\##{pre_name}-%{element_index}", *element_names, increment: increment)
        end

        it "can start anywhere" do
          element_names.each_with_index do |element_name, index|
            expect(test_class).to receive(:element).with(element_name, "\##{pre_name}-#{start_index + (increment * index)}")
          end

          test_class.send(:indexed_elements,
                          "\##{pre_name}-%{element_index}",
                          *element_names,
                          increment:   increment,
                          start_index: start_index)
        end

        it "passes in :find_type" do
          element_names.each_with_index do |element_name, index|
            expect(test_class).to receive(:element).
                                      with(:xpath, element_name, "\##{pre_name}-#{start_index + (increment * index)}")
          end

          test_class.send(:indexed_elements,
                          "\##{pre_name}-%{element_index}",
                          *element_names,
                          increment:   increment,
                          start_index: start_index,
                          find_type:   :xpath)
        end

        it "passes in options" do
          element_names.each_with_index do |element_name, index|
            expect(test_class).to receive(:element).
                                      with(:xpath, element_name, "\##{pre_name}-#{start_index + (increment * index)}", options)
          end

          test_class.send(:indexed_elements,
                          "\##{pre_name}-%{element_index}",
                          *element_names,
                          increment:          increment,
                          start_index:        start_index,
                          find_type:          :xpath,
                          additional_options: options)
        end

        it "calls elements if element_array is true" do
          element_names.each_with_index do |element_name, index|
            expect(test_class).to receive(:elements).
                                      with(:xpath, element_name, "\##{pre_name}-#{start_index + (increment * index)}", options)
          end

          test_class.send(:indexed_elements,
                          "\##{pre_name}-%{element_index}",
                          *element_names,
                          increment:          increment,
                          start_index:        start_index,
                          find_type:          :xpath,
                          additional_options: options,
                          element_array:      true)
        end

        it "skips blanks" do
          skip_pos = rand(1..element_names.length - 2)
          element_names[0..skip_pos - 1].each_with_index do |element_name, index|
            expect(test_class).to receive(:elements).
                                      with(:xpath, element_name, "\##{pre_name}-#{start_index + (increment * index)}", options)
          end
          element_names[skip_pos..-1].each_with_index do |element_name, index|
            expect(test_class).to receive(:elements).
                                      with(:xpath, element_name, "\##{pre_name}-#{1 + start_index + (increment * (skip_pos + index))}", options)
          end

          test_array = element_names[0..skip_pos - 1]
          test_array << :__skip__
          test_array += element_names[skip_pos..-1]

          test_class.send(:indexed_elements,
                          "\##{pre_name}-%{element_index}",
                          *test_array,
                          increment:          increment,
                          start_index:        start_index,
                          find_type:          :xpath,
                          additional_options: options,
                          element_array:      true)
        end
      end
    end
  end
end