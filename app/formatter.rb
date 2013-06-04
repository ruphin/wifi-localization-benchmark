#!/usr/bin/env ruby

require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: simulator.rb [options]"

  opts.on("-g", "--graph", "Render Graphs. Requires tk/tcl") do |g|
    options[:graph] = g
  end
end.parse!

GNUPLOT_TEMPLATE = <<-eos
#!/opt/local/bin/gnuplot
# gnuplot 4.2 / Ubuntu 8.10 
 
#input
set datafile separator ";"
 
#output
set key top left
set style data linespoints
set grid

set ytics nomirror
 
set xlabel 'Access Points Remaining'
set xtics 10
set autoscale x
set xrange [100:10]
set format x "%g%%"

set term svg size 600,400 font "Arial,10"

eos

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
        if data.captures.first == "Centroid"
          dataset[step][:error][0] = [data.captures.first, data.captures.last.to_f]
        else
          dataset[step][:error][2] = [data.captures.first, data.captures.last.to_f]
        end
      elsif (data = (LEARNINGERROR.match line))
        if data.captures.first == "Centroid"
          dataset[step][:error][1] = ["Learning " + data.captures.first, data.captures.last.to_f]
        else
          dataset[step][:error][3] = ["Learning " + data.captures.first, data.captures.last.to_f]
        end

      elsif (data = (MISSES.match line))
        if data.captures.first == "Centroid"
          dataset[step][:misses][0] = [data.captures.first, data.captures.last.to_f]
        else
          dataset[step][:misses][2] = [data.captures.first, data.captures.last.to_f]
        end

      elsif (data = (LEARNINGMISSES.match line))
        if data.captures.first == "Centroid"
          dataset[step][:misses][1] = ["Learning " + data.captures.first, data.captures.last.to_f]
        else
          dataset[step][:misses][3] = ["Learning " + data.captures.first, data.captures.last.to_f]
        end
      end
    end

    algorithms = dataset[0][:error].map(&:first)
    original_aps = dataset[0][:originalaps].to_f
    errors = dataset.map { |d| d[:error].map(&:last) }
    errors = errors.zip( [Array.new(errors.first.size, 0)] + errors).map { |a, b| a.zip(b).map { |c, d| c - d }}
    misses = dataset.map { |d| d[:misses].map(&:last) }
    misses = misses.zip( [Array.new(misses.first.size, 0)] + misses).map { |a, b| a.zip(b).map { |c, d| c - d }}
    average_error = errors.zip(misses).map { |a, b| a.zip(b).map {|c, d| c / (scans_per_iteration - d) }}
    percentage_misses = misses.map { |m| m.map { |a| a / scans_per_iteration }}

    File.open("#{filename}.data", 'w+') do |file|
      file.puts "#{mapsize}\t#{density}\t#{accuracy}\t#{iterations}"
      file.puts ""
      file.puts "step\taps-remaining\t#{algorithms.map {|a| a + " error"}.join("\t")}\t#{algorithms.map {|a| a + " misses"}.join("\t")}"
      dataset.each_with_index do |d, s|
        file.puts "#{s+1}\t#{d[:originalaps]/original_aps}\t#{average_error[s].join("\t")}\t#{misses[s].join("\t")}"
      end
    end
    File.open("#{filename}.accuracy.gnuplot", 'w+') do |file|
      file.puts GNUPLOT_TEMPLATE

      file.puts "set output 'image/#{mapsize}-#{density}-#{accuracy}-#{iterations}-accuracy.svg'"

      file.puts "set ylabel 'Average Localization Error'"
      file.puts "set ytics 5"
      file.puts "set yrange [10:#{average_error.flatten.max + 5}]"
      file.puts "set format y '%g '"

      file.print "plot "
      file.puts algorithms.map { |a| " '-' using 1:($2) title '#{a}' axes x1y1 lt rgb 'black'" }.join(",")
      file.puts average_error.zip( dataset.map { |e| e[:originalaps]/original_aps * 100 }).map { |a, b| a.map { |c| "#{b};#{c}" }}.transpose.map { |a| a.join("\n")}.join("\ne\n")
      file.puts "e"
    end
    File.open("#{filename}.misses.gnuplot", 'w+') do |file|
      file.puts GNUPLOT_TEMPLATE

      file.puts "set output 'image/#{mapsize}-#{density}-#{accuracy}-#{iterations}-error.svg'"


      file.puts "set ylabel 'Localization Miss Percentage'"
      file.puts "set ytics 10"
      file.puts "set autoscale y"
      file.puts "set yrange [0:#{percentage_misses.flatten.max * 100 + 10}]"
      file.puts "set format y '%g%%'"


      file.print "plot"
      file.puts algorithms.map { |a| " '-' using 1:($2*100) title '#{a}' axes x1y1 lt rgb 'black'" }.join(",")
      file.puts percentage_misses.zip( dataset.map { |e| e[:originalaps]/original_aps * 100 }).map { |a, b| a.map { |c| "#{b};#{c}" }}.transpose.map { |a| a.join("\n")}.join("\ne\n")
      file.puts "e"
    end
  end
end


if options[:graph]
  require 'tk'
end
