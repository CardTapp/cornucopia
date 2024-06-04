# frozen_string_literal: true

module Cornucopia
  module SitePrism
    # PageApplication is a class used to fetch page objects and memoize them
    # without really having to know anything about them.
    #
    # This class is intended to be the base class for a page application object.
    #
    # An example of how it is designed to work is:
    #
    # class MyApplication < Cornucopia::SitePrism::PageApplication
    #   def pages_module
    #     MyPagesModule
    #   end
    # end
    #
    # module MyPagesModule
    #   class MyPage < SitePrism::Page
    #   end
    # end
    #
    # page = MyApplication.my_page
    #
    #
    # The system works as follows:
    #   * Pages are defined as:  BaseModule::SubModule::NamePage
    #       BaseModule:: is optional
    #       SubModule:: is optional and you can have as many levels as you want
    #       Name is the name of the page
    #       Page is recommended to distinguish pages from sections
    #
    #   * A singleton instance of your application class is memoized.  That instance
    #     is used to instantiate and memoize all of the page objects.  Additional
    #     functions and properties which you may need may be added to this class.
    #     Remember, this singleton instance is instantiated once per test run and
    #     will be reused in multiple tests.
    #
    #   * To get a page object, simply use your class object and call the underscored name
    #     of the page and its modules as a class method.  The class method name will be
    #     deconstructed and constantized into a page object.  The page object will be created
    #     once and then cached for future use.  Use 2 underscores (__) between modules.
    #       To get the sample page it would be:  MyApplication.sub_module__name_page
    #
    # All you have to do is define the page objects under a single module namespace and the
    # application class will recognize the pages and return them.

    class PageApplication
      @@current_instances = {}

      def pages_module
        Object
      end

      class << self
        def current_instance
          @@current_instances[self.name] ||= self.new
        end

        # Redirect any non-class methods to the instance if the instance supports them.
        def method_missing(method_sym, *arguments, &block)
          if self.current_instance.respond_to?(method_sym, true)
            self.current_instance.send(method_sym, *arguments)
          else
            super
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          if self.current_instance.respond_to_missing?(method_sym, include_private)
            true
          else
            super
          end
        end
      end

      def is_page_name?(method_name)
        is_page_name = false
        if method_name =~ /^[@a-z0-9_]+$/i
          base_class = pages_module

          is_page_name = true
          method_name.split("__").each do |module_name|
            if module_name.blank?
              is_page_name = false
              break;
            end

            unless base_class.const_defined?(module_name.camelize)
              is_page_name = false
              break
            end

            base_class = "#{base_class}::#{module_name.camelize}".constantize
          end
        end

        is_page_name
      end

      def method_missing(method_sym, *arguments, &block)
        method_name = method_sym.to_s
        if is_page_name?(method_name)
          return_page = instance_variable_get("@#{method_name}")
          unless return_page
            return_page = "#{pages_module.to_s}::#{method_name.split("__").map(&:camelize).join("::")}".constantize.new
            instance_variable_set("@#{method_name}", return_page)
          end

          return_page
        else
          super
        end
      end

      def respond_to_missing?(method_sym, include_private = false)
        method_name = method_sym.to_s

        if is_page_name?(method_name)
          true
        else
          super
        end
      end
    end
  end
end
