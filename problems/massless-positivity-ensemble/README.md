# Massless Positivity Ensemble Sweep

## Objective
- Extend the IR-subtracted positivity programme (approach playbook item B) by
  quantifying how fat-tailed heavy spectra and pole regularisations reshape the
  twice-subtracted bound on the renormalised s^2 Wilson coefficient.
- Replace the earlier single-spectrum study with an ensemble analysis that
  samples heavy-state parameters from Pareto-controlled distributions so the
  statistics explicitly capture rare, high-leverage tails.

## Distinction from the 2025-10-25 Prototype
- The previous run fixed one heavy spectrum and contrasted cutoff versus
  analytic pole subtraction for that deterministic choice.
- This workflow generates 16 independent spectra per invocation, drawing
  thresholds, strengths, scales, and tail offsets from tempered Pareto laws and
  randomising the pole residue. The output is a JSON ledger containing per
  sample diagnostics plus aggregate order statistics (no means) for bounds and
  margins.

## Method Summary
- Parse CLI options with hardened validators; enforce two subtractions and
  positivity-friendly parameter ranges.
- Sample heavy spectra via ParetoDistribution draws (capped to retain numerical
  stability) while guaranteeing tail exponents exceed growth + 2, preserving
  convergence of the twice-subtracted integral.
- Evaluate the dispersion integral with NIntegrate at 60-digit working
  precision, disable symbolic preprocessing, and bound recursion depth to 10.
- Quantify the massless pole using the analytic 1/epsilon^3 scaling and tabulate
  both cutoff counterterms and the exact analytic subtraction for each sample.
- Report machine-readable records (heavy integrals, bounds, pole diagnostics)
  and ensemble-level order statistics, including violation indices when a user
  coefficient is supplied.

## Usage
- Baseline ensemble sweep without a test coefficient
  ```
  /Applications/Wolfram.app/Contents/MacOS/wolframscript \
    -file problems/massless-positivity-ensemble/ensemble_ir_subtraction.wls \
    > problems/massless-positivity-ensemble/ensemble_baseline.json
  ```
- Ensemble sweep assessing a candidate contact term (here cRen = 0.01)
  ```
  /Applications/Wolfram.app/Contents/MacOS/wolframscript \
    -file problems/massless-positivity-ensemble/ensemble_ir_subtraction.wls \
    --cRen=0.01 \
    > problems/massless-positivity-ensemble/ensemble_cren_0p01.json
  ```
- Key customisable knobs include `--samples`, `--seed`, the Pareto parameters
  (`--tailOffsetScale`, `--tailOffsetShape`, `--scaleParetoMin`, etc.), and the
  IR diagnostic grids `--irCuts` and `--irSamples`.

## Results
- Baseline ensemble (16 samples) produced strictly successful integrations with
  bounds spanning 2.85e-3 to 1.51e-2. Order statistics: q10 = 4.18e-3, q25 =
  5.46e-3, q50 = 7.19e-3, q75 = 8.61e-3, q90 = 1.45e-2. Pole residues covered
  8.11e-2 to 2.89e-1, demonstrating explicit tail realisations.
- With cRen = 0.01, the margin distribution straddles zero: min = -5.10e-3,
  q10 = -4.55e-3, q25 = 1.14e-3, median = 2.75e-3, q90 = 5.82e-3, max =
  7.15e-3. Three of sixteen samples (indices 2, 4, 10) violate the bound,
  yielding a violation fraction of 0.1875 and explicitly locating the risky
  spectra.
- Counterterm tables confirm cubic regulator divergence for every pole sample,
  while the analytic entry removes the pole exactly, keeping the reported bounds
  finite despite fat-tail extremes.

## Resilience Diagnostics
- No integrator failures observed; the script records any future failure with
  per-sample parameter payloads for post-mortem triage.
- Pareto caps prevent numerical blow-up yet preserve heavy tails; all tail
  exponents stay at least 0.5 above growth + 2, maintaining convergence margin.
- Aggregated outputs expose the entire bound and margin distributions (sorted
  lists plus quantiles), avoiding reliance on averages and highlighting tail
  risk directly.

## Next Steps
- Integrate the ensemble driver into `physics_cli.wls` for scripted sweeps and
  CI hooks so regression jobs can watch violation fractions over time.
- Extend the ensemble to mixed subtraction families (analytic, cutoff,
  principal value) and report cross-scheme spread as an explicit systematic.

## References
https://reference.wolfram.com/language/ref/NIntegrate.html
https://reference.wolfram.com/language/ref/WorkingPrecision.html
https://reference.wolfram.com/language/ref/ParetoDistribution.html.en
