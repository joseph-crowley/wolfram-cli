# Wolfram CLI Helpers

Lightweight notes and sanity checks for running Mathematica/Wolfram Engine tooling from the command line on macOS.

## Quick Start

1. Verify the binaries:

   ```sh
   ls /Applications/Wolfram.app/Contents/MacOS
   /Applications/Wolfram.app/Contents/MacOS/wolframscript -version
   ```

2. Add the directory to PATH (temporary example):

   ```sh
   export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
   ```

3. Run the supplied smoke commands:

   ```sh
   wolframscript -code 'N[Zeta[3], 50]'
   printf 'FactorInteger[2^61 - 1]\nQuit[]\n' | WolframKernel -noprompt
   wolframscript -code 'Export["bessel.pdf", Plot[BesselJ[0,x], {x,0,30}]]'
   ```

## Documentation

- `RUNBOOK.md` – detailed runbook covering installation checks, scripting patterns, argument handling, exports, and troubleshooting (last verified October 14, 2025).
- `FIELD_MANUAL.md` – PhD-level CLI-first physics workflows with end-to-end scripts, argument parsing, and package guidance.

## Conventions

- Commands assume Mathematica is installed at `/Applications/Wolfram.app`.
- For shebang scripts, ensure `wolframscript` is on PATH or prefix invocations with the PATH override shown above.

## Next Steps

- Consider adding a `Makefile` or small test harness to automate the sanity checks.
- Share the runbook with teammates to keep CLI usage consistent across machines.
