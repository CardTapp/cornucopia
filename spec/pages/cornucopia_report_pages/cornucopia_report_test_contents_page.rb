# frozen_string_literal: true

module CornucopiaReportPages
  class CornucopiaReportTestContentsPage < SitePrism::Page
    class RowSection < SitePrism::Section
      attr_accessor :parent_index,
                    :parent_path,
                    :parent_path_owner

      def labels
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-label")
      end

      def expands
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-expand .cornucopia-cell-more-data")
      end

      def mores
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .cornucopia-cell-more .cornucopia-cell-more-data")
      end

      def values
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .hide-contents")
      end

      def value_images
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .cornucopia-section-image")
      end

      def value_links
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .hide-contents > a")
      end

      def value_frames
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .padded-frame > iframe")
      end

      def value_textareas
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .padded-frame > textarea")
      end

      def sub_tables
        index = 1
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .cornucopia-table").map do |element|
          table                   = TableSection.new self, element
          table.parent_index      = index
          table.parent_path       = "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-cell-data > .cornucopia-table"
          table.parent_path_owner = parent_path_owner
          index                   += 1
          table
        end
      end
    end

    class TableSection < SitePrism::Section
      attr_accessor :parent_index,
                    :parent_path,
                    :parent_path_owner

      def rows
        index = 1

        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-row").map do |element|
          row                   = RowSection.new self, element
          row.parent_index      = index
          row.parent_path       = "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-row"
          row.parent_path_owner = parent_path_owner
          index                 += 1

          row
        end
      end
    end

    class MoreDetailsSection < SitePrism::Section
      element :show_hide, "a.cornucopia-additional-details"

      def details
        table                   = TableSection.new self, send(:all, "div.cornucopia-additional-details > .cornucopia-table").first
        table.parent_index      = 1
        table.parent_path       = "div.cornucopia-additional-details > .cornucopia-table"
        table.parent_path_owner = self

        table
      end
    end

    class ErrorSection < SitePrism::Section
      attr_accessor :parent_index,
                    :parent_path,
                    :parent_path_owner

      element :name, ".cornucopia-section-label"
      section :more_details, MoreDetailsSection, ".cornucopia-show-hide-section"

      def tables
        index = 2
        parent_path_owner.send(:find_all, "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-table").map do |element|
          table                   = TableSection.new self, element
          table.parent_index      = index
          table.parent_path       = "#{parent_path}:nth-child(#{parent_index}) > .cornucopia-table"
          table.parent_path_owner = parent_path_owner
          index                   += 1
          table
        end
      end
    end

    sections :all_errors, ErrorSection, ".cornucopia-section"

    def errors
      unless defined?(@all_errros)
        @errors ||= all_errors

        @errors.each_with_index do |error, index|
          error.parent_index      = index + 1
          error.parent_path       = ".cornucopia-section"
          error.parent_path_owner = self
        end
      end
    end
  end
end