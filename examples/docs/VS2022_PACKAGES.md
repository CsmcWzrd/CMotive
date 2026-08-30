# VS2022 package and example browsing

Open `vs2022/CMotive.LangExamples.Packages.sln` to browse the example package
inputs and project metadata.

Build the self-hosted compiler from the main source package first. The examples
expect `cmotive.exe` and `cmotivepp.exe` under the configured CMotive build
output. No Python helper is invoked by the project or example scripts.
