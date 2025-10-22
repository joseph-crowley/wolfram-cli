# Wolfram CLI Graduate Physics Runbook

Last verified: October 22, 2025 on macOS (Mathematica 14.1, WolframScript 1.13.0). This runbook is the authoritative checklist for operating PhysicsCLI at Fat Tailed Solutions. It covers environment hygiene, offline paclet caching, and end-to-end workflows for graduate-level physics domains (statistical mechanics, quantum mechanics, quantum field theory, electrodynamics, spectral/chaotic systems).

---

## 1. Environment and Bootstrap

1. **Wolfram binaries**
   ```sh
   ls /Applications/Wolfram.app/Contents/MacOS
   /Applications/Wolfram.app/Contents/MacOS/wolframscript -version
   ```
   Confirm the version banner before proceeding. PhysicsCLI assumes WolframScript ≥ 1.13.

2. **Session PATH**
   ```sh
   export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
   ```
   Add this line to `~/.zprofile` and `~/.zshrc` so Codex sessions inherit it automatically.

3. **Repository layout**
   ```text
   physics_cli.wls                 # consolidated driver
   lib/PhysicsCLI/                 # modular packages (Utils, Analysis, Classical, Quantum, CLI)
   scripts/                        # backwards-compatible wrappers
   paclets/                        # offline paclet cache (FeynCalc, etc.)
   NOTES.md                        # operational log
   RUNBOOK.md                      # this document
   FIELD_MANUAL.md                 # advanced workflows, theory notes
   ```

4. **Offline FeynCalc cache**
   - Place `FeynCalc.paclet` or `fclatest.zip` in `paclets/`.
   - Optional: set `FAT_TAILED_PACLET_PATH=/path/to/cache`.
   - PhysicsCLI prioritises `.paclet` archives and falls back to `fclatest.zip` during installation.

5. **First-time validation**
   ```sh
   cd /Users/joe/code/wolfram-cli
   make smoke
   ```
   Expect `tests run=4 failures=0`. Record the outcome in `NOTES.md`.

---

## 2. Command-Line Interface Essentials

### 2.1 Unified driver
All tasks are exposed through `physics_cli.wls`:
```sh
wolframscript -file physics_cli.wls --task=<name> [--key=value ...] [--output=json|text]
```

### 2.2 Wrapper scripts
Legacy scripts in `scripts/` call the shared library for ease of automation (Make, CI). They accept the same `--key=value` flags and emit ASCII-safe JSON or CSV.

### 2.3 Input conventions
- Numbers: parsed using hardened validators (decimal/rational/exponential). No raw `ToExpression`.
- Vectors: JSON arrays (`--spectrum='[0.5,1.5,2.5]'`).
- Booleans: `true`/`false` (case-insensitive) or `1`/`0`.
- Output is JSON unless `--output=text` is specified.

---

## 3. Quick Validation Checklist (Daily/Before Deployment)

```sh
make smoke
wolframscript -file physics_cli.wls --task=partition-function --beta=0.7 --spectrum='[0.5,1.5,2.5,3.5]'
wolframscript -file physics_cli.wls --task=qho-spectrum --n=6 --L=9 --m=1 --omega=1
wolframscript -file physics_cli.wls --task=damped-oscillator --gamma=0.05 --omega0=1 --force=1 --drive=0.9 --tmax=40 --samples=201
wolframscript -file physics_cli.wls --task=helmholtz-square --frequency=25 --waveSpeed=1 --meshDensity=300
wolframscript -file physics_cli.wls --task=helmholtz-sweep --densities='[150,200,300,400]' --frequency=25 --waveSpeed=1
wolframscript -file physics_cli.wls --task=dirac-trace --muLabel=mu --nuLabel=nu
```

Record command outputs (success, residuals, cached paclet behaviour) in `NOTES.md`. Escalate anomalies immediately; do **not** proceed to experimentation until resolved.

---

## 4. Domain Playbooks

### 4.1 Statistical Mechanics
Objective: compute canonical thermodynamics from discrete spectra (fat-tailed energy samples).

1. **Generate spectrum (if needed)**
   ```sh
   wolframscript -file physics_cli.wls --task=qho-spectrum --n=10 --L=9 --m=1 --omega=1
   ```
   Output: JSON with energies and suggested file.

2. **Partition function & moments**
   ```sh
   wolframscript -file physics_cli.wls \
     --task=partition-function \
     --beta=0.7 \
     --spectrum='[0.5,1.5,2.5,3.5]'
   ```
   Returns `{Z, U, C}` with 15-digit precision.

