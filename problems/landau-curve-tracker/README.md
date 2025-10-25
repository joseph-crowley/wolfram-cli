# Landau Curve Tracker

## Objective
- Extend approach playbook priority problem C by tracing the full Landau singularity curve for one-loop box topologies instead of sampling isolated determinant zeros.
- Generate machine-readable point clouds along the leading surface so downstream analysis can reason about gradient strength, slope evolution, and fat-tailed parameter excursions.

## Relation to Prior Attempts
- `problems/landau-singularity-mapper` harvested determinant sign changes on fixed grids without resolving tangent structure.
- `problems/landau-classifier-leading` classified individual roots by examining null vectors but still treated each point independently.
- This tracker stitches consecutive roots together using guarded predictor-corrector updates, delivering continuous arcs with diagnostics (residuals, gradient norms, slopes) that expose where the Landau surface sharpens or flattens.

## Method Summary
- Parse CLI arguments with hardened validators; enforce ASCII JSON inputs for masses, squares, step counts, and tolerances.
- Rationalise mass and invariant inputs to stabilise the Cayley determinant, then evaluate at arbitrary precision.
- March along the selected parameter (either `s` or `t`) using a secant-based `FindRoot` predictor-corrector: the previous slope seeds the second initial value while adaptive guards prevent degenerate brackets.
- Monitor residuals, gradient norms, slopes, and derivative magnitudes at every accepted point, aborting if the denominator of the implicit-function slope falls below the requested tolerance.
- Emit a single JSON document containing the forward arc, the backward arc, initial diagnostics, and aggregate summaries (max residual, domain reach).

## Usage
```
/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/landau-curve-tracker/landau_curve_tracker.wls \
  --internalMasses='[0.5,0.5,0.5,0.5]' \
  --externalSquares='[0.0,0.0,0.0,0.0]' \
  --initialPoint='[2.0,2.0]' \
  --parameter=s \
  --range='[0.2,4.0]' \
  --samplesForward=20 \
  --samplesBackward=15 \
  --maxStep=0.1 \
  --workingPrecision=60 \
  --reportGradients=false \
  > problems/landau-curve-tracker/box_equal_mass_curve.json

/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/landau-curve-tracker/landau_curve_tracker.wls \
  --internalMasses='[0.5,0.5,0.5,0.5]' \
  --externalSquares='[0.0,0.0,0.0,0.0]' \
  --initialPoint='[2.0,2.0]' \
  --parameter=t \
  --range='[0.2,4.0]' \
  --samplesForward=15 \
  --samplesBackward=15 \
  --maxStep=0.1 \
  --workingPrecision=60 \
  --reportGradients=false \
  > problems/landau-curve-tracker/box_equal_mass_curve_tparam.json
```
- `--parameter=s` treats s as the marching coordinate and solves for t(s); `--parameter=t` instead inverts the relationship.
- `--maxStep` bounds the parameter increment between successive solves; the tracker raises the step count if needed to respect this cap.
- `--derivativeTolerance` halts stepping when the implicit derivative denominator becomes too small, signalling an approach to a pinch or flat edge.

## Output Structure
- `status`: `ok` on success or `error` with a message.
- `initial`: residual, gradient components, gradient norm, and slope at the seed point.
- `forward` / `backward`: each block lists status, parameter domain reached, termination flag (`range`, `derivative`, or `solver`), maximum residual, and the ordered list of sampled points.
- Every point carries the marching parameter value, the corresponding `(s,t)` pair, residual, `gradientNorm`, and `slope`; gradients are optionally included when `--reportGradients=true`.
- A final `points` array concatenates backward, initial, and forward data for convenience, enabling direct plotting in downstream tooling.

## Results
- Equal-mass scalar box (`m_i = 0.5`, massless external squares) starting at `(s,t)=(2,2)`:
  - 20 forward steps cover `s` from 2.0 to 4.0 with residuals below `3e-15`.
  - Slopes evolve smoothly from `-0.83` near threshold to `-0.14` at `s=3.9`, while gradient norms climb from `5.7` to `13.8`, highlighting the sharpening of the Cayley surface.
  - 15 backward steps reach `s=0.2` before the derivative guard triggers, documenting the flattening region near the branch point.
- Parameter inversion (`--parameter=t`) reproduces the same surface expressed as `s(t)`, validating consistency of the implicit solver.

## Resilience Notes
- Predictor-corrector seeding maintains well-separated secant guesses; guards adjust the second seed when the secant degenerates.
- Rational inputs prevent spurious machine precision loss; `Quiet` filters benign precision warnings while still surfacing true failures.
- The tracker stops rather than extrapolating when the slope denominator drops below tolerance, ensuring fat-tailed scans flag hazardous regions explicitly.

## Next Steps
- Expose a `--savePoints` flag that exports only the concatenated point cloud for large-scale plotting without metadata overhead.
- Add triangle support by wrapping the single-parameter root-finding in the same scaffold, enabling comparative diagnostics across topologies.

## References
https://reference.wolfram.com/language/ref/FindRoot.html
https://reference.wolfram.com/language/ref/Det.html
https://reference.wolfram.com/language/ref/Rationalize.html
