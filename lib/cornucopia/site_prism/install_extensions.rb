# frozen_string_literal: true

if Object.const_defined?("SitePrism") &&
    ::SitePrism.const_defined?("Page")
  unless SitePrism::Page.included_modules.include?(Cornucopia::SitePrism::ElementExtensions)
    SitePrism::Page.include Cornucopia::SitePrism::ElementExtensions
  end
end

if Object.const_defined?("SitePrism") &&
    ::SitePrism.const_defined?("Section")
  unless SitePrism::Section.included_modules.include?(Cornucopia::SitePrism::ElementExtensions)
    SitePrism::Section.include Cornucopia::SitePrism::ElementExtensions
  end
  unless SitePrism::Section.included_modules.include?(Cornucopia::SitePrism::SectionExtensions)
    SitePrism::Section.prepend Cornucopia::SitePrism::SectionExtensions
  end
end
