# IR-Subtracted Positivity with Massless Exchanges

## Objective
- Enforce twice-subtracted forward-limit positivity bounds when the 2 to 2
  amplitude contains a massless t-channel pole.
- Isolate the heavy-state contribution to the dispersion integral so the
  renormalised s squared Wilson coefficient remains finite and positive.
- Demonstrate regulator uniformity by comparing cutoff counterterms against
  analytic pole subtraction while preserving fat-tailed spectral support.

## Relation to Prior Work
- The photon-photon positivity task already captured the purely massive case.
  No repository attempt previously tackled the massless exchange extension.
- This implementation follows the approach playbook priority item B by
  promoting the subtraction scheme to a first-class diagnostic and exposing
  heavy-tail modelling knobs on the CLI.

## Method Summary
- Model the absorptive heavy spectrum as a thresholded power law multiplied by
  a tempering tail so that the dispersion integrand has algebraic decay yet
  remains integrable.
- Treat the massless pole as a separate spectral density proportional to the
  inverse centre-of-mass energy and tabulate its divergent contribution to the
  dispersion weight.
- Evaluate the twice-subtracted dispersion integral with high precision
  quadrature, using an adaptive global strategy and explicit recursion limits
  to maintain stability in the fat-tailed regime.
- Emit JSON summarising the heavy integral, the positivity bound on the
  renormalised coefficient, divergence diagnostics for the pole, and the
  counterterms for a sequence of infrared cutoffs together with the analytic
  subtraction.

## Code
- `ir_subtracted_positivity.wls` implements CLI parsing, heavy spectrum
  integration, divergence estimation, and reporting. All arithmetic is carried
  out with 60-digit working precision and deterministic tolerance settings.

## Usage
- Baseline evaluation with the default heavy spectrum and renormalised contact
  coefficient
  ```
  /Applications/Wolfram.app/Contents/MacOS/wolframscript \
    -file problems/positivity-with-light-states/ir_subtracted_positivity.wls \
    --cRen=0.01 \
    > problems/positivity-with-light-states/summary_default.json
  ```
- Tail-strengthened ensemble probing sensitivity to slower power-law decay
  ```
  /Applications/Wolfram.app/Contents/MacOS/wolframscript \
    -file problems/positivity-with-light-states/ir_subtracted_positivity.wls \
    --cRen=0.004 \
    --heavyStrength=2.5 \
    --heavyScale=4.0 \
    --heavyThreshold=1.2 \
    --growthPower=2.8 \
    --tailExponent=6.2 \
    --sCuts='[0.15,0.3,0.6]' \
    --irSamples='[0.15,0.07,0.03]' \
    > problems/positivity-with-light-states/summary_tail_heavy.json
  ```

## Results
- `summary_default.json` reports a heavy integral of 2.36e-2, yielding a
  renormalised positivity bound of 7.51e-3. A user-supplied coefficient of
  1.00e-2 safely exceeds the bound with a margin of 2.49e-3. The divergence
  samples confirm the cubic growth of the unsubtracted pole term as the
  infrared regulator shrinks, while the cutoff counterterms and analytic
  removal agree on the fully subtracted remainder.
- `summary_tail_heavy.json` increases the heavy tail strength, driving the
  bound up to 4.92e-2. The test coefficient of 4.00e-3 fails the bound, and
  the diagnostic table shows the regulator dependence of the pole counterterm
  while the analytic subtraction again removes the divergence exactly.

## Next Steps
- Extend the CLI into the shared physics driver so the IR subtraction choices
  appear beside the existing positivity tasks.
- Incorporate partial-wave exclusion bands and scheme averaging to quantify
  regulator uncertainty as an explicit error bar in future runs.

## References
https://arxiv.org
