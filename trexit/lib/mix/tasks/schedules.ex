defmodule Mix.Tasks.Schedules do
  use Mix.Task

  def run([route]) do
    Trexit.main(route)
  end
end
