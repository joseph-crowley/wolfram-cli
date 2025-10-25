# Robust Photon Positivity Under Fat-Tailed Spectral Uncertainty

## Objective
- Extend priority problem A (photon-photon EFT positivity) by upgrading the dispersion workflow into a convex optimisation engine that bounds the Wilson coefficients `a1` and `a2` when only fat-tailed partial-wave moments are known.
- Quantify how Pareto-governed ultraviolet spectra and per-node caps propagate into worst-case and best-case values of the Euler-Heisenberg coefficients.
- Deliver machine-readable artefacts that expose saturation patterns, effective mass scales, and resilience diagnostics so downstream automation can reason about rare outliers.

## Distinction from Prior Attempts
- `problems/eft-positivity-photon-photon` encodes analytic inequalities (`c1 > 0`, `c2 > 0`, `c1 + c2 > 0`) for fixed amplitudes. It does not examine spectral uncertainty.
- `problems/eft-positivity-dispersion` evaluates f2 and g2 directly for a chosen discrete spectrum, producing single-point estimates with tail diagnostics.
- This project treats the spectral weights as decision variables constrained by Pareto envelopes, total-moment equalities, and non-negativity. A linear program then produces global bounds on `(a1, a2)` and reports the extremal spectral allocations. This captures worst-case behaviour across entire fat-tailed ensembles rather than a single draw.

## Methodology
- Construct a logarithmic mass grid between `massMin` and `massMax` (defaults: 0.7 GeV to 120 GeV, 18 nodes).
- Assign four non-negative spectral weight families (`rho1`, `rho2`, even-spin `rho3`, odd-spin `rho3`) with totals supplied via CLI flags. Each family receives Pareto-style per-node caps determined by `tailExponent` and `capMultiplier`.
- Form linear coefficients for `f2` and `g2` using the spin-dependent prefactors from the dispersion relations (`factor0 = 16 pi`, `factor2 = 80 pi`, `factor3 = 112 pi`) divided by `mass^6`.
- Solve a sequence of linear programs via `NMinimize`: minimise and maximise `a1`, minimise and maximise `a2`, and minimise directional combinations of `(a1, a2)` supplied through `--objectiveDirections`.
- Report the optimal coefficients, corresponding `f2` and `g2`, mean mass per spectral family, counts of saturated caps, and the full solution vectors for reproducibility.

## Usage
```
/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/eft-positivity-robust/robust_positivity_lp.wls \
  > problems/eft-positivity-robust/bounds_default.json

/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/eft-positivity-robust/robust_positivity_lp.wls \
  --tailExponent=2.1 \
  --capMultiplier=1.2 \
  --massMax=150 \
  --rho2Total=3.0 \
  --evenTotal=0.8 \
  > problems/eft-positivity-robust/bounds_shallow_tail.json

/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/eft-positivity-robust/robust_positivity_lp.wls \
  --tailExponent=4.5 \
  --capMultiplier=3.0 \
  --rho1Total=2.0 \
  --rho2Total=2.5 \
  --oddTotal=0.6 \
  > problems/eft-positivity-robust/bounds_tight_tail.json
```
- Flags accept JSON arrays for `--objectiveDirections` (list of two-component vectors), `--masses` (optional custom grid), or alternative totals if required by downstream studies.
- Outputs are ASCII JSON conforming to repository conventions, suitable for ingestion by downstream WL or Python tooling.

## Results
- **Default envelope** (`tailExponent = 3.2`, `capMultiplier = 1.8`, totals `rho1 = 1.6`, `rho2 = 2.4`, `even = 0.5`, `odd = 0.35`):
  - `a1` lies between roughly `9.3e1` and `2.39e2`, while `a2` ranges from `3.38e1` to `1.80e2`.
  - The minimiser pushes all families to the Pareto caps at masses near `1.05 GeV`, evidencing saturation of the fat-tail envelope across 17 of 18 nodes.
  - The maximiser concentrates all weight at the lightest mass node (`0.7 GeV`), demonstrating that small-mass resonances dominate the upper bound when caps are loose.
- **Shallow tail stress** (`tailExponent = 2.1`, `capMultiplier = 1.2`, heavier `rho2` and `even` totals):
  - The narrower caps expand `a1` between `1.27e2` and `1.86e2`, shrinking the allowed band and forcing mean masses to `1.25 GeV`.
  - Cap saturation remains near-complete, confirming that fat-tail allowances, not total magnitude, control the extremal solutions.
- **Tight tail with larger totals** (`tailExponent = 4.5`, `capMultiplier = 3.0`, `rho1 = 2.0`, `rho2 = 2.5`, `odd = 0.6`):
  - `a1` widens to `9.82e1` through `2.99e2`, and `a2` spans `2.73e1` to `2.28e2`, indicating that heavier totals combined with permissive caps reintroduce substantial uncertainty.
  - Lower bounds again saturate 17 caps, while upper bounds only need three to four low-mass nodes, reinforcing the fat-tailed risk asymmetry.

## Diagnostics and Resilience
- Every output captures the number of nodes at their cap per spectral family, the effective mean mass, and the full decision vector. These diagnostics expose when optimisation rides the cap limits versus distributing weight broadly.
- Directional scans (defaults: `{±1,0}`, `{0,±1}`, `{1,±1}`, `{1,-1}`) provide supporting vertices so downstream tools can reconstruct the convex hull of feasible `(a1, a2)`.
- Failures are reported as JSON with `status = "error"` and include the offending options; no partial data is emitted on invalid arguments.

## Files
- `robust_positivity_lp.wls` — Wolfram CLI script implementing the Pareto-capped linear program.
- `bounds_default.json` — Baseline envelope solution with exhaustive cap saturation.
- `bounds_shallow_tail.json` — Shallower tail, tighter caps, heavier even-spin totals.
- `bounds_tight_tail.json` — Steeper tail with enlarged totals, showcasing widened bounds.

## References
https://reference.wolfram.com/language/ref/LinearOptimization.html
https://reference.wolfram.com/language/ref/NMinimize.html
