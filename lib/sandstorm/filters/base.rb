require 'active_support/concern'

require 'sandstorm/records/errors'

require 'sandstorm/filters/step'

module Sandstorm

  module Filters

    module Base

      extend ActiveSupport::Concern

      attr_reader :backend

      # initial set         a Sandstorm::Record::Key object
      # associated_class    the class of the result record
      def initialize(data_backend, initial_set, associated_class)
        @backend          = data_backend
        @initial_set      = initial_set
        @associated_class = associated_class
        @steps            = []
      end

      # # TODO implement
      # # will probably need to scan and extract the last usage from steps
      # def limit(amount)
      #   @steps << Sandstorm::Filters::Step.new(:limit, {:amount => amount}, {})
      #   self
      # end

      def sort(att, opts = {})
        @steps << ::Sandstorm::Filters::Step.new(:sort, {:key => att, :order => opts.delete(:order)}, {})
        self
      end

      def intersect(attrs = {})
        @steps << ::Sandstorm::Filters::Step.new(:intersect, {}, attrs)
        self
      end

      def union(attrs = {})
        @steps << ::Sandstorm::Filters::Step.new(:union, {}, attrs)
        self
      end

      def diff(attrs = {})
        @steps << ::Sandstorm::Filters::Step.new(:diff, {}, attrs)
        self
      end

      def intersect_range(start, finish, attrs_opts = {})
        @steps << ::Sandstorm::Filters::Step.new(:intersect_range, {:start => start, :finish => finish,
          :order => attrs_opts.delete(:order),
          :by_score => attrs_opts.delete(:by_score)}, attrs_opts)
        self
      end

      def union_range(start, finish, attrs_opts = {})
        @steps << ::Sandstorm::Filters::Step.new(:union_range, {:start => start, :finish => finish,
          :order => attrs_opts.delete(:order),
          :by_score => attrs_opts.delete(:by_score)}, attrs_opts)
        self
      end

      def diff_range(start, finish, attrs_opts = {})
        @steps << ::Sandstorm::Filters::Step.new(:diff_range, {:start => start, :finish => finish,
          :order => attrs_opts.delete(:order),
          :by_score => attrs_opts.delete(:by_score)}, attrs_opts)
        self
      end

      # step users
      def exists?(e_id)
        lock(false) { _exists?(e_id) }
      end

      def find_by_id(f_id)
        lock { _find_by_id(f_id) }
      end

      def find_by_id!(f_id)
        ret = lock { _find_by_id(f_id) }
        raise ::Sandstorm::Records::Errors::RecordNotFound.new(@associated_class, f_id) if ret.nil?
        ret
      end

      def find_by_ids(*f_ids)
        lock { f_ids.collect {|f_id| _find_by_id(f_id) } }
      end

      def find_by_ids!(*f_ids)
        ret = lock { f_ids.collect {|f_id| _find_by_id(f_id) } }
        unless f_ids.length.eql?(ret.length)
          raise ::Sandstorm::Records::Errors::RecordsNotFound.new(@associated_class, f_ids - ret.map(&:id))
        end
        ret
      end

      def ids
        lock(false) { _ids }
      end

      def count
        lock(false) { _count }
      end

      def empty?
        lock(false) { _count == 0 }
      end

      def all
        lock { _all }
      end

      def collect(&block)
        lock { _ids.collect {|id| block.call(_load(id))} }
      end

      def each(&block)
        lock { _ids.each {|id| block.call(_load(id)) } }
      end

      def select(&block)
        lock { _all.select {|obj| block.call(obj) } }
      end
      alias_method :find_all, :select

      def reject(&block)
        lock { _all.reject {|obj| block.call(obj)} }
      end

      def destroy_all
        lock(*@associated_class.send(:associated_classes)) { _all.each {|r| r.destroy } }
      end

      protected

      def lock(when_steps_empty = true, *klasses, &block)
        if !when_steps_empty && @steps.empty?
          return block.call
        end
        klasses += [@associated_class] if !klasses.include?(@associated_class)
        @backend.lock(*klasses, &block)
      end

      private

      def _find_by_id(id)
        if !id.nil? && _exists?(id)
          _load(id.to_s)
        else
          nil
        end
      end

      def _load(id)
        object = @associated_class.new
        object.load(id)
        object
      end

      def _all
        _ids.map {|id| _load(id) }
      end

    end

  end

end
