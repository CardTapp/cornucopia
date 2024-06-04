# frozen_string_literal: true

require "digest"
# require ::File.expand_path("../../util/configuration", File.dirname(__FILE__))
require ::File.expand_path("../../util/report_builder", File.dirname(__FILE__))
require ::File.expand_path("../../util/report_table", File.dirname(__FILE__))

module Cornucopia
  module Capybara
    class PageDiagnostics
      class WindowIterator
        def initialize(window_handles, current_window, diagnostics)
          @window_handles = window_handles
          @current_window = current_window
          @diagnostics    = diagnostics
        end

        def each(&block)
          begin
            @diagnostics.allow_other_windows = false

            if @window_handles.length > 1
              @window_handles.each do |window_handle|
                unless @current_window && @current_window == window_handle
                  switched = @diagnostics.execute_driver_function(:switch_to_window,
                                                                  "could not switch windows",
                                                                  window_handle)
                  if switched != "could not switch windows"
                    block.yield @diagnostics
                  end
                end
              end
            end
          ensure
            @diagnostics.allow_other_windows = true
            @diagnostics.execute_driver_function(:switch_to_window, "could not switch windows", @current_window)
          end
        end
      end
    end
  end
end
