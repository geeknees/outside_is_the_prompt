# ABOUTME: Exercises the three-question CLI and its Markdown output in a temporary directory.
# ABOUTME: Keeps model responses synthetic and verifies failure paths without LM Studio.
require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../lib/outside/cli"

class CliTest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/short-walk.gpx", __dir__)

  class ModelDouble
    attr_reader :facts, :observations

    def model = "test-double"
    def check! = model

    def generate(facts:, observations:)
      @facts, @observations = facts, observations
      "The GPS measured the walk. I remember the stones."
    end
  end

  def setup
    @output = StringIO.new
    @error = StringIO.new
    @model = ModelDouble.new
  end

  def test_prints_and_saves_one_postcard_after_three_questions
    in_temporary_directory do
      assert_equal 0, run_cli("Wind.\nStones.\nSky.\nFourth unused line.\n")
      assert_equal 3, @model.observations.size
      assert_equal 3, @output.string.scan(/^> /).size
      assert_equal 4, @model.facts[:track_points]
      assert_match(/OUTSIDE POSTCARD/, @output.string)
      assert_equal "# Outside Postcard\n\nThe GPS measured the walk. I remember the stones.\n", File.read("output/outside-postcard.md")
      assert_empty @error.string
    end
  end

  def test_empty_memories_produce_no_file_or_generation
    in_temporary_directory do
      assert_equal 1, run_cli("\n\n\n")
      refute File.exist?("output/outside-postcard.md")
      assert_nil @model.facts
    end
  end

  def test_eof_keeps_the_memory_already_entered
    in_temporary_directory do
      assert_equal 0, run_cli("Stones.\n")
      assert_equal 1, @model.observations.size
    end
  end

  def test_connection_error_has_no_stack_trace_and_asks_no_questions
    def @model.check!
      raise Outside::Error, "Could not connect to LM Studio."
    end
    assert_equal 1, run_cli("Memory.\n")
    assert_match(/Could not connect/, @error.string)
    refute_match(/What did you notice/, @output.string)
    refute_match(/\.rb:\d+/, @error.string)
  end

  def test_missing_gpx_is_a_readable_error
    cli = Outside::CLI.new(input: StringIO.new, output: @output, error: @error, model: @model)
    assert_equal 1, cli.run(["nonexistent.gpx"])
    assert_match(/GPX file not found/, @error.string)
  end

  def test_help_needs_no_model
    cli = Outside::CLI.new(output: @output, error: @error)
    assert_equal 0, cli.run(["--help"])
    assert_match(/Usage:/, @output.string)
  end

  private

  def run_cli(answers)
    Outside::CLI.new(input: StringIO.new(answers), output: @output, error: @error, model: @model).run([FIXTURE])
  end

  def in_temporary_directory(&block)
    Dir.mktmpdir("outside-test-") { |directory| Dir.chdir(directory, &block) }
  end
end
