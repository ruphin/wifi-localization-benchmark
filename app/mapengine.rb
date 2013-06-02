require './logging.rb'

module Engine

  LOG10 = Math.log(10)
  class Map

    # The random stream object used to acquire random numbers.
    @random_stream

    @map_width
    @map_height
    @logger

    @access_points

    # map_width and map_height in meters.
    def initialize(map_width=200, map_height=200, random_seed=nil, logger=nil)
      if logger == nil
        @logger = Logging.getLogger(:MapEngine)
        @logger.add_handler(Logging.ConsoleHandler)
        @logger.add_handler(Logging.FileHandler("MapEngine"))
      else
        @logger = logger
      end

      @logger.info("Initializing MapEngine")
      @logger.data(:MapEngine, :initialize, "#{(method(__method__).parameters.map { |arg| eval(arg[1].to_s) }).join("|")}")
      
      if random_seed
        @logger.info("Creating RandomStream with seed: #{random_seed}")
        @random_stream = Random.new(random_seed)
      else
        @random_stream = Random.new
        @logger.info("Creating RandomStream with random seed: #{@random_stream.seed}")
        @logger.data(:MapEngine, :seed, @random_stream.seed)
      end

      @map_width = map_width
      @map_height = map_height
      @access_points = []
    end

    def seed(random_seed)
      @logger.info("Overriding RandomStream with seed: #{random_seed}")
      @logger.data(:MapEngine, :seed, "#{random_seed}")
      @random_stream = Random.new(random_seed)
    end

    def add_access_point(pos_x, pos_y)
      @logger.data(:MapEngine, :add_access_point, "#{(method(__method__).parameters.map { |arg| eval(arg[1].to_s) }).join("|")}")
      @access_points.push AccessPoint.new(pos_x, pos_y)
    end

    # Specify x_min, x_max, y_min, y_max to force the random point to appear within this area.
    # Defaults to the complete map area.
    def add_random_access_point(x_min=0, x_max=@map_width, y_min=0, y_max=@map_height)
      pos_x = @random_stream.rand(x_min..x_max.to_f)
      pos_y = @random_stream.rand(y_min..y_max.to_f)
      @logger.debug("Creating Access Point at (#{pos_x},#{pos_y})")
      @logger.data(:MapEngine, :add_random_access_point, "#{(method(__method__).parameters.map { |arg| eval(arg[1].to_s) }).join("|")}")
      @access_points.push AccessPoint.new(pos_x, pos_y)
    end

    # Remove all access points in the specified area.
    def clear_access_points(x_min, x_max, y_min, y_max)
      @logger.data(:MapEngine, :clear_access_points, "#{(method(__method__).parameters.map { |arg| eval(arg[1].to_s) }).join("|")}")
      @access_points.select! {|ap| ap.x < x_min && ap.x > x_max && ap.y < y_min && ap.y > y_max}
    end

    def remove_access_point(id)
      @logger.data(:MapEngine, :remove_access_point, "#{(method(__method__).parameters.map { |arg| eval(arg[1].to_s) }).join("|")}")
      @access_points.reject! {|ap| ap.id == id}
    end

    def remove_random_access_point
      @logger.data(:MapEngine, :remove_random_access_point, "#{(method(__method__).parameters.map { |arg| eval(arg[1].to_s) }).join("|")}")
      @access_points.delete_at(@random_stream.rand(0..(@access_points.length-1)))
    end

    def read(pos_x, pos_y)
      @logger.data(:MapEngine, :read, "#{(method(__method__).parameters.map { |arg| eval(arg[1].to_s) }).join("|")}")
      @logger.debug("Reading at position (#{pos_x},#{pos_y})")
      response = []
      @access_points.each do |ap|
        distance = distance(ap, pos_x, pos_y)
        if signal_received?(distance)
          response.push [ap.id, signal_strength(distance)]
        end
      end
      return response
    end

    def dump
      return @access_points.collect { |ap| ap.dump }
    end

    private 

    # Returns the distance between an access point and given coordinates in meters
    def distance(access_point, pos_x, pos_y)
      Math.hypot(access_point.x - pos_x, access_point.y - pos_y)
    end

    # Returns a boolean indicating if a signal is received at the given distance in meters.
    # Based on figure 2 from http://research.microsoft.com/en-us/um/people/jckrumm/publications%202005/irs-tr-05-003.pdf
    def signal_received?(distance)
      @logger.debug("Determining if signal is heard at distance #{distance}")
      @logger.data(:MapEngine, :signal_received?, distance)
      return @random_stream.rand < 1.3 - Math.log((distance/28.0) + 1)
    end

    def signal_strength(distance)
      rss = distance_to_rss(distance)
      return randomize_signal_strength(rss)
    end

    # Distance to signal strength calculation based on log-distance path loss model. Variables adapted to match the graph in http://research.microsoft.com/en-us/um/people/jckrumm/publications%202005/irs-tr-05-003.pdf
    def distance_to_rss(distance)
      @logger.debug("Transforming distance to rss")
      return - 65 - (10 * Math.log(distance) / LOG10)
    end

    # According to http://gicl.cs.drexel.edu/people/regli/Classes/CS680/Papers/Localization/01331706.pdf
    # The weaker the signal, the larger our standard deviation. This makes sense, because at strong signals, the distance is inverse logarithmically related to the signal strength.
    #
    # We use a gaussian random distribution with the following standard deviation: http://www.wolframalpha.com/input/?i=0.0497+*+x+%2B+6.3438%2C+x+from+-100+to+-20
    def randomize_signal_strength(rss)
      @logger.debug("Randomizing signal strength at #{rss}")
      @logger.data(:MapEngine, :randomize_signal_strength, rss)
      stddev = 0.0497 * rss + 6.3438
      theta = 2 * Math::PI * @random_stream.rand
      rho = Math.sqrt(-2 * Math.log(1 - @random_stream.rand))
      scale = stddev * rho
      return rss + scale * Math.sin(theta)
    end
  end

  class AccessPoint

    @@id = 0

    def initialize(pos_x, pos_y)
      @id = @@id
      @@id += 1
      @pos_x = pos_x
      @pos_y = pos_y
    end

    def id
      return @id
    end

    def x
      return @pos_x
    end

    def y
      return @pos_y
    end

    def dump
      return [@id, @pos_x, @pos_y]
    end
  end
end