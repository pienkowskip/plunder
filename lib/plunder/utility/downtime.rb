require 'date'
require_relative '../../illegal_state_error'

module Plunder::Utility
  class Downtime
    class Break
      CONFIDENCE_FACTOR = 3

      attr_reader :begin_mean, :begin_stddev, :duration_mean, :duration_stddev

      def initialize(begin_mean, begin_stddev, duration_mean, duration_stddev)
        raise ArgumentError, 'Not numeric break parameter.' unless [begin_mean, begin_stddev, duration_mean, duration_stddev].all? { |arg| arg.is_a?(Numeric) }
        raise ArgumentError, 'Break beginning (mean: %s, stddev: %s) has a chance to happen a day earlier.' % [begin_mean, begin_stddev] if begin_mean - CONFIDENCE_FACTOR * begin_stddev < -24 * 3600
        raise ArgumentError, 'Break duration (mean: %s, stddev: %s) has a chance to be negative.' % [duration_mean, duration_stddev] if duration_mean - CONFIDENCE_FACTOR * duration_stddev < 0
        @begin_mean, @begin_stddev, @duration_mean, @duration_stddev = begin_mean, begin_stddev, duration_mean, duration_stddev
      end

      def create(date, random)
        date = date.to_time
        beg = date + apply_min(random.gauss_rand(begin_mean, begin_stddev), -24 * 3600)
        return beg, beg + apply_min(random.gauss_rand(duration_mean, duration_stddev), 0)
      end

      private

      def apply_min(value, min)
        value < min ? min : value
      end
    end

    def initialize(random, *breaks)
      @random = random
      @generated_until = nil
      @cleared_until = nil
      @generated_breaks = []
      @breaks = breaks.map { |br| br.is_a?(Break) ? br.freeze : Break.new(*br).freeze }
      @breaks.sort_by! { |br| br.begin_mean }
      @breaks.freeze
      generate_until(Date.today)
    end

    def shift(time)
      raise ArgumentError, 'Argument \'time\' is not instance of Time class.' unless time.is_a?(Time)
      raise IllegalStateError, 'Breaks are cleared until [%s].' % @cleared_until if time < @cleared_until
      generate_until(time.to_date)
      @generated_breaks.reverse_each do |b, e|
        if time >= b && time < e
          time = e
          break
        end
      end
      time
    end

    private

    def generate_until(date)
      return if !@generated_until.nil? && @generated_until >= date

      @generated_until = date - 2 if @generated_until.nil?
      while @generated_until < date
        @generated_until += 1
        @breaks.each { |br| @generated_breaks.push(br.create(@generated_until + 1, @random)) }
      end

      @generated_breaks.sort_by! { |_, e| e }

      begin
        last = nil
        @generated_breaks.map! do |elm|
          if last && elm[0] < last[1]
            last[0] = elm[0] if elm[0] < last[0]
            last[1] = elm[1]
            nil
          else
            last = elm
          end
        end
      end while @generated_breaks.compact!

      clear_until(Date.today.to_time)
    end

    def clear_until(time)
      @generated_breaks.reject! do |_, e|
        break if e > time
        true
      end
      @cleared_until = time
    end
  end
end