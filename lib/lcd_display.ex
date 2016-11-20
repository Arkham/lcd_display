defmodule LcdDisplay do
  use Application
  use Bitwise

  def start(_type, _args) do
    LcdDisplay.Server.start_link(["i2c-1", 0x27, :light])
    {:ok, self}
  end

  def write(x, y, message) do
    LcdDisplay.Server.write(x, y, message)
  end

  def clear do
    LcdDisplay.Server.clear
  end

  def test do
    write(4, 0, "Hello")
    write(7, 1, "world!")
  end
end
