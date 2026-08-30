# Visual Studio 2022 projects

Open `vs2022/CMotive.Packages.sln` from a Visual Studio 2022 Developer Command
Prompt or the Visual Studio IDE.

The `CMotive.SelfHostedFrontend` project invokes
`vs2022/build-selfhost.cmd`. It builds the isolated C stage-0 seed, emits and
compiles the CMotive stage-1 frontend, emits and compiles the stage-2 frontend,
builds `c2cmotive` from CMotive source, and compares the stage-1/stage-2/stage-3
generated C files.

Outputs are written below:

```text
build/bin/<Configuration>-<Platform>/
build/vs2022/selfhost/<Configuration>-<Platform>/
```

The package scaffold project remains available for `src/packages` browsing and
static-library experiments. The self-hosted frontend project is the active
compiler build path.

The project definitions include x64 and ARM64 configurations. Native VS2022
execution was not available in the Linux verification environment; the script
and project files are provided for Windows builds and should be run from a
Developer Command Prompt where `cl.exe` and `link.exe` are available.
