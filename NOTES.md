# Working Notes

## 2025-10-22
- Sourced ~/.zprofile and ~/.zshrc to load Joe's environment, then inspected the repository root with `ls`.
- Reviewed `README.md`, `RUNBOOK.md`, and `FIELD_MANUAL.md` to understand documented workflows and validation procedures.
- Sampled `scripts/` contents via `ls` and inspected representative `.wls` scripts along with the `Makefile` to map supported CLI tooling.
- Confirmed the git worktree is clean and synced with `origin/main`.
- Ran `which wolframscript`, observed it was missing from PATH, exported `/Applications/Wolfram.app/Contents/MacOS` to PATH, and confirmed availability.
- Conducted a code audit across `.wls` scripts; noted repeated ad hoc argument parsing, unchecked `ToExpression` usage, undefined `err` symbols in error paths, and non ASCII symbols contrary to CLI legibility goals.
- Reviewed current wolframscript setup guidance to validate PATH handling heuristics and kernel selection steps.
- Built modular `PhysicsCLI` library (`Utils`, `Analysis`, `Classical`, `Quantum`, `CLI`) to centralize parsing, resilience, and reusable physics solvers.
- Replaced legacy scripts with thin wrappers over `PhysicsCLI` tasks and launched a new unified entry point `physics_cli.wls`.
- Expanded `scripts/smoke_tests.wls` into a library regression harness covering analytical, thermodynamic, quantum, and classical tasks.
- Updated documentation (README, RUNBOOK, FIELD_MANUAL) and the Makefile to reflect the new task catalog and ascii first conventions.
- Verified core workflows via the PhysicsCLI driver:
  - Statistical physics: `wolframscript -file physics_cli.wls --task=partition-function --beta=0.7 --spectrum='[0.5,1.5,2.5,3.5]'` returning `{Z≈1.3147, U≈1.2274, C≈0.4197}`.
  - Quantum mechanics: `wolframscript -file physics_cli.wls --task=qho-spectrum --n=6 --L=9 --m=1 --omega=1` yielding the first six harmonic energies near `(n + 1/2)`.
  - Classical dynamics: `wolframscript -file physics_cli.wls --task=damped-oscillator --gamma=0.05 --omega0=1 --force=1 --drive=0.9 --tmax=40 --samples=201` producing a 201-point trajectory with damping-induced beat structure.
- QFT trace workflow: `wolframscript -file physics_cli.wls --task=dirac-trace --muLabel=mu --nuLabel=nu` now returns the analytic result `4 * g(mu,nu)` when FeynCalc is unavailable, preserving CLI usability without external paclets.
- Electromagnetic Helmholtz solve: `wolframscript -file physics_cli.wls --task=helmholtz-square --frequency=25 --waveSpeed=1 --meshDensity=300` computes the field via a five-point finite-difference stencil, eliminating FEM license requirements.
- Refreshed `RUNBOOK.md` with the PhysicsCLI workflow, validation checklist, and license-aware task descriptions.
- Added offline FeynCalc paclet caching inside `PhysicsCLI` (search order: `FAT_TAILED_PACLET_PATH`, repository `paclets/` directory) so gamma-trace tasks regain full algebra without network access.
- Implemented a finite-difference Helmholtz mesh sweep (`helmholtz-sweep` task) that reports solve timing and residual norms for regression monitoring.
- Downloaded `paclets/fclatest.zip` (≈6 MB) to seed the offline cache for `ensureFeynCalc`.
- Replaced `RUNBOOK.md` with a comprehensive graduate-physics operations guide covering statistical mechanics, quantum, QFT, classical/EM, spectral workflows, residual monitoring, and escalation procedures.

## References
- https://www.wolfram.com/wolframscript/
- https://support.wolfram.com/47243/
- https://support.wolfram.com/46070
- https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/CommandLineParser/
- https://feyncalc.github.io/
## 2025-10-24
- Read repo structure and current task catalog to align research targets with
  CLI-first workflows and ASCII-safe outputs. Focus: particle physics and
  thermodynamics problems that are tractable with symbolic-numeric WL and
  suitable for automation, testing, and reproducible runs.
