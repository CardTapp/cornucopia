# frozen_string_literal: true

require 'active_support/concern'

module Cornucopia
  module SitePrism
    module ClassExtensions
      def to_capybara_node
        @__corunucopia_base_node || super
      end
    end

    module ElementExtensions
      extend ActiveSupport::Concern

      included do
        self.prepend Cornucopia::SitePrism::ClassExtensions

        ::Capybara::Session::DSL_METHODS.each do |method|
          alias_method "__cornucopia_site_prism_orig_#{method}".to_sym, method

          define_method method do |*args, &block|
            if @__corunucopia_base_node
              @__corunucopia_base_node.send method, *args, &block
            else
              send "__cornucopia_site_prism_orig_#{method}", *args, &block
            end
          end
        end
      end

      module ClassMethods
        # patterned_elements defines a set of elements where the find pattern is based on the
        # name that will be used for the element.
        #
        # element will be called once for each element with the find pattern where the string
        # `%{element_name}` will be replace with the name for the element.
        # The pattern must include `%{element_name}`.
        #
        # Parameters:
        #   pattern   - String - This is the pattern that will be used to create the find option
        #               for the element.  The pattern must include `%{element_name}`.
        #   elements  - An array of symbols for the elements which will be defined.
        #   options   - A set of options
        #               find_type:          The type of the finder which will be used.  The default is :css
        #               element_array:      If not false or nil, this will cause the function to call `elements` instead
        #                                   of `element`
        #               additional_options: A hash of additional options which will be sent to element call.
        #
        # Examples:
        #   patterned_elements "\#%{element_name}",
        #                      :user_first_name,
        #                      :user_last_name,
        #                      :user_middle_name,
        #                      :user_sex
        #
        #     Will call:
        #       element :user_first_name, "\#user_first_name"
        #       element :user_last_name, "\#user_last_name"
        #       element :user_middle_name, "\#user_middle_name"
        #       element :user_sex, "\#user_sex"
        #
        #   patterned_elements "//option[contains(text(), \"${element_name}\")]",
        #                      :Cincinati,
        #                      :Chicago,
        #                      :Denver,
        #                      find_type: :xpath,
        #                      additional_options: { visible: false }
        #
        #     Will call:
        #       element :Cincinati, :xpath, "//option[contains(text(), \"Cincinati\")]", visible: false
        #       element :Chicago, :xpath, "//option[contains(text(), \"Chicago\")]", visible: false
        #       element :Denver, :xpath, "//option[contains(text(), \"Denver\")]", visible: false
        def patterned_elements(pattern, *elements)
          options = elements.extract_options!

          unless pattern =~ /\%\{element_name\}/
            raise Exception.new("Invalid pattern \"#{pattern}\".  Pattern must contain \"%{element_name}\".")
          end

          element_function = :element
          element_function = :elements if options[:element_array]

          element_name_index = 0
          options_array      = []
          if options[:find_type]
            options_array << options[:find_type]
            element_name_index += 1
          end
          options_array << :__blank__
          options_array << pattern
          options_array << options[:additional_options] if options[:additional_options]

          elements.each do |element_name|
            options_array[element_name_index]     = element_name.to_s.gsub(/[-]/, "_").to_sym
            options_array[element_name_index + 1] = pattern % { element_name: element_name }
            send element_function, *options_array
          end
        end

        # form_elements defines an ID finder for most form elements.  Given a <model_name> and an
        # array of <field_name>s, this function will call `element` once for each <field_name>
        # defining an id based element assuming it was definied within a form for <model_name>.
        #
        # This is based off the fact that the IDs for most form elements follows a basic pattern
        # of:  "<model_name>_<field_name>".
        #
        # Parameters:
        #   model_name
        #   field_names
        #   options   - A set of options
        #               element_array:      If not false or nil, this will cause the function to call `elements` instead
        #                                   of `element`
        #
        # Example:
        #   form_elements :user,
        #                 :first_name,
        #                 :last_name,
        #                 :middle_name,
        #                 :sex
        #
        #     Will call:
        #       element :first_name, "\#user_first_name"
        #       element :last_name, "\#user_last_name"
        #       element :middle_name, "\#user_middle_name"
        #       element :sex, "\#user_sex"
        def form_elements(model_name, *field_names)
          options = field_names.extract_options!

          patterned_elements "\##{model_name}_%{element_name}", *field_names, options.slice(:element_array)
        end

        # id_elements defines an ID finder where the id of the element is the name for the element.
        #
        # Parameters:
        #   element_names - An array of elements to define where the id of the element is the same as the element name
        #   options       - A set of options
        #                   element_array:      If not false or nil, this will cause the function to call `elements` instead
        #                                       of `element`
        #
        # Example:
        #   id_elements :some_object,
        #               :another_object
        #
        #     Will call:
        #       element :some_object, "\#some_object"
        #       element :another_object, "\#another_object"
        def id_elements(*element_names)
          options = element_names.extract_options!

          patterned_elements "\#%{element_name}", *element_names, options.slice(:element_array)
        end

        # class_elements defines an ID finder where the class of the element is the name for the element.
        #
        # Parameters:
        #   element_names - An array of elements to define where the id of the element is the same as the element name
        #   options       - A set of options
        #                   element_array:      If not false or nil, this will cause the function to call `elements` instead
        #                                       of `element`
        #
        # Example:
        #   id_elements :some_object,
        #               :another_object
        #
        #     Will call:
        #       element :some_object, ".some_object"
        #       element :another_object, ".another_object"
        def class_elements(*element_names)
          options = element_names.extract_options!

          patterned_elements ".%{element_name}", *element_names, options.slice(:element_array)
        end

        # indexed_elements defines a set of elements where the finder pattern can be based off of
        # an index value.
        #
        # This can be useful for table columns for example.
        #
        # Parameters:
        #   index_pattern   - String - This is the pattern that will be used to create the find option
        #                     for the element.  The pattern must include `%{element_index}`.
        #   element_names   - An array of symbols for the elements which will be defined.
        #                     The name :__skip__ will be ignored.  Ignored elements will always increment by one and
        #                     will ignore the increment value.
        #   options         - A set of options
        #                     find_type:          The type of the finder which will be used.  The default is :css
        #                     element_array:      If not false or nil, this will cause the function to call `elements` instead
        #                                         of `element`
        #                     additional_options: A hash of additional options which will be sent to element call.
        #                     start_index:        The start value for the first index element.
        #                     increment:          The amount the index will be incremented by each time.
        #
        # Examples:
        #   indexed_elements "\#my_table tr td:nth-child(%{element_index})",
        #                      :first_name,
        #                      :last_name,
        #                      :middle_name,
        #                      :sex
        #
        #     Will call:
        #       element :first_name, "\#my_table tr td:nth-child(1)"
        #       element :last_name, "\#my_table tr td:nth-child(2)"
        #       element :middle_name, "\#my_table tr td:nth-child(3)"
        #       element :sex, "\#my_table tr td:nth-child(4)"
        #
        #   indexed_elements "\#my_table tr td:nth-child(%{element_index})",
        #                      :first_name,
        #                      :last_name,
        #                      :middle_name,
        #                      :__skip__
        #                      :sex
        #
        #     Will call:
        #       element :first_name, "\#my_table tr td:nth-child(1)"
        #       element :last_name, "\#my_table tr td:nth-child(2)"
        #       element :middle_name, "\#my_table tr td:nth-child(3)"
        #       element :sex, "\#my_table tr td:nth-child(5)"
        #
        #   indexed_elements "\#my_table tr td:nth-child(%{element_index})",
        #                      :first_name,
        #                      :last_name,
        #                      :middle_name,
        #                      :__skip__
        #                      :sex,
        #                      start_index: 4
        #                      increment:   3
        #
        #     Will call:
        #       element :first_name, "\#my_table tr td:nth-child(4)"
        #       element :last_name, "\#my_table tr td:nth-child(7)"
        #       element :middle_name, "\#my_table tr td:nth-child(10)"
        #       element :sex, "\#my_table tr td:nth-child(12)"
        def indexed_elements(index_pattern, *element_names)
          options = element_names.extract_options!

          element_function = :element
          element_function = :elements if options[:element_array]

          element_index   = options[:start_index] || 1
          index_increment = options[:increment] || 1

          unless index_pattern =~ /\%\{element_index\}/
            raise Exception.new("Invalid index_pattern \"#{index_pattern}\".  Pattern must contain \"%{element_index}\".")
          end
          raise Exception.new("Increment value may not be 0") if index_increment == 0

          options_array      = []
          element_name_index = 0
          if options[:find_type]
            options_array << options[:find_type]
            element_name_index += 1
          end
          options_array << :__blank__
          options_array << index_pattern
          options_array << options[:additional_options] if options[:additional_options]

          element_names.each do |element_name|
            if [:__blank__, :__skip__].include?(element_name)
              element_index += 1
              next
            end

            options_array[element_name_index]     = element_name
            options_array[element_name_index + 1] = index_pattern % { element_index: element_index }
            send element_function, *options_array
            element_index += index_increment
          end
        end

        # I don't need this right now.
        # I am thinking that I should try using x-path next time I need this.
        #
        # # immediate_child_element element_name, find_string == element element_name, "> #{find_string}"
        # def immediate_child_element(element_name, *find_args)
        #   self.class_eval do
        #     elements "__cornucopia_element_#{element_name}", *find_args
        #   end
        #
        #   define_method element_name.to_s do
        #     the_element = send("__cornucopia_element_#{element_name}").reduce([]) do |array, element|
        #       array << element if element.parent == self.root_element
        #       array
        #     end
        #
        #     raise ::Capybara::ElementNotFound unless the_element.length > 0
        #     raise ::Capybara::Ambiguous unless the_element.length == 1
        #
        #     the_element[0]
        #   end
        # end
      end

      def owner_node
        @__corunucopia_base_node
      end

      def owner_node=(base_node)
        @__corunucopia_base_node = base_node
      end
    end
  end
end
