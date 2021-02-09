defmodule MetaSagaTest do
  use ExUnit.Case
  doctest MetaSaga

  test "greets the world" do
    assert MetaSaga.hello() == :world
  end
end
