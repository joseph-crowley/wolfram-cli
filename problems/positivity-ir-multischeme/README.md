# Multi-Scheme IR Positivity Comparator

## Objective
- Advance approach playbook priority B by quantifying how different infrared
  subtraction choices impact the twice-subtracted positivity bound when a
  massless t-channel pole is present.
- Treat analytic removal, hard cutoffs, and partial-wave exclusion windows on
  equal footing so the worst-case bound and regulator spread are explicit.
- Preserve fat-tailed heavy spectra while delivering ASCII-safe JSON suitable
  for automation and regression baselining.

## Relation to Prior Attempts
- `problems/positivity-with-light-states` analysed a single spectrum with
  analytic subtraction and reported cutoff counterterms but did not compute the
  resulting bounds per scheme.
- `problems/massless-positivity-ensemble` sampled many spectra yet still used a
  single subtraction pathway, leaving cross-scheme variability implicit.
- This directory introduces simultaneous evaluation of multiple schemes and
  records residuals, lost spectral weight, and counterterm magnitudes so
  regulator-dependent risk is visible and the tightest bound can be enforced.

## Method Summary
- The Wolfram script `multi_scheme_ir_bounds.wls` parses CLI options (fat-tail
  parameters, scheme definitions, precision controls) with hardened validators.
- The heavy spectrum is modelled as a thresholded power law with tempering,
  ensuring integrability even when tails concentrate probability mass.
- `NIntegrate` with 60-digit working precision evaluates the twice-subtracted
  integrals over scheme-specific intervals (full spectrum, hard exclusions, or
  band gaps). The prefactor `2/π` implements the dispersion kernel.
- Each scheme reports the renormalised bound, counterterm size, residual shift
  from the analytic baseline, and the fraction of heavy spectral weight that
  was removed by the exclusion window.
- Aggregation logic computes the minimum and maximum bounds, spread,
  consistency check against the analytic baseline, and the largest counterterm
  or spectral loss.

## Usage
```
/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/positivity-ir-multischeme/multi_scheme_ir_bounds.wls \
  > problems/positivity-ir-multischeme/multi_scheme_default.json

/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/positivity-ir-multischeme/multi_scheme_ir_bounds.wls \
  --heavyStrength=2.5 \
  --heavyScale=4.0 \
  --heavyThreshold=1.2 \
  --growthPower=2.8 \
  --tailExponent=6.2 \
  --schemes='[{"scheme":"analytic"},{"scheme":"cutoff","sCut":0.2},\
{"scheme":"cutoff","sCut":0.12},{"scheme":"excludeBelow","sMin":1.8},\
{"scheme":"bandGap","sMin":1.8,"sMax":2.6},\
{"scheme":"bandGap","sMin":2.2,"sMax":3.6}]' \
  --cRen=0.008 \
  > problems/positivity-ir-multischeme/multi_scheme_tailstress.json
```
- `--schemes=` expects a JSON array of scheme dictionaries. Supported types:
  `analytic`, `cutoff` (requires `sCut > 0`), `excludeBelow` (requires
  `sMin`), and `bandGap` (requires `sMin < sMax`).
- `--schemeTolerance` controls the numerical equality test that flags whether
  all schemes reproduce the analytic bound within tolerance.

## Results
- Baseline run (`multi_scheme_default.json`): the analytic and cutoff schemes
  agree on a bound of `7.51e-3`. Excluding everything above `s = 2.0` relaxes
  the bound to `7.17e-3`, removing `4.5%` of the heavy spectral weight.
  Carving out the band `[2.0, 2.8]` drops the bound to `5.24e-3` but removes
  `30%` of the spectrum, exposing how aggressive exclusions shrink the bound.
- Tail-stressed run (`multi_scheme_tailstress.json`): the analytic bound rises
  to `4.92e-2`. Excluding weight below `s = 1.8` lowers the bound by
  `3.42e-3`, while removing the band `[2.2, 3.6]` cuts the bound almost in
  half to `2.73e-2` after discarding `44.6%` of the spectrum. All candidate
  schemes flag that a test coefficient `cRen = 8.0e-3` violates positivity.
- Counterterms span `0` to `1.26e1` in the baseline and up to `2.46e1` in the
  stressed run, confirming that hard cutoffs introduce massive regulator
  corrections even though the renormalised bound should match the analytic
  baseline.

## Files
- `multi_scheme_ir_bounds.wls` — CLI implementation delivering multi-scheme
  dispersion bounds and diagnostics.
- `multi_scheme_default.json` — baseline comparison across default schemes.
- `multi_scheme_tailstress.json` — heavy-tail stress test with custom schemes
  and a failing candidate coefficient.

## Next Steps
- Integrate the comparator into `physics_cli.wls` so CI can enforce the
  worst-case bound alongside the existing positivity tasks.
- Extend the scheme catalogue with principal-value wedges and subtraction-band
  averaging, reporting systematic spreads as explicit error bars.
- Pair the scheme spread with Monte Carlo heavy spectra to obtain a full
  distribution over worst-case bounds under combined tail and regulator
  uncertainties.

## References
https://reference.wolfram.com/language/ref/NIntegrate.html
https://arxiv.org
