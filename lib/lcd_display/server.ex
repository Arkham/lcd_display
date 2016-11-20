# Datasheet: https://www.embeddedadventures.com/datasheets/LCD-1602_hw_v1_doc_v1.pdf

defmodule LcdDisplay.Server do
  use GenServer
  use Bitwise

  # API

  def start_link([bus, address, background]) do
    GenServer.start_link(
      __MODULE__,
      [bus, address, background],
      name: __MODULE__
    )
  end

  def write(x, y, message) when x < 0,  do: write(0, y, message)
  def write(x, y, message) when x > 15, do: write(15, y, message)
  def write(x, y, message) when y < 0,  do: write(x, 0, message)
  def write(x, y, message) when y > 1,  do: write(x, 1, message)
  def write(x, y, message) do
    GenServer.cast(__MODULE__, {:write, x, y, message})
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  # Callbacks

  def init([bus, address, background]) do
    {:ok, display} = I2c.start_link(bus, address)
    send(self, :initialize_display)
    {:ok, %{display: display, background: background}}
  end

  def handle_info(:initialize_display, %{display: display} = state) do
    send_command(0x33, state) # initialize to 8-line mode
    :timer.sleep(5)
    send_command(0x32, state) # initialize to 4-line mode
    :timer.sleep(5)
    send_command(0x28, state) # 2 lines of cells composed of 5*7 dots
    :timer.sleep(5)
    send_command(0x0C, state) # enable display without cursor
    :timer.sleep(5)
    send_command(0x01, state) # clear screen
    i2c_write(display, 0x08)
    {:noreply, state}
  end

  def handle_cast({:write, x, y, message}, state) do
    address = 0x80 + 0x40 * y + x
    send_command(address, state)
    message
    |> String.to_char_list
    |> Enum.each(fn char ->
      send_data(char, state)
    end)
    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    send_command(0x01, state)
  end

  # Private
  
  defp i2c_write(display, value) do
    I2c.write(display, <<value>>)
  end

  defp write_word(data, %{display: display, background: :light}) do
    i2c_write(display, data ||| 0x08)
  end
  defp write_word(data, %{display: display, background: :dark}) do
    i2c_write(display, data &&& 0xF7)
  end

  defp send_command(command, state) do
    # 0x04 -> RS = 0, RW = 0, EN = 1
    send_with_mask(command, 0x04, state)
  end

  defp send_data(data, state) do
    # 0x05 -> RS = 0, RW = 0, EN = 1
    send_with_mask(data, 0x05, state)
  end

  defp send_with_mask(data, mask, state) do
    # first send bits 7-4
    buffer = data &&& 0xF0
    buffer = buffer ||| mask
    write_word(buffer, state)
    :timer.sleep(2)
    buffer = buffer &&& 0xFB # 0xFB -> EN = 0
    write_word(buffer, state)

    # then send bits 3-0
    buffer = (data &&& 0x0F) <<< 4
    buffer = buffer ||| mask
    write_word(buffer, state)
    :timer.sleep(2)
    buffer = buffer &&& 0xFB # 0xFB -> EN = 0
    write_word(buffer, state)
  end
end
