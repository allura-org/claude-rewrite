defmodule ClaudeTest do
  use ExUnit.Case
  doctest Claude

  test "greets the world" do
    assert Claude.hello() == :world
  end
end
