# frozen_string_literal: true

require ::File.expand_path("../../../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("../../../util/report_builder", File.dirname(__FILE__))

module Cornucopia
  module Capybara
    class FinderDiagnostics
      class FindAction
        # A class representing an emelement that was found as a possible match for an action.
        class FoundElement
          ELEMENT_ATTRIBUTES = %w[
            text
            value
            visible?
            checked?
            selected?
            tag_name
            location
            id
            src
            name
            href
            style
            path
            outerHTML
          ].freeze

          NATIVE_ATTRIBUTES = %w[
            size
            type
          ].freeze

          PREDEFINED_ATTRIBUTES = (NATIVE_ATTRIBUTES + ELEMENT_ATTRIBUTES).freeze

          attr_reader :found_element

          def capybara_session
            if Object.const_defined?("::Capybara") &&
                ::Capybara.send(:session_pool).present?
              my_page = ::Capybara.current_session

              my_page if (my_page && my_page.current_url.present? && my_page.current_url != "about:blank")
            end
          rescue StandardError
            nil
          end

          def ==(comparison_object)
            comparison_object.equal?(self) ||
                (comparison_object.instance_of?(self.class) &&
                    (comparison_object.found_element == found_element
                    # ||
                    #     (comparison_object.instance_variable_get(:@elem_text) == @elem_text &&
                    #         comparison_object.instance_variable_get(:@elem_value) == @elem_value &&
                    #         comparison_object.instance_variable_get(:@elem_visible) == @elem_visible &&
                    #         comparison_object.instance_variable_get(:@elem_checked) == @elem_checked &&
                    #         comparison_object.instance_variable_get(:@elem_selected) == @elem_selected &&
                    #         comparison_object.instance_variable_get(:@elem_tag_name) == @elem_tag_name &&
                    #         comparison_object.instance_variable_get(:@elem_location) == @elem_location &&
                    #         comparison_object.instance_variable_get(:@elem_size) == @elem_size &&
                    #         comparison_object.instance_variable_get(:@elem_id) == @elem_id &&
                    #         comparison_object.instance_variable_get(:@elem_name) == @elem_name &&
                    #         comparison_object.instance_variable_get(:@elem_href) == @elem_href &&
                    #         comparison_object.instance_variable_get(:@elem_style) == @elem_style &&
                    #         comparison_object.instance_variable_get(:@elem_path) == @elem_path &&
                    #         comparison_object.instance_variable_get(:@elem_outerHTML) == @elem_outerHTML &&
                    #         comparison_object.instance_variable_get(:@native_class) == @native_class &&
                    #         comparison_object.instance_variable_get(:@native_value) == @native_value &&
                    #         comparison_object.instance_variable_get(:@native_type) == @native_type
                    #     )
                    )
                ) ||
                comparison_object == found_element
          end

          def initialize(found_element)
            @found_element = found_element
            ELEMENT_ATTRIBUTES.each do |attrib|
              variable_name = attrib.to_s.gsub("?", "")
              instance_variable_set("@elem_#{variable_name.gsub(/[\-]/, "_")}", get_attribute(attrib))
            end

            NATIVE_ATTRIBUTES.each do |attrib|
              instance_variable_set("@native_#{attrib.gsub(/[\-]/, "_")}", get_native_attribute(attrib))
            end

            instance_variable_set("@native_class", @found_element[:class])

            session = capybara_session
            if session.driver.respond_to?(:browser) &&
                session.driver.browser.respond_to?(:execute_script) &&
                session.driver.browser.method(:execute_script).arity != 1
              begin
                # This is a "trick" that works with Selenium, but which might not work with other drivers...
                script = "var attrib_list = [];
var attrs = arguments[0].attributes;
for (var nIndex = 0; nIndex < attrs.length; nIndex += 1)
{
  var a = attrs[nIndex];
  attrib_list.push(a.name);
};
return attrib_list;"

                attributes = session.driver.browser.execute_script(script, @found_element.native)
                attributes.each do |attritue|
                  unless PREDEFINED_ATTRIBUTES.include?(attritue)
                    instance_variable_set("@native_#{attritue.gsub(/[\-]/, "_")}", @found_element[attritue])
                  end
                end

                @elem_outerHTML ||= session.driver.browser.execute_script("return arguments[0].outerHTML", @found_element.native)
              rescue ::Capybara::NotSupportedByDriverError
              end
            end

            # information from Selenium that may not be available depending on the form, the full outerHTML of the element
            if (session.respond_to?(:evaluate_script))
              unless (@elem_id.blank?)
                begin
                  @elem_outerHTML ||= session.evaluate_script("document.getElementById('#{@elem_id}').outerHTML")
                rescue ::Capybara::NotSupportedByDriverError
                end
              end
            end
          end

          def get_attribute(attribute)
            if found_element.respond_to?(attribute)
              begin
                found_element.send(attribute)
              rescue ::Capybara::NotSupportedByDriverError
              rescue ArgumentError
              end
            elsif found_element.respond_to?(:[]) && found_element[attribute]
              found_element[attribute]
            else
              get_native_attribute(attribute)
            end
          end

          def get_native_attribute(attribute)
            if found_element.native.respond_to?(attribute)
              found_element.native.send(attribute)
            elsif found_element.native.respond_to?(:[])
              found_element.native[attribute]
            else
              nil
            end
          end
        end
      end
    end
  end
end
