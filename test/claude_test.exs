defmodule ClaudeTest do
  use ExUnit.Case
  doctest Claude

  describe "version/0" do
    test "returns a version string" do
      version = Claude.version()
      assert is_binary(version)
    end
  end

  describe "status/0" do
    test "returns a map with expected keys" do
      status = Claude.status()

      assert is_map(status)
      assert Map.has_key?(status, :version)
      assert Map.has_key?(status, :bot_user_id)
      assert Map.has_key?(status, :provider)
      assert Map.has_key?(status, :model)
    end
  end

  describe "connected?/0" do
    test "returns a boolean" do
      result = Claude.connected?()
      assert is_boolean(result)
    end
  end

  describe "llm_info/0" do
    test "returns LLM configuration info" do
      info = Claude.llm_info()

      assert is_map(info)
      assert Map.has_key?(info, :provider)
      assert Map.has_key?(info, :model)
      assert Map.has_key?(info, :base_url)
      assert Map.has_key?(info, :supports_images)
    end
  end
end
