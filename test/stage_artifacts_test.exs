Mix.start()
Code.require_file("../build-package/stage_artifacts.exs", __DIR__)
ExUnit.start()

defmodule StageArtifactsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Nerves.Action.Stage

  setup do
    root =
      Path.join(System.tmp_dir!(), "nerves-action-test-#{System.unique_integer([:positive])}")

    source = Path.join(root, "source")
    downloads = Path.join(root, "downloads")
    File.mkdir_p!(source)
    File.mkdir_p!(downloads)
    File.write!(Path.join(source, "checksum.exs"), "%{}\n")
    File.write!(Path.join(source, "CHANGELOG.md"), "## v1.0.0\n\nRelease notes.\n")
    on_exit(fn -> File.rm_rf!(root) end)

    %{source: source, downloads: downloads, destination: Path.join(root, "deploy")}
  end

  test "stages only the selected package's downloads and preserves publishing files", context do
    archive = Path.join(context.downloads, "system.tar.gz")
    signature = archive <> ".sig"
    File.write!(archive, "archive")
    File.write!(signature, "signature")
    File.write!(Path.join(context.downloads, "unrelated.tar.gz"), "unrelated")

    package = %{
      app: :system,
      path: context.source,
      downloads: [
        %{archive_path: archive, filename: "system.tar.gz"},
        %{archive_path: signature, filename: "system.tar.gz.sig"}
      ]
    }

    assert :ok = Stage.stage(package, context.destination)
    artifacts = Path.join(context.destination, "artifacts")
    assert Enum.sort(File.ls!(artifacts)) == ["system.tar.gz", "system.tar.gz.sig"]
    assert File.read!(Path.join(artifacts, "system.tar.gz")) == "archive"
    assert File.read!(Path.join(artifacts, "system.tar.gz.sig")) == "signature"
    assert File.read!(Path.join(context.destination, "checksum.exs")) == "%{}\n"
    assert File.read!(Path.join(context.destination, "CHANGELOG.md")) =~ "Release notes."
  end

  test "fails when an expected archive is missing", context do
    package = %{
      app: :system,
      path: context.source,
      downloads: [
        %{archive_path: Path.join(context.downloads, "missing.tar.gz"), filename: "system.tar.gz"}
      ]
    }

    assert_raise File.CopyError, fn -> Stage.stage(package, context.destination) end
  end

  test "fails rather than exporting an empty package", context do
    package = %{app: :system, path: context.source, downloads: []}

    assert_raise Mix.Error, "No artifact outputs found for system", fn ->
      Stage.stage(package, context.destination)
    end
  end

  test "fails when the generated checksum manifest is missing", context do
    archive = Path.join(context.downloads, "system.tar.gz")
    File.write!(archive, "archive")
    File.rm!(Path.join(context.source, "checksum.exs"))

    package = %{
      app: :system,
      path: context.source,
      downloads: [%{archive_path: archive, filename: "system.tar.gz"}]
    }

    assert_raise File.CopyError, fn -> Stage.stage(package, context.destination) end
  end
end
