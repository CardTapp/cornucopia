# frozen_string_literal: true

if Object.const_defined?("Capybara") &&
    Capybara.const_defined?("Node") &&
    Capybara::Node.const_defined?("Document")
  unless Capybara::Node::Document.included_modules.include?(Cornucopia::Capybara::FinderExtensions)
    Capybara::Node::Document.prepend Cornucopia::Capybara::FinderExtensions
  end
  unless Capybara::Node::Document.included_modules.include?(Cornucopia::Capybara::MatcherExtensions)
    Capybara::Node::Document.prepend Cornucopia::Capybara::MatcherExtensions
  end
end

if Object.const_defined?("Capybara") &&
    Capybara.const_defined?("Node") &&
    Capybara::Node.const_defined?("Simple")
  unless Capybara::Node::Simple.included_modules.include?(Cornucopia::Capybara::FinderExtensions)
    Capybara::Node::Simple.prepend Cornucopia::Capybara::FinderExtensions
  end
  unless Capybara::Node::Simple.included_modules.include?(Cornucopia::Capybara::MatcherExtensions)
    Capybara::Node::Simple.prepend Cornucopia::Capybara::MatcherExtensions
  end
end

if Object.const_defined?("Capybara") &&
    Capybara.const_defined?("Node") &&
    Capybara::Node.const_defined?("Element")
  unless Capybara::Node::Element.included_modules.include?(Cornucopia::Capybara::FinderExtensions)
    Capybara::Node::Element.prepend Cornucopia::Capybara::FinderExtensions
  end
  unless Capybara::Node::Element.included_modules.include?(Cornucopia::Capybara::MatcherExtensions)
    Capybara::Node::Element.prepend Cornucopia::Capybara::MatcherExtensions
  end
  unless Capybara::Node::Element.included_modules.include?(Cornucopia::Capybara::SelectableValues)
    Capybara::Node::Element.include Cornucopia::Capybara::SelectableValues
  end
end

if Object.const_defined?("Capybara") &&
    Capybara.const_defined?("Session")
  unless Capybara::Session.included_modules.include?(Cornucopia::Capybara::Synchronizable)
    Capybara::Session.include Cornucopia::Capybara::Synchronizable
  end
end
