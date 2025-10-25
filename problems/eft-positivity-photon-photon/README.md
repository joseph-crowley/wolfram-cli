# Photon-Photon EFT Positivity

## Overview
- Objective: codify forward-limit positivity bounds for the Euler-Heisenberg light-by-light effective action with Wilson coefficients `c1` and `c2`.
- Business value: supplies a fast sanity gate for proposed fat-tailed photon sector modifications and validates that Standard Model loops respect analyticity and unitarity requirements.
- Deliverables: Wolfram CLI script `positivity_analysis.wls` plus JSON summaries `positivity_summary.json` (Standard Model baseline) and `positivity_counterexample.json` (paths that violate positivity).

## Method
- Encoded analytic helicity amplitudes for `++++`, `++--`, and `+-+-` channels using the dispersion-theory results from the Adams et al. positivity program.
- Extracted the coefficient of `s^2` per channel and mapped them to linear inequalities on `c1` and `c2`.
- Provided CLI parsing for optional `--c1=` and `--c2=` flags to stress test prospective EFT points.
- Validated the Standard Model electron loop coefficients against the inequalities and generated a counterexample point with `c2 < 0` to demonstrate failure modes.

## Usage
```bash
wolframscript -file problems/eft-positivity-photon-photon/positivity_analysis.wls
wolframscript -file problems/eft-positivity-photon-photon/positivity_analysis.wls --c1=1e-3 --c2=-1e-3
```
- Output is ASCII JSON containing the amplitude formulas, the `s^2` coefficients, and boolean evaluations of the positivity inequalities.
- JSON artifacts are committed under the same directory for reproducibility.

## Results
- Forward amplitudes: `++++` proportional to `(c1 + c2)`, `++--` to `c1`, and `+-+-` to `c2`.
- Positivity region: `c1 > 0`, `c2 > 0`, `c1 + c2 > 0`.
- Standard Model sample (electron loop) satisfies all inequalities with comfortable margins.
- Counterexample (`c1 = 1e-3`, `c2 = -1e-3`) breaks the `++++` and `+-+-` channels, illustrating why both coefficients must stay strictly positive.

## Files
- `positivity_analysis.wls` — CLI script emitting amplitude and positivity data.
- `positivity_summary.json` — Standard Model evaluation snapshot.
- `positivity_counterexample.json` — Demonstrates inequality violations for an adversarial choice.

## References
- https://arxiv.org/abs/hep-th/0602178
- https://arxiv.org/abs/2112.12168
