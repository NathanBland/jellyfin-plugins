using Jellyfin.Plugin.CommercialSkipper.Analysis;
using Jellyfin.Plugin.CommercialSkipper.Configuration;
using Jellyfin.Plugin.RecordingPipeline;

namespace Jellyfin.Plugin.CommercialSkipper.Tests;

public sealed class ComskipRunnerTests
{
    [Fact]
    public async Task TestAsync_ReportsMissingConfiguredExecutable()
    {
        var path = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"), "comskip");
        var result = await new ComskipRunner(new ProcessRunner()).TestAsync(
            new PluginConfiguration { ComskipPath = path },
            CancellationToken.None);

        Assert.False(result.Success);
        Assert.Null(result.ExitCode);
        Assert.Contains(path, result.Error, StringComparison.Ordinal);
    }

    [Fact]
    public async Task TestAsync_AcceptsComskipHelpExitCode()
    {
        if (OperatingSystem.IsWindows())
        {
            return;
        }

        var path = await CreateExecutableAsync("printf 'Usage: comskip [options] input\n'\nexit 2\n");
        try
        {
            var result = await new ComskipRunner(new ProcessRunner()).TestAsync(
                new PluginConfiguration { ComskipPath = path },
                CancellationToken.None);

            Assert.True(result.Success);
            Assert.Equal(2, result.ExitCode);
            Assert.Null(result.Error);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public async Task TestAsync_ReportsProcessFailure()
    {
        if (OperatingSystem.IsWindows())
        {
            return;
        }

        var path = await CreateExecutableAsync("printf 'loader failure\n' >&2\nexit 7\n");
        try
        {
            var result = await new ComskipRunner(new ProcessRunner()).TestAsync(
                new PluginConfiguration { ComskipPath = path },
                CancellationToken.None);

            Assert.False(result.Success);
            Assert.Equal(7, result.ExitCode);
            Assert.Contains("loader failure", result.Error, StringComparison.Ordinal);
        }
        finally
        {
            File.Delete(path);
        }
    }

    private static async Task<string> CreateExecutableAsync(string body)
    {
        if (OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException();
        }

        var path = Path.Combine(Path.GetTempPath(), "commercial-skipper-" + Guid.NewGuid().ToString("N"));
        await File.WriteAllTextAsync(path, "#!/bin/sh\n" + body);
        File.SetUnixFileMode(
            path,
            UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        return path;
    }
}
