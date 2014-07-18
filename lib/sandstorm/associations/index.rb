require 'sandstorm/records/key'

# NB index instances are all internal to sandstorm, not user-accessible

module Sandstorm
  module Associations
    class Index

      def initialize(parent, class_key, att)
        @indexers = {}

        @backend   = parent.send(:backend)
        @parent    = parent
        @class_key = class_key
        @attribute = att
      end

      def value=(value)
        @value = value
      end

      def delete_id(id)
        return unless indexer = indexer_for_value

        @backend.delete(indexer, id)
      end

      def add_id(id)
        return unless indexer = indexer_for_value

        @backend.add(indexer, id)
      end

      def move_id(id, indexer_to)
        return unless indexer = indexer_for_value

        @backend.move(indexer, indexer_to.key, id)
      end

      def key
        indexer_for_value
      end

      private

      def indexer_for_value
        index_key = case @value
        when String, Symbol, TrueClass, FalseClass
          @value.to_s.gsub(/ /, '%20').gsub(/:/, '%3A')
        end
        return if index_key.nil?

        @indexers[index_key] ||= Sandstorm::Records::Key.new(
          :class  => @class_key,
          :name   => "by_#{@attribute}:#{index_key}",
          :type   => :set,
          :object => :index
        )
      end

    end
  end
end