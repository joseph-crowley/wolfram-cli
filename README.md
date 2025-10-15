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
- `scripts/` – runnable `.wls` toolkit (Fourier transforms, oscillators, FEM problems, QHO spectra, Clebsch-Gordan tables, partition functions, Dirac traces, FEM eigenmodes, Levi-Civita identities, smoke tests).

## Scripts

- `scripts/fourier_gaussian.wls` – Fourier transform of a shifted Gaussian with configurable parameters and JSON output.
- `scripts/damped_oscillator.wls` – forced damped oscillator with CSV export of the response.
- `scripts/helmholtz_square.wls` – FEM solve of a Helmholtz boundary value problem on the unit square.
- `scripts/qho_eigs.wls` – lowest harmonic oscillator eigenvalues via FEM and JSON export.
- `scripts/clebsch_gordan_table.wls` – tabulate non-zero Clebsch-Gordan coefficients in JSON.
- `scripts/partition_fn.wls` – canonical partition function from a supplied discrete spectrum.
- `scripts/billiard_eigs.wls` – eigenmodes of a stadium billiard with image exports.
- `scripts/dirac_trace.wls` – FeynCalc-powered trace of gamma matrices (bootstraps FeynCalc if needed).
- `scripts/levi_civita_check.wls` – Levi-Civita tensor identity using `TensorReduce`.
- `scripts/residue_demo.wls`, `scripts/asymptotic_integral.wls` – analytic one-offs for residue and asymptotic checks.
- `scripts/smoke_tests.wls` – verification tests; target for CI and `make smoke`.

## Usage Cheatsheet

- Flags: Every script accepts long `--key=value` flags (no spaces). Defaults are sensible; run with no flags to use defaults.
- JSON vs text: Scripts emitting symbolic results return JSON with those expressions as InputForm strings in the `transform` field; numeric arrays (energies, coefficients, etc.) are emitted as proper JSON numbers.
- Examples:
  - Fourier (JSON to stdout):
    `wolframscript -file scripts/fourier_gaussian.wls --mu=0 --sigma=1 --t=0 | jq -r .transform`
  - Damped oscillator (CSV file):
    `wolframscript -file scripts/damped_oscillator.wls --gamma=0.05 --omega0=1 --F=1 --Omega=1 --tmax=10 --out=x.csv`
  - QHO eigenvalues (JSON file):
    `wolframscript -file scripts/qho_eigs.wls --n=6 --L=8 --m=1 --omega=1 --out=qho_energies.json`
  - Partition function from QHO energies:
    `wolframscript -file scripts/partition_fn.wls --beta=1.0 --in=qho_energies.json`
  - Clebsch–Gordan table:
    `wolframscript -file scripts/clebsch_gordan_table.wls --j1=1 --j2=1 --J=2 | jq .`
  - Levi-Civita cross product components:
    `wolframscript -file scripts/levi_civita_check.wls`

## Make Targets

- `make smoke` – runs `scripts/smoke_tests.wls` and propagates exit code.
- `make qho` – computes QHO energies with default flags (see `Makefile`).
- `make helmholtz`, `make billiards` – FEM examples; may require FEM-enabled license.

## Conventions and Caveats

- PATH: `export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"` to use `wolframscript` without absolute paths.
- Protected names: avoid `N`, `C`, etc.; scripts use ASCII flag names like `--n`, `--omega`.
- Symbolic JSON: symbolic expressions are stringified via `InputForm` to ensure strict JSON; parse with downstream tools as strings if needed.
- FEM license: some FEM-heavy scripts (`helmholtz_square.wls`, `billiard_eigs.wls`) require FEM functionality; if you encounter a license error, skip these or run on a licensed install.

## Conventions

- Commands assume Mathematica is installed at `/Applications/Wolfram.app`.
- For shebang scripts, ensure `wolframscript` is on PATH or prefix invocations with the PATH override shown above.

## Next Steps

- Consider adding a `Makefile` or small test harness to automate the sanity checks.
- Share the runbook with teammates to keep CLI usage consistent across machines.
