require 'pqueue'

module Plunder::Utility
  class Scheduler
    def initialize
      @queue = PQueue.new { |a,b| b[1] <=> a[1] }
    end

    def add_task(task, at)
      raise ArgumentError, 'Argument \'task\' is not callable (absence of call method).' unless task.respond_to?(:call)
      raise ArgumentError, 'Argument \'at\' is not instance of Time class.' unless at.is_a?(Time)
      @queue.push([task, at].freeze)
    end

    def execute_next_task
      raise StopIteration, 'No tasks to execute.' if empty?
      now = Time.new
      sleep next_task_at - now if next_task_at > now
      task = @queue.pop[0]
      task.call
    end

    def next_task_at
      @queue.top[1]
    end

    def empty?
      @queue.empty?
    end
  end
end