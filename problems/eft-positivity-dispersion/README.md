# Dispersive Photon Positivity with Fat-Tailed Spectra

## Objective
- Extend the approach playbook priority A by translating the forward-limit photon positivity bounds into an explicit dispersive calculator that evaluates the f2 and g2 coefficients from partial-wave spectral densities.
- Stress test the bounds against Pareto-sampled ultraviolet spectra so extreme resonances and wide partial-wave hierarchies are handled without manual tuning.
- Produce machine-readable diagnostics that highlight which rare events dominate the Wilson coefficients, enabling downstream automation to remain resilient when fat-tailed physics is proposed.

## Distinction from the Earlier Attempt
- The previous `problems/eft-positivity-photon-photon` script codified analytic inequalities c1 greater than zero, c2 greater than zero, and c1 plus c2 greater than zero derived from the Euler-Heisenberg effective action.
- This project implements the sum-rule machinery of arXiv:2210.04675, Equation 3.11, in order to build f2 and g2 directly from partial-wave spectral data, keeping track of the Landau-Yang compatible even and odd towers.
- Instead of presuming clean analytic coefficients, the new workflow samples discrete spectral lines from Pareto distributions, enforces non-negative weights, and reports how much of g2 is carried by the heaviest contributors, making tail risk explicit.

## Methodology
- The Wolfram Language script `spectral_dispersion.wls` parses either user-supplied spectral data or generates deterministic Pareto ensembles with configurable seeds, shape exponents, and spin content.
- For each entry the script evaluates the brackets appearing in the dispersive positivity sum rules: the plus and minus combinations of the helicity-one partial waves and the even and odd sequences of the helicity-two projections. Discrete delta functions replace the continuum integrals, so each term contributes a weight divided by the sixth power of its mass.
- The aggregated brackets feed directly into f2 and g2. Wilson coefficients a1 and a2 are recovered via the relation a1 equals one sixteenth of g2 plus f2 and a2 equals one sixteenth of g2 minus f2. The script emits those numbers alongside the Standard Model Euler-Heisenberg benchmark for comparison.
- Tail diagnostics rank the per-entry contributions to g2, report quantiles, and expose the min and max shares flowing into a1 and a2. This transparency ensures rare, high-leverage resonances are visible and can be mitigated if necessary.

## Usage
```
/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/eft-positivity-dispersion/spectral_dispersion.wls \
  > problems/eft-positivity-dispersion/baseline.json

/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/eft-positivity-dispersion/spectral_dispersion.wls \
  --seed=20251026 \
  --samples=32 \
  --tailExponent=2.2 \
  --candidateCoefficients='{"a1":50.0,"a2":45.0}' \
  > problems/eft-positivity-dispersion/stress_tail.json
```
- `--spectralData=` accepts a JSON array of discrete resonances with fields `spin`, `mass`, `rho1`, `rho2`, and `rho3`. Missing weights default to zero, and validation rejects negative inputs.
- `--spins=` accepts a JSON array selecting which partial waves to sample in the automatic generator. The default mixes even and odd entries so both helicity sectors are probed.
- `--candidateCoefficients=` lets downstream workflows test proposed Wilson coefficients against the positivity requirements. The response reports whether each condition passes and the fraction of the newly computed a1 and a2 they represent.

## Results
- The baseline run (seed 20251025, eighteen samples) produces f2 approximately 9.19e1 and g2 approximately 9.81e2, yielding a1 equal to 6.71e1 and a2 equal to 5.56e1. The diagnostic ledger shows that four partial waves already account for more than eighty per cent of g2, emphasising the need to monitor outliers.
- The stress run (seed 20251026, thirty-two samples, shallower tail exponent 2.2) strengthens the tail. f2 rises to approximately 2.22e2 and g2 climbs above 2.16e3, so a1 and a2 become 1.49e2 and 1.21e2 respectively. The supplied candidate coefficients of fifty and forty-five remain positive but sit at roughly one third of the computed a1 and a2, signalling insufficient safety margin if those coefficients were adopted.
- Standard Model benchmarks remain vastly larger because the electron mass is tiny, yet the positivity check still flags them as obeying the inequalities, demonstrating that the dispersive calculator aligns with known physics.

## Files
- `spectral_dispersion.wls` — CLI implementation of the dispersive positivity calculator.
- `baseline.json` — baseline Pareto ensemble output with diagnostics.
- `stress_tail.json` — stress run with heavier tails and candidate evaluation.

## References
https://arxiv.org/abs/2210.04675
https://en.wikipedia.org/wiki/Euler%E2%80%93Heisenberg_Lagrangian
