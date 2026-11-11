ExUnit.start()

defmodule PublishTest do
  use ExUnit.Case, async: true

  @script Path.expand("../deploy-package/publish.sh", __DIR__)

  setup do
    root =
      Path.join(System.tmp_dir!(), "nerves-publish-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, "bin"))
    File.mkdir_p!(Path.join(root, "deploy/system"))
    File.write!(Path.join(root, "deploy/system/checksum.exs"), "generated checksum\n")
    File.write!(Path.join(root, "checksum.exs"), "old checksum\n")
    on_exit(fn -> File.rm_rf!(root) end)

    for command <- ["mix", "gh"] do
      path = Path.join(root, "bin/#{command}")

      File.write!(path, """
      #!/usr/bin/env bash
      set -eu
      test "$(cat checksum.exs)" = "generated checksum"
      test -z "${MIX_OS_DEPS_COMPILE_PARTITION_COUNT+x}"
      printf '%s %s\\n' "#{command}" "$*" >> commands
      if [[ "#{command} $*" == "${FAIL_COMMAND:-}" ]]; then exit 42; fi
      if [[ "#{command} $*" == "mix docs" ]]; then touch docs-ready; fi
      if [[ "#{command} $*" == "mix hex.publish --yes" ]]; then
        test -f docs-ready
        test "$ACTIONS_ID_TOKEN_REQUEST_URL" = "https://example.invalid/oidc"
        test "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" = "oidc-test-token"
        echo "Package staged for approval"
      fi
      """)

      File.chmod!(path, 0o755)
    end

    %{root: root}
  end

  test "publishes the GitHub release before fetching artifacts and staging package and docs",
       ctx do
    {output, status} = run(ctx)

    assert status == 0
    assert output =~ "Package staged for approval"

    assert commands(ctx) == [
             "mix local.hex --force",
             "mix deps.get",
             "gh release edit v1.2.3 --draft=false",
             "mix nerves.artifact.get",
             "mix docs",
             "mix hex.publish --yes"
           ]

    assert File.read!(Path.join(ctx.root, "checksum.exs")) == "generated checksum\n"
  end

  test "rejects non-tag runs without modifying the project or publishing", ctx do
    {output, status} = run(ctx, [{"GITHUB_REF_TYPE", "branch"}])

    assert status == 1
    assert output =~ "requires a tagged release"
    assert commands(ctx) == []
    assert File.read!(Path.join(ctx.root, "checksum.exs")) == "old checksum\n"
  end

  test "requires the build's checksum before running any publishing commands", ctx do
    File.rm!(Path.join(ctx.root, "deploy/system/checksum.exs"))
    {_output, status} = run(ctx)

    assert status != 0
    assert commands(ctx) == []
  end

  test "stops on preparation, GitHub release, artifact download, docs, and Hex failures", ctx do
    expected = [
      "mix local.hex --force",
      "mix deps.get",
      "gh release edit v1.2.3 --draft=false",
      "mix nerves.artifact.get",
      "mix docs",
      "mix hex.publish --yes"
    ]

    for {command, index} <- Enum.with_index(expected, 1) do
      File.rm(Path.join(ctx.root, "commands"))
      File.rm(Path.join(ctx.root, "docs-ready"))
      {_output, status} = run(ctx, [{"FAIL_COMMAND", command}])

      assert status == 42
      assert commands(ctx) == Enum.take(expected, index)
    end
  end

  defp commands(ctx) do
    case File.read(Path.join(ctx.root, "commands")) do
      {:ok, contents} -> String.split(contents, "\n", trim: true)
      {:error, :enoent} -> []
    end
  end

  defp run(ctx, env \\ []) do
    defaults = [
      {"PATH", Path.join(ctx.root, "bin") <> ":" <> System.fetch_env!("PATH")},
      {"GITHUB_REF_TYPE", "tag"},
      {"GITHUB_REF_NAME", "v1.2.3"},
      {"MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "4"},
      {"ACTIONS_ID_TOKEN_REQUEST_URL", "https://example.invalid/oidc"},
      {"ACTIONS_ID_TOKEN_REQUEST_TOKEN", "oidc-test-token"},
      {"FAIL_COMMAND", nil}
    ]

    System.cmd("bash", [@script],
      cd: ctx.root,
      env: Enum.into(env, Map.new(defaults)),
      stderr_to_stdout: true
    )
  end
end