3. **Notes**
   - Accepts inline arrays or `--in=filename`.
   - For fat-tailed ensembles, sweep `beta` and capture outputs in downstream Python/Rust for plotting.
   - Verify energy support: ensure no negative or complex entries unless modelling specific systems.

### 4.2 Quantum Mechanics and Angular Momentum
#### Harmonic Oscillator via FEM
```sh
wolframscript -file physics_cli.wls --task=qho-spectrum --n=8 --L=10 --m=0.5 --omega=2 --output=json
```
Outputs eigenvalues; compare against analytical `(n + 1/2) ℏω`.

#### Clebsch–Gordan Coefficients
```sh
wolframscript -file physics_cli.wls --task=clebsch-gordan --j1=1 --j2=1.5 --J=2.0
```
The JSON payload lists all non-zero coefficients. Use `jq` or Python for downstream filtering.

### 4.3 Quantum Field Theory (Dirac Algebra)
1. **Ensure FeynCalc cache**: confirm `paclets/fclatest.zip` or `FeynCalc.paclet` exists.
2. **Dirac trace**:
   ```sh
   wolframscript -file physics_cli.wls --task=dirac-trace --muLabel=mu --nuLabel=nu
   ```
   - If FeynCalc loads successfully, expect `Result: "4 * MetricTensor[mu, nu]"` with `Method: "FeynCalc"`.
   - If caching fails, fallback is `4 * g(mu,nu)` (analytic Clifford trace). Investigate paclet availability.
3. **Extending traces**: for higher-rank structures, edit `lib/PhysicsCLI/Quantum.wl` or run FeynCalc interactively (`Get["lib/PhysicsCLI/Quantum.wl"]; ensureFeynCalc[];` etc.).

### 4.4 Classical Dynamics and Electrodynamics
#### Damped Oscillator
```sh
wolframscript -file physics_cli.wls --task=damped-oscillator \
  --gamma=0.05 --omega0=1 --force=1 --drive=0.9 --tmax=60 --samples=1201 --output=json
```
Inspect `Trajectory` (time/displacement tuples). Export to CSV using wrapper script or `jq`.

#### Helmholtz Solver (Finite Difference)
```sh
wolframscript -file physics_cli.wls --task=helmholtz-square \
  --frequency=25 --waveSpeed=1 --meshDensity=400
```
Returns sampled field, solve time, residual RMS, and max residual. Use the data to plot iso-surfaces or feed into verification scripts.

#### Mesh-Density Regression
```sh
wolframscript -file physics_cli.wls --task=helmholtz-sweep \
  --frequency=25 --waveSpeed=1 --densities='[150,200,300,400,500]'
```
Log residual trends to ensure numerical stability and detect regressions.

#### Transverse-Field Zeroes
- Goal: verify a complex scalar seed solves the wave equation, construct E and B that solve source-free Maxwell, and locate transverse zero sets in a large-g limit.
- Location: problems/transverse-field-zeroes
- How to run:
  - export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
  - wolframscript -file problems/transverse-field-zeroes/solve.wls
- Expected artifacts:
  - report.txt with symbolic verification: wave-equation True; Ampere residuals {0,0,0}; Ez expression; zero-locus statements.
  - sketch.png visualizing the electric zero axis and the magnetic elliptic helix.
- Operational notes:
  - Set $Assumptions for real variables and positive parameters; apply c = omega/k during PDE checks.
  - Use ComplexExpand before imposing real equalities on phasor-derived expressions.
  - Keep outputs ASCII via InputForm; avoid front-end dependencies to enable headless runs.

### 4.5 Spectral/Chaotic Systems
```sh
wolframscript -file physics_cli.wls --task=stadium-billiard \
  --modes=10 --meshMax=0.02 --radius=0.5
```
Requires FEM licence. Outputs eigenvalues and sampled modes (PNG export handled by wrapper). For cost control, run on licensed machines only.

---

## 5. Automation and CI Hooks

1. **Make targets**
   ```sh
   make smoke
   make helmholtz
   make helmholtz-sweep
   make partition
   ```
2. **CI recommendation**
   - Run `make smoke` on every commit.
   - Schedule `make helmholtz-sweep` daily; alert if residual RMS drifts above `1e-10`.
   - Include `dirac-trace` command to confirm cached FeynCalc remains functional.

3. **Logging**
   - Append command outcomes to `NOTES.md` with timestamp.
   - Store JSON outputs in `artifacts/` if needed for longer-term audits (do not commit large data).

---

## 6. Performance, Accuracy, and Cost Management

