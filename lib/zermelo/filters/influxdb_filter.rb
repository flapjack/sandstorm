require 'zermelo/filters/base'

module Zermelo
  module Filters
    class InfluxDBFilter

      include Zermelo::Filters::Base

      private

      def _exists?(id)
        return if id.nil?
        @steps << Zermelo::Filters::Steps::SetStep.new({:op => :intersect}, {:id => id})
        resolve_steps(:count) > 0
      end

      def lock(when_steps_empty = true, *klasses, &block)
        # no-op
        block.call
      end

      def _ids
        resolve_steps(:ids)
      end

      def _count
        resolve_steps(:count)
      end

      def escaped_id(id)
        if id.is_a?(Numeric)
          id
        else
          "'" + id.gsub(/'/, "\\'").gsub(/\\/, "\\\\'") + "'"
        end
      end

      def resolve_steps(result_type)
        class_key = @associated_class.send(:class_key)

        query = case result_type
        when :ids
          "SELECT id FROM /#{class_key}\\/.*/"
        when :count
          "SELECT COUNT(id) FROM /#{class_key}\\/.*/"
        end

        unless @initial_key.id.nil?
          query += ' WHERE '

          initial_class_key = @initial_key.klass.send(:class_key)

          ii_query = "SELECT #{@initial_key.name} FROM \"#{initial_class_key}/#{@initial_key.id}\" " +
            "LIMIT 1"

          begin
            initial_id_data =
              Zermelo.influxdb.query(ii_query)["#{initial_class_key}/#{@initial_key.id}"]
          rescue InfluxDB::Error => ide
            raise unless
              /^Field #{@initial_key.name} doesn't exist in series #{initial_class_key}\/#{@initial_key.id}$/ === ide.message

            initial_id_data = nil
          end

          return [] if initial_id_data.nil?

          initial_ids = initial_id_data.first[@initial_key.name]

          if initial_ids.nil? || initial_ids.empty?
            # make it impossible for the query to return anything
            query += '(1 = 0)'
          else
            query += '((' + initial_ids.collect {|id|
              "id = #{escaped_id(id)}"
            }.join(') OR (') + '))'
          end
        end

        unless @steps.empty?
          query += (@initial_key.id.nil? ? ' WHERE ' : ' AND ') +
                   ('(' * @steps.size)

          first_step = steps.first

          query += @steps.collect {|step|
            step.resolve(backend, @associated_class, :first => (step == first_step))
          }.join("")
        end

        query += " LIMIT 1"

        begin
          result = Zermelo.influxdb.query(query)
        rescue InfluxDB::Error => ide
          raise unless /^Couldn't look up columns$/ === ide.message
          result = {}
        end

        data_keys = result.keys.select {|k| k =~ /^#{class_key}\// }

        case result_type
        when :ids
          data_keys.empty? ? [] : data_keys.collect {|k| k =~ /^#{class_key}\/(.+)$/; $1 }
        when :count
          data_keys.empty? ?  0 : data_keys.inject(0) do |memo, k|
            memo += result[k].first['count']
            memo
          end
        end
      end
    end
  end
end
