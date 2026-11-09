ExUnit.start()

defmodule RunLoggedTest do
  use ExUnit.Case, async: true

  @script Path.expand("../build-package/run_logged.sh", __DIR__)

  setup do
    root = Path.join(System.tmp_dir!(), "nerves-logs-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    %{root: root, summary: Path.join(root, "summary.md")}
  end

  test "captures build stdout and stderr without flooding successful console output", context do
    {output, status} =
      run(context, "artifact-build", [
        "bash",
        "-c",
        ~s(printf 'stdout marker\\n'; printf 'stderr marker\\n' >&2; printf '%s\\n' "$1"),
        "--",
        "argument with spaces"
      ])

    assert status == 0
    assert output =~ "completed successfully"
    refute output =~ "stdout marker"
    refute output =~ "stderr marker"
    refute File.exists?(context.summary)

    assert File.read!(Path.join(context.root, "nerves-package-logs/artifact-build.log")) ==
             "stdout marker\nstderr marker\nargument with spaces\n"
  end

  test "streams short command output while retaining complete logs", context do
    for step <- ["artifact-clean", "artifact-checksum", "artifact-staging", "hex-build"] do
      {output, status} =
        run(context, step, [
          "bash",
          "-c",
          "printf 'stdout marker\\n'; printf 'stderr marker\\n' >&2"
        ])

      assert status == 0
      assert output =~ "stdout marker\n"
      assert output =~ "stderr marker\n"

      assert File.read!(Path.join(context.root, "nerves-package-logs/#{step}.log")) ==
               "stdout marker\nstderr marker\n"
    end

    refute File.exists?(context.summary)
  end

  test "does not mask streamed command failures or repeat their output", context do
    {output, status} =
      run(context, "hex-build", ["bash", "-c", "printf 'Hex packaging failed\\n' >&2; exit 42"])

    assert status == 42
    assert output =~ "::error::hex-build failed with exit status 42"
    assert length(Regex.scan(~r/Hex packaging failed/, output)) == 1
    assert File.read!(context.summary) =~ "Hex packaging failed"
    assert File.read!(context.summary) =~ "**42**"

    assert File.read!(Path.join(context.root, "nerves-package-logs/hex-build.log")) ==
             "Hex packaging failed\n"
  end

  test "preserves failures and reports a readable tail in the console and summary", context do
    command = """
    for ((i=1; i<=200; i++)); do printf 'line-%03d\\n' "$i"; done
    printf '\\033[31mHex packaging failed\\033[0m\\r\\n' >&2
    exit 42
    """

    {output, status} = run(context, "artifact-build", ["bash", "-c", command])
    assert status == 42
    assert output =~ "::error::artifact-build failed with exit status 42"
    assert output =~ "Hex packaging failed"
    refute output =~ "line-001\n"

    summary = File.read!(context.summary)
    assert summary =~ "artifact-build failed"
    assert summary =~ "**42**"
    assert summary =~ "nerves-package-logs"
    assert summary =~ "line-200\n"
    assert summary =~ "Hex packaging failed"
    refute summary =~ "line-001\n"
    refute summary =~ "\e"
    refute summary =~ "\r"

    log = File.read!(Path.join(context.root, "nerves-package-logs/artifact-build.log"))
    assert log =~ "line-001\n"
    assert log =~ "\e[31mHex packaging failed\e[0m\r\n"
  end

  test "bounds the summary even when a command prints a very long line", context do
    {output, status} =
      run(context, "artifact-build", [
        "bash",
        "-c",
        "printf '%20000s\\n' oversized; printf 'last error\\n' >&2; exit 1"
      ])

    assert status == 1
    assert byte_size(output) < 17000
    assert byte_size(File.read!(context.summary)) < 17000
    assert File.read!(context.summary) =~ "last error"

    assert File.stat!(Path.join(context.root, "nerves-package-logs/artifact-build.log")).size >
             20000
  end

  test "keeps the container terminal and exit status when capturing script output", context do
    for step <- ["artifact-clean", "artifact-build"] do
      {output, status} =
        run(context, step, [
          "script",
          "-e",
          "-c",
          "test -t 0 && test -t 1 && exit 17",
          "-q",
          "/dev/null"
        ])

      assert status == 17
      assert output =~ "#{step} failed with exit status 17"
      assert File.read!(context.summary) =~ "**17**"
    end
  end

  defp run(context, step, command) do
    System.cmd("bash", [@script, step | command],
      env: [{"RUNNER_TEMP", context.root}, {"GITHUB_STEP_SUMMARY", context.summary}],
      stderr_to_stdout: true
    )
  end
end
