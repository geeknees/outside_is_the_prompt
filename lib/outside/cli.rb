# ABOUTME: Shows what GPS measured, asks three brief questions, and saves a postcard.
# ABOUTME: Keeps the time at the screen short and all generated files local.
require "fileutils"
require_relative "gpx"
require_relative "local_model"

module Outside
  class CLI
    QUESTIONS = [
      "What did you notice that GPS couldn't?",
      "What surprised you?",
      "What will you remember?"
    ].freeze

    def initialize(input: $stdin, output: $stdout, error: $stderr, model: nil)
      @input, @output, @error = input, output, error
      @model = model
    end

    def run(arguments)
      if arguments == ["--help"] || arguments == ["-h"]
        @output.puts "Usage: bin/outside /path/to/hike.gpx\nThree short answers. One postcard in output/outside-postcard.md."
        return 0
      end
      raise Error, "Usage: bin/outside /path/to/hike.gpx" unless arguments.size == 1

      facts = Gpx.read(arguments.first).facts
      show_facts(facts)
      @output.flush
      @model ||= LocalModel.new
      @model.check!
      @output.puts "\nLocal model: #{@model.model}\nThree short answers. Enter skips a question.\n\n"
      observations = []
      QUESTIONS.each do |question|
        @output.puts question
        @output.print "> "
        @output.flush
        line = @input.gets
        break if line.nil?

        answer = line.strip
        observations << { question: question, answer: answer } unless answer.empty?
      end
      raise Error, "Please enter your memories, one line per question, before generating a postcard." if observations.empty?

      @output.puts "\nReflecting locally..."
      postcard = @model.generate(facts: facts, observations: observations)
      FileUtils.mkdir_p("output", mode: 0o700)
      File.open("output/outside-postcard.md", "w", 0o600) { |file| file.write("# Outside Postcard\n\n#{postcard}\n") }
      @output.puts "\nOUTSIDE POSTCARD\n\n#{postcard}\n\nSaved to output/outside-postcard.md"
      0
    rescue Error => error
      @error.puts "\n#{error.message}"
      1
    rescue SystemCallError
      @error.puts "\nCould not save the postcard. Check that the output directory is writable."
      1
    rescue Interrupt
      @error.puts "\nStopped. Come back when you have a memory to keep."
      130
    end

    private

    def show_facts(facts)
      @output.puts "OUTSIDE IS THE PROMPT\n\nTHE MACHINE KNOWS\n\n"
      distance = facts[:distance_km] && format("%.2f km", facts[:distance_km])
      rows = {
        "Distance" => distance,
        "Time outside" => facts[:duration],
        "Elevation gain" => meters(facts[:elevation_gain_m], approximate: true),
        "Lowest point" => meters(facts[:minimum_elevation_m]),
        "Highest point" => meters(facts[:maximum_elevation_m]),
        "Track points" => facts[:track_points],
        "Start (UTC)" => facts[:start_time],
        "End (UTC)" => facts[:end_time]
      }
      rows.each { |label, value| @output.puts format("%-17s %s", "#{label}:", value || "Not recorded") }
      @output.puts "\nBUT THE GPS DOESN'T KNOW EVERYTHING."
    end

    def meters(value, approximate: false)
      return unless value

      number = value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      "#{approximate ? '~' : ''}#{number} m"
    end
  end
end
