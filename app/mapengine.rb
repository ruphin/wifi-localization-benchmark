require './logging.rb'

class MapEngine

  # Minimum distance between map coordinates in Millimeters
  @granularity 

  # The random stream object used to acquire random numbers.
  @random_stream

  @map_size_x
  @map_size_y
  @logger

  def initialize(map_size_x=1000, map_size_y=1000, granularity=10, random_seed=nil, logger=nil)
    if logger == nil
      @logger = Logging.getLogger("MapEngine")
      @logger.add_handler(Logging.ConsoleHandler)
    else
      @logger = logger
    end

    @logger.info("Initializing MapEngine")
    @logger.data(:MapEngine, :initialize, "#{map_size_x}|#{map_size_y}|#{granularity}|#{random_seed}")
    
    if random_seed
      @logger.info("Creating RandomStream with seed: #{seed}")
      @logger.data(:seed, random_seed)
      @random_stream = Random.new(random_seed)
    else
      @random_stream = Random.new
      @logger.info("Creating RandomStream without seed")
    end
  end
end