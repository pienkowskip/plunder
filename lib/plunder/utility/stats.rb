require 'csv'
require 'time'
require_relative '../../illegal_state_error'

module Plunder::Utility
  module Stats
    TIMESTAMP_FORMAT = '%FT%T.%6N'

    def stat(*columns)
      csv = Plunder::Utility::Stats.csv_output
      return if csv.nil?
      raise ArgumentError, 'Empty stats row.' if columns.empty?
      time = Time.now.strftime(TIMESTAMP_FORMAT)
      csv.puts(columns.unshift(time, $$))
      csv.flush
      self
    end

    def self.setup(stats_io)
      @csv_output = CSV.new(stats_io)
      self
    end

    def self.csv_output
      @csv_output
    end
  end
end