| Task | Tunable knobs | Guidance |
| --- | --- | --- |
| `partition-function` | Spectrum size, precision | Keep arrays sorted; use high-precision values if variance is extreme. |
| `qho-spectrum` | Domain half-width `L`, element maximum iteration | Increase `L` for higher modes; watch CPU time (`Method -> MaxIterations`). |
| `dirac-trace` | Paclet cache | Keep paclet zipped to minimise repo size; ensure hashed copy in secure storage. |
| `helmholtz-square` | `meshDensity` (points per axis ≈ density/10) | RMS residual target: `< 1e-10`. Use sweep to calibrate. |
| `damped-oscillator` | `samples`, `tmax` | For FFT analysis choose power-of-two samples; maintain `samples >= 200` for 40-second windows. |

Resource tip: run heavy tasks on Azure burst nodes only when necessary. The finite-difference Helmholtz solver is CPU-bound but license-free; QHO and stadium tasks require FEM and may incur licence costs.

---

## 7. Troubleshooting Matrix

| Symptom | Immediate action | Resolution |
| --- | --- | --- |
| `wolframscript: command not found` | Ensure PATH export in current shell | `export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"` |
| `FeynCalc archive not found` | Verify `paclets/` contents | Download `FeynCalc.paclet` or `fclatest.zip` and retry |
| Dirac trace returns unresolved FeynCalc expressions | Check paclet install logs in stdout | If unresolved, CLI auto-falls back; investigate local FeynCalc install |
| `make smoke` fails after successful PATH export | Inspect `scripts/smoke_tests.wls` output | Resolve Mathematica errors before continuing |
| Helmholtz residuals > `1e-9` | Run `helmholtz-sweep` with finer densities | Adjust `meshDensity`; inspect boundary conditions |
| FEM licence errors (stadium, FEM wrappers) | Use finite-difference alternatives | Run on FEM-enabled nodes or skip FEM demos |

---

## 8. Operational Hygiene

1. **ASCII only** – PhysicsCLI enforces ASCII outputs; keep logs/csv free of special characters.
2. **NOTES.md discipline** – log date, commands run, anomalies, fix status.
3. **Git hygiene** – commit and push after every coherent change; avoid committing large generated files.
4. **Backups** – store cached paclets in the secure company artifact store in addition to repo inclusion.
5. **Security** – FeynCalc archives are trusted from official site; verify checksums when downloading manually.

6. **Language policy (WL-only)**
   - Use Wolfram Language exclusively for problem solutions and automation in this repository.
   - Do not commit Python or other non-WL sources under `problems/` or `scripts/`.
   - If temporary Python exploration is unavoidable, keep it outside the repo or in a local scratch area and do not commit artifacts.
   - Prefer `wolframscript` headless flows; avoid notebooks in version control for operational runs.

---

## 9. Reference Cheat Sheet

| Goal | Command |
| --- | --- |
| Validate repo | `make smoke` |
| Compute thermodynamics | `wolframscript -file physics_cli.wls --task=partition-function --beta=<β> --spectrum='[...]'` |
| QHO eigenvalues | `wolframscript -file physics_cli.wls --task=qho-spectrum --n=10 --L=12 --m=1 --omega=0.8` |
| Clebsch–Gordan table | `wolframscript -file physics_cli.wls --task=clebsch-gordan --j1=2 --j2=1.5 --J=1` |
| Dirac gamma trace (cached) | `wolframscript -file physics_cli.wls --task=dirac-trace --muLabel=mu --nuLabel=nu` |
| Damped oscillator CSV | `wolframscript -file scripts/damped_oscillator.wls --gamma=0.1 --omega0=1 --force=2 --drive=1.2 --tmax=30 --samples=601 --out=osc.csv` |
| Helmholtz solution | `wolframscript -file physics_cli.wls --task=helmholtz-square --frequency=30 --waveSpeed=1 --meshDensity=500` |
| Helmholtz residual sweep | `wolframscript -file physics_cli.wls --task=helmholtz-sweep --densities='[200,300,400,500]'` |
| Stadium eigenmodes (FEM) | `wolframscript -file physics_cli.wls --task=stadium-billiard --modes=12 --meshMax=0.02 --radius=0.5` |

---

## 10. Escalation Protocol

1. **On failure** (test suite, command, or residual threshold):
   - Stop other work.
   - Capture stderr/stdout.
   - Update `NOTES.md` with details.
   - Notify Joe and the Fat Tailed Solutions engineering channel.

2. **On success after fix**:
   - Re-run the validation checklist.
   - Document the remediation steps in `NOTES.md`.
   - Push commits with descriptive messages.

Following this runbook keeps the PhysicsCLI toolchain reproducible, licence-compliant, and ready for both local exploration and Azure-scale automation across fat-tailed physics workloads.