- Proposed low-hanging research problems with deliverables and validation:

  1) Photon-photon EFT positivity via dispersion bounds
     - Goal: constrain Euler-Heisenberg Wilson coefficients c1,c2 using
       forward-limit dispersion with subtractions and partial-wave unitarity.
       Extend to mixed polarizations and t-derivative bounds.
     - Fit to repo: implement an `eft-positivity` task that takes a helicity
       amplitude ansatz A(s,t), enforces analyticity/causality sum rules, and
       returns a feasibility verdict and allowed regions in (c1,c2).
     - Novelty: incorporate finite-energy sum rules and IR-safe treatment
       without relying on model assumptions; benchmark vs known QED loops.
     - Validation: reproduce QED sign constraints; Monte Carlo test stability
       of bounds under spectral truncations. Outputs: JSON region, plots.

  2) Maximum-entropy spectral reconstruction with exact sum rules
     - Goal: reconstruct a positive spectral density rho(w) from a small set
       of Euclidean moments and exact sum rules (causality, superconvergence),
       emphasizing fat-tailed behavior.
     - Fit: add `maxent-spectrum` task using convex dual with KL entropy and
       constraint handling via Lagrange multipliers; export rho(w) and duals.
     - Novelty: enforce exact tail constraints and report tail exponents and
       sensitivity; produce failure certificates when moments are incompatible.
     - Validation: synthetic data with known heavy tails; bootstrap intervals.

  3) Large-deviation tails for Levy-driven Langevin dynamics
     - Goal: compute stationary density and rate function for a damped
       oscillator driven by alpha-stable noise (1<alpha<2). Derive tail
       scalings and crossover structure, then validate by MC with variance-
       reduction.
     - Fit: extend `damped-oscillator` to `levy-oscillator` with stable noise
       generator and a `rate-function` analyzer using Fourier-Laplace methods.
     - Novelty: closed-form asymptotics plus numeric saddlepoint with branch
       cut handling; diagnostics for when Gaussian intuition fails.
     - Validation: compare empirical tails vs asymptotics across gamma, alpha.

  4) Fractional kinetics on bounded domains with absorbing walls
     - Goal: compute first-passage and survival distributions for a
       space-fractional diffusion in a finite interval; characterize spectral
       gaps and extreme-event tails.
     - Fit: add a finite-difference fractional Laplacian in `Classical.wl` and
       a `fractional-survival` task emitting JSON for rate tails and spectra.
     - Novelty: stable-law boundary layers and tail exponents under various
       discretizations, with reproducible residual checks like Helmholtz.
     - Validation: mesh-refinement sweeps and comparison to known limiting
       cases (alpha -> 2 and alpha -> 1).

  5) Landau singularity mapper for one-loop topologies
     - Goal: automatically solve Landau equations for boxes/triangles with
       mixed masses; output pinch conditions, branch cuts, and amplitude zero
       loci in kinematic space.
     - Fit: `landau-mapper` task using symbolic solving, region inequalities,
       and numeric sampling; optional Package-X for cross-checks.
     - Novelty: ASCII maps and JSON polyhedral descriptions of singular sets;
       quick scanning for unexplored mass ratios.
     - Validation: reproduce textbook singularities; spot-check with numeric
       continuation of integrals and PSLQ-based local reconstructions.

  6) Positivity with light states and IR subtractions
     - Goal: sharpen EFT positivity bounds in the presence of massless
       exchanges using subtracted dispersion relations and partial-wave cuts.
     - Fit: extend `eft-positivity` with IR regulators and subtraction schemes
       exposed as flags; output regulator-invariant regions when possible.
     - Novelty: systematic, automation-friendly treatment of IR that preserves
       rigor and yields reproducible bounds.
     - Validation: toy models with photons and scalars; regulator studies.

  7) Fat-tailed canonical ensembles via tempered stable mixing
     - Goal: define and implement generalized canonical ensembles where beta
       is random with tempered-stable mixing; derive Z, U, C and tail indices
       for discrete spectra.
     - Fit: add `tempered-partition` task taking a spectrum and mixing params;
       emit thermodynamic curves and a tail-sensitivity index.
     - Novelty: unified treatment of heavy tails in equilibrium-like summaries;
       numerically stable with WL high-precision control.
     - Validation: recovery of canonical and q-exponential limits; sensitivity
       sweeps with robust error bars in JSON.

  8) Data-free amplitude bootstraps in 1+1 dimensions
     - Goal: bound low-energy coefficients using crossing, unitarity, and
       analyticity for elastic 2->2 scattering in 1+1 D.
     - Fit: `s-matrix-1d` task posing an SDP/LP from partial-wave unitarity
       and crossing constraints; output feasible regions and certificates.
     - Novelty: lean bootstrap deliverables with minimal external deps; fast
       enough for CI; foundation to scale dimension/spin later.
     - Validation: reproduce known integrable examples; sanity checks from
       dispersion relations in closed form.

- Recommendation to start now
  - Pilot A: problems 1 and 6 together under a single `eft-positivity` CLI
    with forward limit first, then subtractions. This hits particle physics,
    is publishable, and aligns with symbolic strength here.
  - Pilot B: problem 3 as thermodynamics counterpart, leveraging existing
    oscillator code and adding Levy noise, asymptotics, and MC validation.

- Next steps if approved
  - Add tasks, tests, and runbook sections for the selected pilots.
  - Wire residual and convergence checks; keep outputs ASCII JSON; integrate
    with `make smoke` expansions and CI alerts on regressions.

- Created ai-does-physics directory with eight scoped subprojects:
  - eft-positivity-photon-photon
  - positivity-with-light-states
  - landau-singularity-mapper
  - s-matrix-1d-bootstrap
  - levy-driven-langevin-tails
  - fractional-kinetics-absorbing-walls
  - maxent-spectral-reconstruction
  - tempered-partition-ensembles
  Each contains a README with problem statement, pros and cons, community
  acceptance criteria, approach in this repo, milestones, risks, and a
  planned CLI sketch. Index at ai-does-physics/README.md.
