defmodule Mix.Tasks.Nerves.Action.Stage do
  @moduledoc "Stage the selected Nerves package's build outputs for deployment."
  use Mix.Task

  @requirements ["deps.loadpaths"]
  # This task is loaded with elixir -r before the project's dependencies.
  @compile {:no_warn_undefined, [Nerves, Nerves.MixUtils]}

  @impl Mix.Task
  def run([]) do
    package = Nerves.MixUtils.select_package!(Nerves.build_plan(), [])
    stage(package, "deploy/system")
  end

  @doc false
  def stage(package, destination) do
    if package.downloads == [] do
      Mix.raise("No artifact outputs found for #{package.app}")
    end

    artifacts = Path.join(destination, "artifacts")
    File.mkdir_p!(artifacts)

    Enum.each(package.downloads, fn download ->
      File.cp!(download.archive_path, Path.join(artifacts, download.filename))
    end)

    for filename <- ["checksum.exs", "CHANGELOG.md"] do
      File.cp!(Path.join(package.path, filename), Path.join(destination, filename))
    end

    :ok
  end
end
