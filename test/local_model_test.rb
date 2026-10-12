# ABOUTME: Checks model selection and prompt boundaries without running an LLM.
# ABOUTME: Uses controlled API responses so tests never require a network connection.
require "minitest/autorun"
require_relative "../lib/outside/local_model"

class LocalModelTest < Minitest::Test
  class FakeAPI < Outside::LocalModel
    attr_accessor :responses
    attr_reader :requests

    def initialize(**options)
      super
      @requests = []
      @responses = []
    end

    private

    def request(path, body = nil)
      @requests << [path, body]
      @responses.shift
    end
  end

  def setup
    @model = FakeAPI.new(base_url: "http://localhost:1234/v1", model: "google/gemma-4-e2b")
    @memories = [{ question: "What will you remember?", answer: "The stones in my pocket." }]
  end

  def test_discovers_exact_model
    @model.responses = [{ "data" => [{ "id" => "google/gemma-4-e2b" }] }]
    assert_equal "google/gemma-4-e2b", @model.check!
  end

  def test_accepts_unambiguous_publisher_alias
    @model.responses = [{ "data" => [{ "id" => "gemma-4-e2b" }] }]
    assert_equal "gemma-4-e2b", @model.check!
  end

  def test_does_not_silently_use_a_different_model
    @model.responses = [{ "data" => [{ "id" => "another-model" }] }]
    error = assert_raises(Outside::Error) { @model.check! }
    assert_match(/LM_STUDIO_MODEL/, error.message)
  end

  def test_rejects_a_remote_or_credential_bearing_url
    ["https://example.com/v1", "http://user:password@localhost:1234/v1"].each do |url|
      assert_raises(Outside::Error) { Outside::LocalModel.new(base_url: url) }
    end
  end

  def test_accepts_a_private_lan_server_and_infers_v1
    model = FakeAPI.new(base_url: "http://192.168.1.10:1234", model: "gemma-4-e2b")
    model.responses = [{ "data" => [{ "id" => "gemma-4-e2b" }] }]
    assert_equal "gemma-4-e2b", model.check!
    assert_equal "http://192.168.1.10:1234/v1", model.instance_variable_get(:@base_url)
  end

  def test_requires_a_human_memory
    assert_raises(Outside::Error) { @model.generate(facts: {}, observations: []) }
    assert_empty @model.requests
  end

  def test_sends_separate_structured_sources_and_selected_model
    @model.responses = [completion("The GPS measured the distance. I remember the stones in my pocket.")]
    text = @model.generate(facts: { distance_km: 1.23 }, observations: @memories)
    assert_match(/stones/, text)
    path, body = @model.requests.last
    assert_equal "chat/completions", path
    assert_equal "google/gemma-4-e2b", body[:model]
    payload = JSON.parse(body[:messages].last[:content])
    assert_equal({ "distance_km" => 1.23 }, payload["gps_measurements"])
    assert_equal "The stones in my pocket.", payload["human_memories"].first["answer"]
  end

  def test_rejects_empty_and_overlong_postcards
    ["", ("word " * 101)].each do |text|
      @model.responses = [completion(text)]
      assert_raises(Outside::Error) { @model.generate(facts: {}, observations: @memories) }
    end
  end

  def test_does_not_publish_truncated_generation_or_reasoning
    @model.responses = [completion("<think>private reasoning</think>The stones in my pocket.")]
    assert_equal "The stones in my pocket.", @model.generate(facts: {}, observations: @memories)
    @model.responses = [completion("Unfinished", finish: "length")]
    assert_raises(Outside::Error) { @model.generate(facts: {}, observations: @memories) }
  end

  def test_malformed_completion_is_a_readable_error
    @model.responses = [{}]
    assert_raises(Outside::Error) { @model.generate(facts: {}, observations: @memories) }
  end

  private

  def completion(text, finish: "stop")
    { "choices" => [{ "message" => { "content" => text }, "finish_reason" => finish }] }
  end
end
