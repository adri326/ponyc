Param(
    [Parameter(Position=0, Mandatory=$true, HelpMessage="Enter the action to take, e.g. libs, cleanlibs, configure, build, clean, distclean, test, install.")]
    [string]
    $Command,

    [Parameter(HelpMessage="The build configuration (Release, Debug, RelWithDebInfo, MinSizeRel).")]
    [string]
    $Config = "Release",

    [Parameter(HelpMessage="The CMake generator, e.g. `"Visual Studio 16 2019`"")]
    [string]
    $Generator = "default",

    [Parameter(HelpMessage="The architecture to use for compiling, e.g. `"x64`"")]
    [string]
    $Architecture = "x64",

    [Parameter(HelpMessage="The location to install to")]
    [string]
    $InstallPath = "default",

    [Parameter(HelpMessage="The version to use when packaging")]
    [string]
    $Version = "default"
)

# Sanitize config to conform to CMake build configs.
switch ($Config.ToLower())
{
    "release" { $Config = "Release"; break; }
    "debug" { $Config = "Debug"; break; }
    "relwithdebinfo" { $Config = "RelWithDebInfo"; break; }
    "minsizerel" { $Config = "MinSizeRel"; break; }
    default { throw "'$Config' is not a valid config; use Release, Debug, RelWithDebInfo, or MinSizeRel)." }
}
$config_lower = $Config.ToLower()

if ($null -eq (Get-Command "cmake.exe" -ErrorAction SilentlyContinue)) {
	Write-Output "Warning, unable to find cmake.exe in your PATH, trying to discover one in Visual Studio installation."
	Push-Location
	$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
	if (Test-Path $vswhere -PathType Leaf ) {
    	$cmakePath = $(Get-Item $( Invoke-Expression '& "$vswhere" -latest -requires Microsoft.VisualStudio.Component.VC.CMake.Project -find Common7/IDE/**/cmake.exe ' )).Directory.FullName
	    if ($null -ne $cmakePath) {
			$env:Path = "$env:Path;$cmakePath"
			Write-Output "Success, CMake added to current PATH from $cmakePath"
		} else {
			Write-Output "Your latest Visual Studio installation does not include CMake package."
		}
	} else {
		Write-Output "No Visual Studio 2017+ was found in the system."
	}
	Pop-Location
}

if ($Generator -eq "default")
{
    $Generator = cmake --help | Where-Object { $_ -match '\*\s+(.*\S)\s+(\[arch\])?\s+=' } | Foreach-Object { $Matches[1].Trim() } | Select-Object -First 1
}

$srcDir = Split-Path $script:MyInvocation.MyCommand.Path

if ($Generator -match 'Visual Studio')
{
    $buildDir = Join-Path -Path $srcDir -ChildPath "build\build"
}
else
{
    $buildDir = Join-Path -Path $srcDir -ChildPath "build\build_$config_lower"
}

$tempPath = [IO.Path]::GetFullPath($env:TEMP)
$buildPath = [IO.Path]::GetFullPath((Join-Path -Path $srcDir -ChildPath "build"))
if ($buildPath.StartsWith($tempPath, [StringComparison]::OrdinalIgnoreCase))
{
    $newTempPath = Join-Path -Path $srcDir -ChildPath "tempdir"
    if (!(Test-Path $newTempPath -PathType Leaf))
    {
        New-Item $newTempPath -ItemType Directory
    }
    $env:TMP = $newTempPath
    $env:TEMP = $newTempPath
}

$libsDir = Join-Path -Path $srcDir -ChildPath "build\libs"
$outDir = Join-Path -Path $srcDir -ChildPath "build\$config_lower"

Write-Output "Source directory: $srcDir"
Write-Output "Build directory:  $buildDir"
Write-Output "Libs directory:   $libsDir"
Write-Output "Output directory: $outDir"
Write-Output "Temp directory:   $env:TEMP"

if ($InstallPath -eq "default")
{
    $InstallPath = Join-Path -Path $srcDir -ChildPath "build\install\$config_lower"
}
elseif (![System.IO.Path]::IsPathRooted($InstallPath))
{
    $InstallPath = Join-Path -Path $srcDir -ChildPath $InstallPath
}

Write-Output "make.ps1 $Command -Config $Config -Generator `"$Generator`" -InstallPath `"$InstallPath`""

if (($Command.ToLower() -ne "libs") -and ($Command.ToLower() -ne "distclean") -and !(Test-Path -Path $libsDir))
{
    throw "Libs directory '$libsDir' does not exist; you may need to run 'make.ps1 libs' first."
}

if ($Generator.Contains("Win64") -or $Generator.Contains("Win32"))
{
    $Architecture = ""
}

switch ($Command.ToLower())
{
    "dummy" { break }
    "libs"
    {
        if (!(Test-Path -Path $libsDir))
        {
            New-Item -ItemType "directory" -Path $libsDir | Out-Null
        }

        $libsBuildDir = Join-Path -Path $srcDir -ChildPath "build\build_libs"
        if (!(Test-Path -Path $libsBuildDir))
        {
            New-Item -ItemType "directory" -Path $libsBuildDir | Out-Null
        }

        $libsSrcDir = Join-Path -Path $srcDir -ChildPath "lib"
        Write-Output "Configuring libraries..."
        if ($Architecture.Length -gt 0)
        {
            Write-Output "cmake.exe -B `"$libsBuildDir`" -S `"$libsSrcDir`" -G `"$Generator`" -A $Architecture -Thost=x64 -DCMAKE_INSTALL_PREFIX=`"$libsDir`" -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_ENABLE_WARNINGS=OFF -DLLVM_ENABLE_TERMINFO=OFF"
            & cmake.exe -B "$libsBuildDir" -S "$libsSrcDir" -G "$Generator" -A $Architecture -Thost=x64 -DCMAKE_INSTALL_PREFIX="$libsDir" -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_ENABLE_WARNINGS=OFF -DLLVM_ENABLE_TERMINFO=OFF
        }
        else
        {
            Write-Output "cmake.exe -B `"$libsBuildDir`" -S `"$libsSrcDir`" -G `"$Generator`" -Thost=x64 -DCMAKE_INSTALL_PREFIX=`"$libsDir`" -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_ENABLE_WARNINGS=OFF -DLLVM_ENABLE_TERMINFO=OFF"
            & cmake.exe -B "$libsBuildDir" -S "$libsSrcDir" -G "$Generator" -Thost=x64 -DCMAKE_INSTALL_PREFIX="$libsDir" -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_ENABLE_WARNINGS=OFF -DLLVM_ENABLE_TERMINFO=OFF
        }
        if (!$?) { throw "Error: exit code $LastExitCode" }

        Write-Output "Building libraries..."
        Write-Output "cmake.exe --build `"$libsBuildDir`" --config Release"
        & cmake.exe --build "$libsBuildDir" --config Release

        Write-Output "Installing libraries..."
        Write-Output "cmake.exe --build `"$libsBuildDir`" --target install --config Release"
        & cmake.exe --build "$libsBuildDir" --target install --config Release
        if (!$?) { throw "Error: exit code $LastExitCode" }
        break
    }
    "cleanlibs"
    {
        if (Test-Path -Path $libsDir)
        {
            Write-Output "Removing $libsDir..."
            Remove-Item -Path $libsDir -Recurse
        }
        break
    }
    "configure"
    {
        if ($Architecture.Length -gt 0)
        {
            Write-Output "cmake.exe -B `"$buildDir`" -S `"$srcDir`" -G `"$Generator`" -A $Architecture -Thost=x64 -DCMAKE_INSTALL_PREFIX="$InstallPath" -DCMAKE_BUILD_TYPE=`"$Config`""
            & cmake.exe -B "$buildDir" -S "$srcDir" -G "$Generator" -A $Architecture -Thost=x64 -DCMAKE_INSTALL_PREFIX="$InstallPath" -DCMAKE_BUILD_TYPE="$Config" --no-warn-unused-cli
        }
        else
        {
            Write-Output "cmake.exe -B `"$buildDir`" -S `"$srcDir`" -G `"$Generator`" -Thost=x64 -DCMAKE_INSTALL_PREFIX="$InstallPath" -DCMAKE_BUILD_TYPE=`"$Config`""
            & cmake.exe -B "$buildDir" -S "$srcDir" -G "$Generator" -Thost=x64 -DCMAKE_INSTALL_PREFIX="$InstallPath" -DCMAKE_BUILD_TYPE="$Config" --no-warn-unused-cli
        }
        if (!$?) { throw "Error: exit code $LastExitCode" }
        break
    }
    "build"
    {
        Write-Output "cmake.exe --build `"$buildDir`" --config $Config --target ALL_BUILD"
        & cmake.exe --build "$buildDir" --config $Config --target ALL_BUILD
        if (!$?) { throw "Error: exit code $LastExitCode" }
        break
    }
    "clean"
    {
        Write-Output "cmake.exe --build `"buildDir`" --config $Config --target clean"
        & cmake.exe --build "$buildDir" --config $Config --target clean

        if (Test-Path $outDir)
        {
            Write-Output "Remove-Item -Path $outDir -Recurse -Force"
            Remove-Item -Path "$outDir" -Recurse -Force
        }
        break
    }
    "distclean"
    {
        if (Test-Path ($srcDir + "\build"))
        {
            Write-Output "Remove-Item -Path `"$srcDir\build`" -Recurse -Force"
            Remove-Item -Path "$srcDir\build" -Recurse -Force
        }
        break
    }
    "test"
    {
        $numTestSuitesRun = 0
        $failedTestSuites = @()

        & $outDir\ponyc.exe --version

        # libponyrt.tests
        $numTestSuitesRun += 1;
        Write-Output "$outDir\libponyrt.tests.exe --gtest_shuffle"
        & $outDir\libponyrt.tests.exe --gtest_shuffle
        if (!$?) { $failedTestSuites += 'libponyrt.tests' }

        # libponyc.tests
        $numTestSuitesRun += 1;
        Write-Output "$outDir\libponyc.tests.exe --gtest_shuffle"
        & $outDir\libponyc.tests.exe --gtest_shuffle
        if (!$?) { $failedTestSuites += 'libponyc.tests' }

        # stdlib-debug
        $numTestSuitesRun += 1;
        Write-Output "$outDir\ponyc.exe -d --checktree --verify -b stdlib-debug -o $outDir $srcDir\packages\stdlib"
        & $outDir\ponyc.exe -d --checktree --verify -b stdlib-debug -o $outDir $srcDir\packages\stdlib
        if ($LastExitCode -eq 0)
        {
            Write-Output "$outDir\stdlib-debug.exe"
            & $outDir\stdlib-debug.exe --exclude="net/Broadcast"
            if (!$?) { $failedTestSuites += 'stdlib-debug' }
        }
        else
        {
            $failedTestSuites += 'compile stdlib-debug'
        }

        # stdlib-release
        $numTestSuitesRun += 1;
        Write-Output "$outDir\ponyc.exe --checktree --verify -b stdlib-release -o $outDir $srcDir\packages\stdlib"
        & $outDir\ponyc.exe --checktree --verify -b stdlib-release -o $outDir $srcDir\packages\stdlib
        if ($LastExitCode -eq 0)
        {
            Write-Output "$outDir\stdlib-release.exe"
            & $outDir\stdlib-release.exe --exclude="net/Broadcast"
            if (!$?) { $failedTestSuites += 'stdlib-release' }
        }
        else
        {
            $failedTestSuites += 'compile stdlib-release'
        }

        # grammar
        $numTestSuitesRun += 1
        Get-Content -Path "$srcDir\pony.g" -Encoding ASCII | Out-File -Encoding UTF8 "$outDir\pony.g.orig"
        & $outDir\ponyc.exe --antlr | Out-File -Encoding UTF8 "$outDir\pony.g.test"
        if ($LastExitCode -eq 0)
        {
            $origHash = (Get-FileHash -Path "$outDir\pony.g.orig").Hash
            $testHash = (Get-FileHash -Path "$outDir\pony.g.test").Hash

            Write-Output "grammar original hash:  $origHash"
            Write-Output "grammar generated hash: $testHash"

            if ($origHash -ne $testHash)
            {
                $failedTestSuites += 'generated grammar file differs from baseline'
            }
        }
        else
        {
            $failedTestSuites += 'generate grammar'
        }

        #
        $numTestSuitesFailed = $failedTestSuites.Length
        Write-Output "Test suites run: $numTestSuitesRun, num failed: $numTestSuitesFailed"
        if ($numTestSuitesFailed -ne 0)
        {
            $failedTestSuitesList = [string]::Join(', ', $failedTestSuites)
            Write-Output "Test suites failed: ($failedTestSuitesList)"
            exit $numTestSuitesFailed
        }

        break
    }
    "install"
    {
        Write-Output "cmake.exe --build `"$buildDir`" --config $Config --target install"
        & cmake.exe --build "$buildDir" --config $Config --target install
        if (!$?) { throw "Error: exit code $LastExitCode" }

        break
    }
    "package"
    {
        switch ($Version)
        {
            "default" { $Version = (Get-Content $srcDir\VERSION) + "-" + (git rev-parse --short --verify HEAD^) }
            "date" { $Version = (Get-Date).ToString("yyyyMMdd") }
        }

        $package = "ponyc-x86_64-pc-windows-msvc-$Version-$Config.zip"
        Write-Output "Creating $buildDir\$package"

        Compress-Archive -Path "$InstallPath\ponyc", "$InstallPath\packages", "$InstallPath\examples" -DestinationPath "$buildDir\$package" -Force
    }
    default
    {
        throw "Unknown command '$Command'; use: {libs, cleanlibs, configure, build, clean, distclean, test, install}"
    }
}
