require 'active_support/concern'

require 'sandstorm/records/base'

# a record is a row in a time series (named for the record class)

# all attributes are stored as fields in that row

# a save will delete (if required) and create the row

# if time field does not exist, this will be created automatically by influxdb

# indexing -- not really relevant until query building has been worked on, but
# everything in the influxdb query language should be supportable, maybe those
# just indicate what should be queryable?

# TODO: ensure time_precision is set for the incoming data

# class level values are in other time series (with similar names to the
# related redis sets)

module Sandstorm
  module Records
    module InfluxDBRecord
      extend ActiveSupport::Concern

      include Sandstorm::Records::Base

      included do
        set_backend :influxdb

        # define_attributes :time             => :timestamp
                          # :sequence_number  => :float

      end

      def save
        # raise 'InfluxDB records cannot be updated' if persisted? ||
        #   (!id.nil? && self.class.exists?(id))

        super
      end

      def destroy
        raise 'InfluxDB records cannot be destroyed' if persisted? ||
          (!id.nil? && self.class.exists?(id))
        super
      end
    end
  end
end
