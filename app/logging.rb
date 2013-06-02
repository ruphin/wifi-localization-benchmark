module Logging

  LEVELS = { debug: 1, info: 2, warn: 3 }

  @loggers = {}

  class Logger

    def initialize
      @handlers = []
    end

    def add_handler(handler)
      @handlers.push handler
    end

    def debug(message)
      @handlers.each do |handler|
        handler.debug(message)
      end
    end

    def info(message)
      @handlers.each do |handler|
        handler.info(message)
      end
    end

    def warn(message)
      @handlers.each do |handler|
        handler.warn(message)
      end
    end

    def data(*tags, message)
      @handlers.each do |handler|
        handler.data(*tags, message)
      end
    end
  end

  class Handler

    def initialize(level, &proc)
      @level = Logging::LEVELS[level]
      @output_method = proc
      @tags = []
    end

    def closer(&proc)
      @close_method = proc
    end

    def close
      @close_method && @close_method.call
    end

    def log_level=(level)
      @level = Logging::LEVELS[level]
    end

    def log_data=(log_data)
      @data = log_data
    end

    def add_tag(tag)
      @tags.push(tag)
    end

    def debug(message)
      if @level <= Logging::LEVELS[:debug]
        @output_method.call("DBUG: #{message}")
      end
    end

    def info(message)  
      if @level <= Logging::LEVELS[:info]
        @output_method.call("INFO: #{message}")
      end
    end

    def warn(message)  
      if @level <= Logging::LEVELS[:warn]
        @output_method.call("WARN: #{message}")
      end
    end

    def data(*tags, message)
      if @data == true
        @output_method.call("DATA:#{(@tags + tags).join(".")}:#{message}")
      end
    end
  end

  def self.FileHandler(file_name, level=:warn, data=true)
    f = File.open("log/#{file_name}.log", 'w+')
    handler = Handler.new(level) { |message| f.puts("#{message}") }
    handler.closer { f.close }
    handler.log_data = data
    return handler
  end

  def self.ConsoleHandler(level=:debug, data=false)
    handler = Handler.new(level) { |message| puts message }
    handler.log_data = data
    return handler
  end

  def self.getLogger(name)
    if @loggers[name] == nil
      @loggers[name] = Logger.new
    end
    return @loggers[name]
  end
end

# Unit testing

if __FILE__ == $0

  require 'test/unit'
  class LoggingTest < Test::Unit::TestCase
    def test_creating_loggers
      test_logger = Logging.getLogger('test')
      other_logger = Logging.getLogger('other')
      assert_not_equal(test_logger, other_logger)

      test_logger_2 = Logging.getLogger('test')
      assert_equal(test_logger, test_logger_2)
    end

    def test_filehandler
      increment = 1
      while (FileTest.exists?("log/test.#{increment}.log"))
        increment += 1
      end
      file_handler = Logging.FileHandler('test')
      assert(FileTest.exists?("log/test.#{increment}.log"))
      file_handler.log_level = :debug
      file_handler.log_data = true
      file_handler.data(:flag, :second_flag, "testdata")
      file_handler.info("printing test data")
      file_handler.close
      f = File.open("log/test.#{increment}.log", 'r')
      assert_equal("DATA:flag.second_flag:testdata\n", f.gets)
      assert_equal("INFO: printing test data\n", f.gets)
      File.delete("log/test.#{increment}.log")
    end
  end
end