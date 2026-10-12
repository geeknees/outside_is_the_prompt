# ABOUTME: Parses GPX tracks and measures distance, time, and elevation in Ruby.
# ABOUTME: Exposes aggregate facts without coordinates or track metadata.
require "rexml/document"
require "time"

module Outside
  class Error < StandardError; end

  class Gpx
    Point = Struct.new(:latitude, :longitude, :elevation, :time, keyword_init: true)
    EARTH_RADIUS_M = 6_371_008.8

    def self.read(path)
      new(File.read(path, encoding: "UTF-8"))
    rescue Errno::ENOENT
      raise Error, "GPX file not found. Pass the path to your recorded walk."
    rescue Errno::EACCES, Errno::EISDIR
      raise Error, "Could not read the GPX file. Check its path and permissions."
    end

    def initialize(xml)
      raise Error, "GPX files with DTDs or custom entities are not supported." if xml.match?(/<!DOCTYPE|<!ENTITY/i)

      document = REXML::Document.new(xml)
      raise Error, "Expected a GPX document." unless document.root&.name == "gpx"

      @segments = REXML::XPath.match(document, "/*[local-name()='gpx']/*[local-name()='trk']/*[local-name()='trkseg']").map do |segment|
        segment.elements.select { |element| element.name == "trkpt" }.map { |element| parse_point(element) }
      end.reject(&:empty?)
      @points = @segments.flatten
      raise Error, "The GPX needs at least two track points (trkpt)." if @points.size < 2

      times = @points.filter_map(&:time)
      raise Error, "GPX timestamps must be in chronological order." if times.each_cons(2).any? { |a, b| b < a }
    rescue REXML::ParseException, ArgumentError
      raise Error, "Could not parse this GPX. Check the XML, coordinates, elevations, and timestamps."
    end

    def self.haversine(lat1, lon1, lat2, lon2)
      radians = Math::PI / 180
      dlat = (lat2 - lat1) * radians
      dlon = (lon2 - lon1) * radians
      a = Math.sin(dlat / 2)**2 + Math.cos(lat1 * radians) * Math.cos(lat2 * radians) * Math.sin(dlon / 2)**2
      2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a.clamp(0.0, 1.0)))
    end

    def distance_m
      @segments.sum do |segment|
        segment.each_cons(2).sum { |a, b| self.class.haversine(a.latitude, a.longitude, b.latitude, b.longitude) }
      end
    end

    def duration_seconds
      return unless @points.first.time && @points.last.time

      (@points.last.time - @points.first.time).round
    end

    def elevation_gain_m
      return if @points.any? { |point| point.elevation.nil? }

      @segments.sum do |segment|
        elevations = segment.map(&:elevation)
        # A three-point median removes isolated spikes; endpoints stay measured.
        smoothed = elevations.each_index.map do |index|
          if index.zero? || index == elevations.length - 1
            elevations[index]
          else
            elevations[(index - 1)..(index + 1)].sort[1]
          end
        end
        smoothed.each_cons(2).sum { |a, b| [b - a, 0].max }
      end
    end

    def facts
      elevations = @points.filter_map(&:elevation)
      seconds = duration_seconds
      minutes = seconds && (seconds / 60.0).round
      {
        track_points: @points.length,
        distance_km: (distance_m / 1_000).round(2),
        elapsed_seconds: seconds,
        duration: minutes && "#{minutes / 60}h #{minutes % 60}m",
        minimum_elevation_m: elevations.min&.round,
        maximum_elevation_m: elevations.max&.round,
        elevation_gain_m: elevation_gain_m&.round,
        start_time: @points.first.time&.utc&.iso8601,
        end_time: @points.last.time&.utc&.iso8601
      }
    end

    private

    def parse_point(element)
      latitude = number(element.attributes["lat"])
      longitude = number(element.attributes["lon"])
      raise Error, "GPX coordinates are outside their valid ranges." unless (-90..90).cover?(latitude) && (-180..180).cover?(longitude)

      children = element.elements.to_a.to_h { |child| [child.name, child.text] }
      timestamp = children["time"]
      if timestamp && !timestamp.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)
        raise Error, "GPX timestamps need a timezone (Z or an offset)."
      end
      Point.new(latitude: latitude, longitude: longitude,
                elevation: children["ele"] && number(children["ele"]),
                time: timestamp && Time.iso8601(timestamp))
    end

    def number(value)
      result = Float(value || "")
      raise Error, "GPX measurements must be finite numbers." unless result.finite?

      result
    end
  end
end
