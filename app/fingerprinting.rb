require './logging.rb'
require './mapengine.rb'
require 'set'

module Localization
  class Fingerprinting

    # The number of matches to average for a final result
    BEST_MATCHES = 4

    # The minimum number of matching signals to consider a fingerprint as a possible match
    MINIMUM_SIGNAL_MATCHES = 1


    def initialize(logger = nil)
      @fingerprints = Hash.new { |hash, key| hash[key] = [] }
      @cumulative_error = 0
      @localization_misses = 0
      if logger == nil
        @logger = Logging.getLogger(:Fingerprinting)
        @logger.add_handler(Logging.ConsoleHandler)
        @logger.add_handler(Logging.FileHandler("Fingerprinting"))
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

    # Data structures explained:

    # signal - A tuple of an ID and corresponding signal strength
    #  [id, signal_strength]
    #
    # fingerprint - A tuple of a list signals with a corresponding x and y position
    #  [[signals], pos_x, pos_y]
    #
    # @fingerprints - a hash from Set of IDs to corresponding fingerprints
    #  { Set:id_set -> [fingerprints] }

    # Enters a set of received signals at a specific location into the system
    def feed(pos_x, pos_y, signals)
      signal_set = (signals.map{|id, _| id}).to_set
      @fingerprints[signal_set].push([signals, pos_x, pos_y])
    end

    # Returns an estimated location based on the perceived signals
    def read(signals)

      id_set = (signals.map{|id, _| id}).to_set

      # Get an array with all relevant fingerprints for this set of IDs
      set_distance_map = relevant_fingerprint_array(id_set)

      # Build a list of fingerprints with the closest match to the id_set, with minimum size of BEST_MATCHES
      searchable_fingerprints = []
      set_distance_map.each do |fingerprints|
        searchable_fingerprints.concat(fingerprints)
        break if searchable_fingerprints.size >= BEST_MATCHES
      end

      matches = []

      searchable_fingerprints.each do |fingerprint_signals, pos_x, pos_y|
        fingerprint_id_set = fingerprint_signals.map{|id, _| id }.to_set

        matching_signals = signals.select{ |id, _| fingerprint_id_set.include?(id) }

        # If the fingerprint matches only one ID, consider it a match with the following properties:
        # Match strength is weaker than any match with more than one ID
        # Match strength is equal to the negative difference between observed signal strengths
        if matching_signals.size == 1
          matches.push([-1 - (matching_signals.first.last - fingerprint_signals.first.last).abs, pos_x, pos_y])
        else

          strength_map = Hash[matching_signals.map{ |_, strength| strength }.sort.each_with_index.map { |str, index| [str, index]}]
          # Strength maps are incorrect if two signals have the same strength. They are assigned the index of the last signal instead of the average of their indices.
          # Problem is worse when multiple signals match strength.  
          signal_ranks = matching_signals.map{|_, str| strength_map[str]}

          fingerprint_strength_map = Hash[fingerprint_signals.map{ |_, strength| strength }.sort.each_with_index.map { |str, index| [str, index]}]
          fingerprint_signal_ranks = fingerprint_signals.map{|_, str| fingerprint_strength_map[str]}
          matches.push([Math.spearman_coefficient(signal_ranks, fingerprint_signal_ranks), pos_x, pos_y])
        end
      end
      if matches.empty?
        @localization_misses += 1
        return [-1, -1]
      end
      best_matches = matches.sort{ |a, b| b.first <=> a.first }.first(BEST_MATCHES).map{ |_, pos_x, pos_y| [pos_x, pos_y]}
      return best_matches.reduce { |match1, match2| [match1.first + match2.first, match1.last + match2.last]}.map{ |pos| pos/best_matches.size.to_f }
    end

    private

    # Returns an array with all fingerprints for the given id_set, indexed on distance to the given id_set.
    # Example: [[fingerprints_with_distance_0], [fingerprints_with_distance_1], etc]
    #
    # Only returns fingerprints with at least 1 matching id
    #
    # The signals from these fingerprints that do not match the given id_set are removed.
    # The following is correct for all returned fingerprints: fingerprint.signal_ids.subset?(id_set) == true
    #
    # All fingerprint signal sets are sorted by id.
    def relevant_fingerprint_array(id_set)
      result = []
      @fingerprints.each do |fingerprint_id_set, fingerprints|
        if (id_set & fingerprint_id_set).size >= MINIMUM_SIGNAL_MATCHES
          difference = (id_set ^ fingerprint_id_set)
          distance = difference.size

          filtered_fingerprints = fingerprints.map do |signals, pos_x, pos_y|
            [signals.reject{ |id, _| difference.include?(id) }.sort{ |a, b| a.first <=> b.first }, pos_x, pos_y]
          end

          result[distance] = [] if result[distance] == nil
          result[distance].concat(filtered_fingerprints)
        end
      end
      return result.map { |e| e || [] }
    end
  end
end

module Math

  # Calculates the spearman coefficient of two vectors.
  # The result always lies within (-1..1)
  # A result of 1 denotes a strong similarity, and -1 a strong dissimilarity between the given vectors
  def self.spearman_coefficient (vector1, vector2)
    throw "Vectors are not the same size" if vector1.length != vector2.length
    
    mean1 = vector1.inject(:+) / vector1.length
    mean2 = vector2.inject(:+) / vector2.length
    vector1.collect! {|e| e - mean1 }
    vector2.collect! {|e| e - mean2 }

    top = 0
    lower1 = 0
    lower2 = 0

    vector1.each_index do |index|
      top += (vector1[index] * vector2[index])
      lower1 += vector1[index] ** 2
      lower2 += vector2[index] ** 2
    end

    bottom = Math.sqrt(lower1 * lower2)
    
    p "#{vector1} - #{vector2}" if bottom == 0
    return top / bottom
  end
end