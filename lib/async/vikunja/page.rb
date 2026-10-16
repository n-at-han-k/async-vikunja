require_relative "representation"

module Async
  module Vikunja
    class Page < Representation
      include Enumerable

      MEMBER = Representation

      def items = Array(self.value[:items])

      def page = self.value[:page].to_i

      def per_page = self.value[:per_page].to_i

      def total = self.value[:total].to_i

      def total_pages = self.value[:total_pages].to_i

      def last? = self.page >= [self.total_pages, 1].max

      def empty? = self.items.empty?

      def each(&block)
        if block
          self.items.each do |record|
            block.call(self.member_for(record))
          end
        else
          self.to_enum(:each)
        end
      end

      def member_class = self.class::MEMBER

      def member_path(record) = Vikunja.escape(record[:id])

      def member_resource(record)
        @resource.with(path: self.member_path(record), parameters: nil, merge: false)
      end

      def member_for(record)
        self.member_class.new(self.member_resource(record), value: record, metadata: self.metadata)
      end
    end

    class Collection
      include Enumerable

      DEFAULT_PER_PAGE = 50

      def self.for(parent, path, page_class, **parameters)
        self.new(parent.with(path: path, parameters: parameters), page_class)
      end

      def initialize(resource, page_class)
        @resource = resource
        @page_class = page_class
      end

      attr :resource

      attr :page_class

      def each_page(per_page: DEFAULT_PER_PAGE, &block)
        if block
          self.walk(per_page, &block)
        else
          self.to_enum(:each_page, per_page: per_page)
        end
      end

      def each(**options, &block)
        if block
          self.each_page(**options) do |page|
            page.each(&block)
          end
        else
          self.to_enum(:each, **options)
        end
      end

      def page(number, per_page: DEFAULT_PER_PAGE)
        @page_class.new(@resource.with(parameters: {page: number, per_page: per_page}))
      end

      def total
        self.page(1, per_page: 1).total
      end

      def walk(per_page, &block)
        number = 1

        while true
          page = self.page(number, per_page: per_page)

          if page.empty?
            break
          end

          block.call(page)

          if page.last?
            break
          end

          number += 1
        end
      end
    end
  end
end
