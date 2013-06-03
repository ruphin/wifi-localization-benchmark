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
set key top center
set style data linespoints
set grid
 
set xlabel 'Step'
set xtics 5
set mxtics 5
 
set ylabel 'Measured Error'
set ytics nomirror
set ytics 5
set yrange [10:50]
 
set y2label 'Access Points Remaining'
set y2tics 10
set autoscale y2
set y2range [0:100]
set format y2 "%g%%"

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
        dataset[step][:error].push [data.captures.first, data.captures.last.to_f]
      elsif (data = (LEARNINGERROR.match line))
        dataset[step][:error].push ["Learning " + data.captures.first, data.captures.last.to_f]
      elsif (data = (MISSES.match line))
        dataset[step][:misses].push [data.captures.first, data.captures.last.to_f]
      elsif (data = (LEARNINGMISSES.match line))
        dataset[step][:misses].push ["Learning " + data.captures.first, data.captures.last.to_f]
      end
    end

    algorithms = dataset[0][:error].map(&:first)
    original_aps = dataset[0][:originalaps].to_f
    errors = dataset.map { |d| d[:error].map(&:last) }
    errors = errors.zip( [Array.new(errors.first.size, 0)] + errors).map { |a, b| a.zip(b).map { |c, d| c - d }}
    misses = dataset.map { |d| d[:misses].map(&:last) }
    misses = misses.zip( [Array.new(misses.first.size, 0)] + misses).map { |a, b| a.zip(b).map { |c, d| c - d }}
    average_error = errors.zip(misses).map { |a, b| a.zip(b).map {|c, d| c / (scans_per_iteration - d) }}

    File.open("#{filename}.data", 'w+') do |file|
      file.puts "#{mapsize}\t#{density}\t#{accuracy}\t#{iterations}"
      file.puts ""
      file.puts "step\taps-remaining\t#{algorithms.map {|a| a + " error"}.join("\t")}\t#{algorithms.map {|a| a + " misses"}.join("\t")}"
      dataset.each_with_index do |d, s|
        file.puts "#{s+1}\t#{d[:originalaps]/original_aps}\t#{average_error[s].join("\t")}\t#{misses[s].join("\t")}"
      end
    end
    File.open("#{filename}.gnuplot", 'w+') do |file|
      file.puts GNUPLOT_TEMPLATE

      file.puts "set xrange [1:#{iterations}]"
      file.puts "set output '#{mapsize}-#{density}-#{accuracy}-#{iterations}.svg'"

      file.print "plot "
      algorithms.each do |a|
        file.puts "'-' using 1:($2) title '#{a}' axes x1y1 lt rgb 'black', \\"
      end
      file.puts "'-' using 1:($2*100) title 'Remaining Access Points' axes x1y2 lt rgb 'black'"
      file.puts average_error.zip( Array.new(average_error.size) { |x| x+1 }).map { |a, b| a.map { |c| "#{b};#{c}" }}.transpose.map { |a| a.join("\n")}.join("\ne\n")
      file.puts "e"
      dataset.map { |e| e[:originalaps]/original_aps }.each_with_index do |d, s|
        file.puts "#{s+1};#{d}"
      end
      file.puts "e"
    end
  end
end


if options[:graph]
  require 'tk'

end