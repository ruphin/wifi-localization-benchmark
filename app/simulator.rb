#!/usr/bin/env ruby

require './logging.rb'
require './mapengine.rb'
require './fingerprinting.rb'
require './centroid.rb'
require 'tk'

class Range
  def float_step(float)
    if self.begin.is_a?(Numeric) && self.end.is_a?(Numeric)
      num = self.begin
      while num <= self.end
        yield num
        num += float
      end
    end
  end
end

class Simulator

  # mapsize in meters.
  def initialize(mapsize, random_seed = Random.new_seed, logger = nil)
    @mapsize = mapsize
    @learning_algorithms = []
    @static_algorithms = []

    if logger == nil
      @logger = Logging.getLogger(:Simulator)
      @logger.add_handler(Logging.ConsoleHandler(:info))
      @logger.add_handler(Logging.FileHandler("Simulator"))
    else
      @logger = logger
    end

    # We don't make any measurements at the border perimeter of the map to make sure every measurement has potential access points in all directions
    measurement_border = 75
    if measurement_border * 2 > mapsize
      @logger.warn("Testing area too small. Increase mapsize to get results.")
    end
    @test_area = measurement_border..(mapsize - measurement_border).to_f
    @map = Engine::Map.new(@mapsize, @mapsize, random_seed , @logger)
  end

  def create_access_points(amount)
    amount.times do
      @map.add_random_access_point
    end
  end

  def algorithms
    return @static_algorithms + @learning_algorithms
  end

  def add_static_algorithm(algorithm)
    @static_algorithms.push algorithm
  end

  def add_learning_algorithm(algorithm)
    @learning_algorithms.push algorithm
  end

  # distance in meters between each individual measurements
  def field_scan(distance)
    @test_area.float_step(distance) do |x|
      @test_area.float_step(distance) do |y|
        signals = @map.read(x,y)
        algorithms.each do |a|
          a.feed(x, y, signals)
        end
      end
    end
  end

  def change(number)
    number.times do
      @map.remove_random_access_point
      @map.add_random_access_point
    end
  end

  def field_test(distance)
    locations = []
    @test_area.float_step(distance) do |x|
      @test_area.float_step(distance) do |y|
        locations.push [x, y]
      end
    end
    locations.shuffle.each do |l|
      test(*l)
    end
  end

  def test(x=Kernel.rand(@test_area), y=Kernel.rand(@test_area))
    signals = @map.read(x, y)
    @static_algorithms.each do |a|
      result = a.read(signals)
      if result == [-1,-1]
        @logger.debug("No match for #{a.class.name} at (#{x},#{y})")
      else
        error = Math.hypot(result.first - x, result.last - y)
        a.add_error error
        @logger.debug("Error for #{a.class.name} at (#{x},#{y}): #{error}")
      end
    end
    @learning_algorithms.each do |a|
      result = a.read(signals)
      if result == [-1, -1]
        @logger.debug("No match for Learning #{a.class.name} at (#{x},#{y})")
      else
        error = Math.hypot(result.first - x, result.last - y)
        a.add_error error
        @logger.debug("Error for Learning #{a.class.name} at (#{x},#{y}): #{error}")
        a.feed(*result, signals)
      end
    end
  end

  def errors
    @static_algorithms.each do |a|
      @logger.info("Error for #{a.class.name}: #{a.cumulative_error}")
      @logger.info("Misses for #{a.class.name}: #{a.localization_misses}")

    end

    @learning_algorithms.each do |a|
      @logger.info("Error for Learning #{a.class.name}: #{a.cumulative_error}")
      @logger.info("Misses for Learning #{a.class.name}: #{a.localization_misses}")
    end
  end

  CANVAS_BORDER = 5
  def draw
    canvas = TkCanvas.new(:width=>@mapsize + CANVAS_BORDER, :height=>@mapsize + CANVAS_BORDER).pack

    positions = @map.dump.map { |_, x, y, _| [x,y] }

    (0..@mapsize).step(100) do |line|
      TkcLine.new(canvas, CANVAS_BORDER , line + CANVAS_BORDER, @mapsize + CANVAS_BORDER, line + CANVAS_BORDER, :fill => 'grey', :dash => '-')
      TkcLine.new(canvas, line + CANVAS_BORDER , CANVAS_BORDER, line + CANVAS_BORDER, @mapsize + CANVAS_BORDER, :fill => 'grey', :dash => '-')
    end

    positions.each do |x, y|
      TkcOval.new(canvas, x+5, y+5, x+5, y+5, :fill=>'black', :outline=>'black')
    end

    Tk.mainloop
  end

  def dump
    return @map.dump
  end
end

# MAP SIZE in meters
MAP_SIZE = ARGV.shift.to_i

# NODE DENSITY in nodes per hectare (10000m^2)
NODE_DENSITY = ARGV.shift.to_i

NODE_COUNT = MAP_SIZE**2 / 10000 * NODE_DENSITY

null_logger = Logging::getLogger(:NULL)
logger = Logging::getLogger(:console)
logger.add_handler(Logging.FileHandler("DATA-#{MAP_SIZE}-#{NODE_DENSITY}", :info, false))
sim = Simulator.new(MAP_SIZE, Random.new_seed, logger)
sim.add_static_algorithm(Localization::Fingerprinting.new(null_logger))
sim.add_static_algorithm(Localization::Centroid.new(null_logger))
sim.add_learning_algorithm(Localization::Fingerprinting.new(null_logger))
sim.add_learning_algorithm(Localization::Centroid.new(null_logger))

sim.create_access_points(NODE_COUNT)
sim.field_scan(MAP_SIZE/250.0)

(1..50).each do |step|
  p step
  logger.info("STEP:#{step}")
  sim.change(NODE_COUNT/25)
  logger.info("ORIGINAL-APS:#{ sim.dump.map { |id, _, _| id }.select { |id| id < NODE_COUNT }.size }")
  logger.info("AP-SET:#{ sim.dump }")
  sim.field_test((MAP_SIZE-150)/20.0)
  sim.errors
end

sim.draw

