#!/usr/bin/env ruby

require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: simulator.rb [options]"

  opts.on("-g", "--graph", "Render Graphs. Requires tk/tcl") do |g|
    options[:graph] = g
  end
end.parse!

STEP = /INFO: STEP:(\d+)/
ORIGINALAPS = /INFO: ORIGINAL-APS:(\d+)/
APSET = /INFO: AP-SET:(.+)/
ERROR = /INFO: Error for Localization::(\w+): (.+)/
LEARNINGERROR = /INFO: Error for Learning Localization::(\w+): (.+)/
MISSES = /INFO: Misses for Localization::(\w+): (.+)/
LEARNINGMISSES = /INFO: Misses for Learning Localization::(\w+): (.+)/
LOGOPTIONS = /DATA-(\d+)-(\d+)-(\d+)-(\d+).log/

logfiles = `ls ./log/*.log`.split("\n")

logfiles.each do |filename|
  File.open(filename, "r") do |logfile|
    mapsize, density, accuracy, iterations = (LOGOPTIONS.match filename).captures.map(&:to_i)
    scans_per_iteration = (accuracy/5)**2
    dataset = []
    step = 0
    while (line = logfile.gets)
      if (data = (STEP.match line))
        step = data.captures.first.to_i - 1
        dataset[step] = {error:[], misses:[]}
      elsif (data = (ORIGINALAPS.match line))
        dataset[step][:originalaps] = data.captures.first.to_i
      elsif (data = (APSET.match line))
        dataset[step][:apset] = eval(data.captures.first)
      elsif (data = (ERROR.match line))
        dataset[step][:error].push [data.captures.first, data.captures.last.to_f]
      elsif (data = (LEARNINGERROR.match line))
        dataset[step][:error].push ["Learning " + data.captures.first, data.captures.last.to_f]
      elsif (data = (MISSES.match line))
        dataset[step][:misses].push [data.captures.first, data.captures.last.to_f]
      elsif (data = (LEARNINGMISSES.match line))
        dataset[step][:misses].push ["Learning " + data.captures.first, data.captures.last.to_f]
      end
    end
    File.open("#{filename}.data", 'w+') do |file|
      algorithms = dataset[0][:error].map(&:first)
      errors = dataset.map { |d| d[:error].map(&:last) }
      errors = errors.zip( [Array.new(errors.first.size, 0)] + errors).map { |a, b| a.zip(b).map { |c, d| c - d }}
      misses = dataset.map { |d| d[:misses].map(&:last) }
      misses = misses.zip( [Array.new(misses.first.size, 0)] + misses).map { |a, b| a.zip(b).map { |c, d| c - d }}
      average_error = errors.zip(misses).map { |a, b| a.zip(b).map {|c, d| c / (scans_per_iteration - d) }}


      file.puts "#{mapsize}\t#{density}\t#{accuracy}\t#{iterations}"
      file.puts ""
      file.puts "step\toriginal-aps\t#{algorithms.join("\t")}\t#{algorithms.join("\t")}"
      dataset.each_with_index do |d, s|
        file.puts "#{s+1}\t#{d[:originalaps]}\t#{average_error[s].join("\t")}\t#{misses[s].join("\t")}"
      end
    end
  end
end


if options[:graph]
  require 'tk'

end