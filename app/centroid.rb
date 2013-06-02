require './logging.rb'
require './mapengine.rb'
require 'benchmark'

module Localization
  class Centroid

    # Map of all access points
    # { ID => [[x_positions], [y_positions]] }
    # x_positions and y_positions are arrays of positions for this access point
    #
    #
    @map
    def initialize(logger=nil)
      @map = Hash.new { |hash, key| hash[key] = {x: [], y: [], position: nil} }
      @cumulative_error = 0
      @localization_misses = 0
      if logger == nil
        @logger = Logging.getLogger(:Centroid)
        @logger.add_handler(Logging.ConsoleHandler)
        @logger.add_handler(Logging.FileHandler("Centroid"))
      else
        @logger = logger
      end
    end

    def add_error error
      @cumulative_error += error
    end

    def cumulative_error
      return @cumulative_error
    end

    def localization_misses
      return @localization_misses
    end

    # Enters a set of received signals at a specific location into the system 
    def feed(pos_x, pos_y, signals)
      signals.each do |id, _|
        @map[id][:x].push pos_x
        @map[id][:y].push pos_y

        x = @map[id][:x].reduce(:+) / @map[id][:x].size.to_f
        y = @map[id][:y].reduce(:+) / @map[id][:x].size.to_f
        @map[id][:position] = {x: x, y: y}
      end
    end

    # Returns an estimated location based on the perceived signals
    def read(signals)
      
      positions = signals.map { |id, _| @map[id][:position] }.reject { |p| p.nil? }
      if positions.size == 0
        @localization_misses += 1
        return [-1,-1]
      else
        x = positions.map { |p| p[:x] }.reduce(:+) / positions.size.to_f
        y = positions.map { |p| p[:y] }.reduce(:+) / positions.size.to_f
        return [x, y]
      end
    end
  end
end
