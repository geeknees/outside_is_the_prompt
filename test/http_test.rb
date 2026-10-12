# ABOUTME: Verifies the real HTTP adapter's requests, proxy policy, and errors.
# ABOUTME: Replaces the socket transport only; no LLM or network is needed.
require "minitest/autorun"
require_relative "../lib/outside/local_model"

class HttpTest < Minitest::Test
  class Transport
    attr_accessor :use_ssl, :open_timeout, :read_timeout, :max_retries
    attr_reader :requests

    def initialize(responses)
      @responses, @requests = responses, []
    end

    def request(message)
      @requests << message
      result = @responses.shift
      raise result if result.is_a?(Exception)

      result
    end
  end

  def test_get_and_post_use_v1_json_and_no_proxy_or_api_key
    transport = Transport.new([
      response(Net::HTTPOK, { data: [{ id: "google/gemma-4-e2b" }] }),
      response(Net::HTTPOK, { choices: [{ message: { content: "I remember the stones." }, finish_reason: "stop" }] })
    ])
    factory_calls = []
    with_transport(transport, factory_calls) do
      model = Outside::LocalModel.new(base_url: "http://127.0.0.1:1234")
      model.check!
      model.generate(facts: { track_points: 2 }, observations: [{ answer: "Stones." }])
    end
    assert_equal ["/v1/models", "/v1/chat/completions"], transport.requests.map(&:path)
    assert_equal ["GET", "POST"], transport.requests.map(&:method)
    assert_equal ["127.0.0.1", 1234, nil], factory_calls.first
    assert_nil transport.requests.last["Authorization"]
    assert_equal "application/json", transport.requests.last["Content-Type"]
    body = JSON.parse(transport.requests.last.body)
    assert_equal "google/gemma-4-e2b", body["model"]
    assert_equal false, body["stream"]
  end

  def test_connection_denial_is_human_readable
    with_transport(Transport.new([Errno::EPERM.new])) do
      error = assert_raises(Outside::Error) { Outside::LocalModel.new.check! }
      assert_match(/Could not connect to LM Studio/, error.message)
    end
  end

  def test_http_errors_do_not_echo_server_body
    with_transport(Transport.new([response(Net::HTTPInternalServerError, { error: "private server details" })])) do
      error = assert_raises(Outside::Error) { Outside::LocalModel.new.check! }
      assert_match(/HTTP 500/, error.message)
      refute_match(/private server details/, error.message)
    end
  end

  def test_invalid_json_is_human_readable
    invalid = response(Net::HTTPOK, {})
    invalid.body = "not json"
    with_transport(Transport.new([invalid])) do
      error = assert_raises(Outside::Error) { Outside::LocalModel.new.check! }
      assert_match(/invalid JSON/, error.message)
    end
  end

  private

  def response(type, body)
    code = type == Net::HTTPOK ? "200" : "500"
    result = type.new("1.1", code, "test response")
    result.instance_variable_set(:@read, true)
    result.body = JSON.generate(body)
    result
  end

  def with_transport(transport, calls = [])
    original = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) do |*arguments|
      calls << arguments
      transport
    end
    yield
  ensure
    Net::HTTP.define_singleton_method(:new, original)
  end
end
