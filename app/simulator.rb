#!/usr/bin/env ruby

require './logging.rb'
require './mapengine.rb'
require './fingerprinting.rb'
require './centroid.rb'
require 'optparse'
#require 'tk'

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
    @measurement_border = 75
    if @measurement_border * 2 > @mapsize
      @logger.warn("Testing area too small. Increase mapsize to get results.")
    end
    @test_area = @measurement_border..(@mapsize - @measurement_border).to_f
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

  # Accuracy in number of coordinates scanned per map dimension
  def field_scan(accuracy)
    distance = (@mapsize - @measurement_border) / accuracy.to_f
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

  # Accuracy in number of coordinates tested per map dimension
  def field_test(accuracy)
    distance = (@mapsize - @measurement_border) / accuracy.to_f
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


options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: simulator.rb [options]"

  opts.on("-g", "--graph", "Render Graphs. Requires tk/tcl") do |g|
    options[:graph] = g
  end

  opts.on(:REQUIRED, "-mMAPSIZE", "--mapsize=MAPSIZE", OptionParser::DecimalInteger, "Map size (300)" ) do |m|
    options[:mapsize] = m
  end

  opts.on(:REQUIRED, "-dDENSITY", "--density=DENSITY", OptionParser::DecimalInteger, "Node density (15)" ) do |m|
    options[:density] = m
  end

  opts.on(:REQUIRED, "-aACCURACY", "--accuracy=ACCURACY", OptionParser::DecimalInteger, "Test accuracy (100)" ) do |m|
    options[:accuracy] = m
  end

  opts.on(:REQUIRED, "-iITERATIONS", "--iterations=ITERATIONS", OptionParser::DecimalInteger, "Test iterations (100)" ) do |m|
    options[:iterations] = m
  end

end.parse!

NODE_COUNT = options[:mapsize]**2 / 10000 * options[:density]

null_logger = Logging::getLogger(:NULL)
logger = Logging::getLogger(:console)
logger.add_handler(Logging.FileHandler("DATA-#{options[:mapsize]}-#{options[:density]}-#{options[:accuracy]}-#{options[:iterations]}", :info, false))
sim = Simulator.new(options[:mapsize], Random.new_seed, logger)
sim.add_static_algorithm(Localization::Fingerprinting.new(null_logger))
sim.add_static_algorithm(Localization::Centroid.new(null_logger))
sim.add_learning_algorithm(Localization::Fingerprinting.new(null_logger))
sim.add_learning_algorithm(Localization::Centroid.new(null_logger))

sim.create_access_points(NODE_COUNT)
sim.field_scan(options[:accuracy]*2.5)

(1..options[:iterations]).each do |step|
  p step
  logger.info("STEP:#{step}")
  logger.info("ORIGINAL-APS:#{ sim.dump.map { |id, _, _| id }.select { |id| id < NODE_COUNT }.size }")
  logger.info("AP-SET:#{ sim.dump }")
  sim.field_test(options[:accuracy]/5.0)
  sim.errors
  sim.change(2*(NODE_COUNT/options[:iterations]))
end

if options[:graph]
  require 'tk'
  sim.draw
end

