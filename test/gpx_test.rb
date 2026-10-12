# ABOUTME: Verifies deterministic measurements using synthetic routes only.
# ABOUTME: Covers geographic distances, timestamps, missing data, and elevation noise.
require "minitest/autorun"
require_relative "../lib/outside/gpx"

class GpxTest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/short-walk.gpx", __dir__)

  def setup
    @gpx = Outside::Gpx.read(FIXTURE)
  end

  def test_haversine_for_one_degree_at_equator
    assert_in_delta 111_195.08, Outside::Gpx.haversine(0, 0, 0, 1), 0.01
    assert_equal 0, Outside::Gpx.haversine(35, 139, 35, 139)
  end

  def test_haversine_crosses_the_antimeridian
    assert_in_delta 222_390.16, Outside::Gpx.haversine(0, 179, 0, -179), 0.01
  end

  def test_parses_a_namespaced_gpx_and_sums_distance
    assert_equal 4, @gpx.facts[:track_points]
    assert_in_delta 3335.85, @gpx.distance_m, 0.01
    assert_equal 3.34, @gpx.facts[:distance_km]
  end

  def test_duration_uses_first_and_last_timestamps
    assert_equal 900, @gpx.duration_seconds
    assert_equal "0h 15m", @gpx.facts[:duration]
    assert_equal "2026-01-01T10:00:00Z", @gpx.facts[:start_time]
    assert_equal "2026-01-01T10:15:00Z", @gpx.facts[:end_time]
  end

  def test_timestamp_offsets_represent_the_same_instant
    xml = File.read(FIXTURE).sub("2026-01-01T10:00:00Z", "2026-01-01T19:00:00+09:00")
    assert_equal 900, Outside::Gpx.new(xml).duration_seconds
  end

  def test_elevation_summary
    assert_equal 100, @gpx.facts[:minimum_elevation_m]
    assert_equal 110, @gpx.facts[:maximum_elevation_m]
    assert_equal 10, @gpx.elevation_gain_m
  end

  def test_median_filter_removes_an_isolated_spike
    points = [100, 100, 500, 100, 100].map { |elevation| point(0, elevation) }.join
    gpx = Outside::Gpx.new(wrap(points))
    assert_equal 0, gpx.elevation_gain_m
    assert_equal 500, gpx.facts[:maximum_elevation_m]
  end

  def test_does_not_join_separate_track_segments
    segment_a = "<trkseg>#{point(0, 100)}#{point(0.01, 110)}</trkseg>"
    segment_b = "<trkseg>#{point(10, 500)}#{point(10.01, 510)}</trkseg>"
    gpx = Outside::Gpx.new("<gpx><trk>#{segment_a}#{segment_b}</trk></gpx>")
    assert_in_delta 2223.90, gpx.distance_m, 0.01
    assert_equal 20, gpx.elevation_gain_m
  end

  def test_missing_times_and_elevations_stay_unknown
    gpx = Outside::Gpx.new(wrap('<trkpt lat="0" lon="0"/><trkpt lat="0" lon="1"/>'))
    assert_nil gpx.duration_seconds
    assert_nil gpx.facts[:start_time]
    assert_nil gpx.facts[:minimum_elevation_m]
    assert_nil gpx.elevation_gain_m
  end

  def test_partial_elevations_do_not_fabricate_gain
    gpx = Outside::Gpx.new(wrap(point(0, 100) + '<trkpt lat="0" lon="1"/>' + point(2, 200)))
    assert_nil gpx.elevation_gain_m
    assert_equal 100, gpx.facts[:minimum_elevation_m]
    assert_equal 200, gpx.facts[:maximum_elevation_m]
  end

  def test_rejects_reversed_timestamps
    xml = File.read(FIXTURE).sub("10:05:00Z", "09:00:00Z")
    assert_raises(Outside::Error) { Outside::Gpx.new(xml) }
  end

  def test_rejects_invalid_xml_and_out_of_range_coordinates
    assert_raises(Outside::Error) { Outside::Gpx.new("<gpx>") }
    assert_raises(Outside::Error) { Outside::Gpx.new(File.read(FIXTURE).sub('lat="0"', 'lat="91"')) }
    assert_raises(Outside::Error) { Outside::Gpx.new(File.read(FIXTURE).sub('lat="0"', 'lat="NaN"')) }
  end

  def test_rejects_custom_entities
    assert_raises(Outside::Error) { Outside::Gpx.new('<!DOCTYPE gpx [<!ENTITY example "text">]><gpx/>') }
  end

  def test_summary_omits_location_samples
    refute_match(/latitude|longitude|trkpt|creator/, @gpx.facts.inspect)
    assert_equal 9, @gpx.facts.size
  end

  private

  def point(longitude, elevation)
    %(<trkpt lat="0" lon="#{longitude}"><ele>#{elevation}</ele></trkpt>)
  end

  def wrap(points)
    "<gpx><trk><trkseg>#{points}</trkseg></trk></gpx>"
  end
end
