defmodule BasicsElixir01Test do
  use ExUnit.Case
  doctest BasicsElixir01

  test "greets the world" do
    assert BasicsElixir01.hello() == :world
  end
end
