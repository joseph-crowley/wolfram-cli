# Landau Singularity Classifier

## Objective
- Upgrade the priority problem C (Landau singularity mapper) by extracting the Landau parameter null vectors at each detected singular point and classifying the solution as fully leading, edge-degenerate, or sign-indefinite.
- Provide deterministic diagnostics that survive fat-tailed scans where the Cayley determinant becomes ill-conditioned, ensuring the CLI detects unstable regions instead of silently accepting them.
- Deliver ASCII-safe JSON that augments the existing determinant grids with gradient magnitudes and alpha-vector summaries so downstream tooling can prioritise genuinely dangerous kinematic loci.

## Relation to Prior Attempt
- The earlier `problems/landau-singularity-mapper` project stopped after bracketing determinant zeros on fixed grids. It did not inspect the null space of the Cayley matrix nor distinguish leading Landau regions from spurious sign-flips.
- This classifier builds on that output by solving the SVD null vector problem at each root, orienting the vector, normalising it on both the L1 simplex and unit-sum scales, and reporting when the smallest singular value exceeds a tunable tolerance.
- Gradient evaluation at every classified point quantifies how sharply the determinant crosses zero, flagging near-degenerate plateaus that the mapper could miss.

## Implementation
- `landau_classifier.wls` loads the shared `PhysicsCLI` utilities, reuses the argument specification, and routes inputs through `PhysicsCLI`Analysis`LandauMapper` before applying classification.
- Null-space extraction uses `SingularValueDecomposition` at configurable working precision; the smallest singular value is compared against `--nullTolerance` to reject numerically dubious solutions.
- Alpha-vector orientation flips the null vector so its first significant component is positive and classifies outcomes via an `--alphaTolerance` soft threshold (`leading-positive`, `edge-degenerate`, or `sign-indefinite`).
- Triangle mode consumes the mapper's `roots` (plus optional `--scanValue`), computes first derivatives of the determinant, and emits per-root residuals, slopes, singular values, and simplex-normalised alphas.
- Box mode merges `curvePoints` and explicit `(s,t)` evaluations, returning gradient pairs `(∂det/∂s, ∂det/∂t)` alongside alpha diagnostics so users can trace entire singular curves.

## Usage
```
/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/landau-classifier-leading/landau_classifier.wls \
  --topology=triangle \
  --internalMasses='[0.7,0.8,0.9]' \
  --externalSquares='[1.0,1.0,4.0]' \
  --scanIndex=3 \
  --scanRange='[0.1,6.0,200]' \
  --workingPrecision=100 \
  --nullTolerance=1e-10 \
  --alphaTolerance=1e-10 \
  > problems/landau-classifier-leading/triangle_classification.json

/Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/landau-classifier-leading/landau_classifier.wls \
  --topology=box \
  --internalMasses='[0.5,0.5,0.5,0.5]' \
  --externalSquares='[0,0,0,0]' \
  --sRange='[0.1,5.0,80]' \
  --tRange='[0.1,5.0,80]' \
  --workingPrecision=120 \
  --nullTolerance=5e-11 \
  --alphaTolerance=5e-11 \
  > problems/landau-classifier-leading/box_classification.json
```
- Both commands inherit the shared parsing rules, so JSON arrays are mandatory for vector inputs, and the outputs remain ASCII and machine-readable.
- The classifier prints a single JSON document summarising inputs, diagnostics, and the list of singularities. Redirect to a file to keep audit trails alongside the original mapper artefacts.
- When scanning massless equal-mass boxes the determinant develops an extended zero locus anchored at `s=0`, so explicit `--s`/`--t` evaluations (as in the second command) remain the reliable way to classify the physically relevant pinch point; the README will be updated once the candidate harvester learns to trim those flat directions automatically.

## Diagnostics Emitted
- `singularValue` — minimum singular value of the Cayley matrix; high values indicate the determinant zero is numerically spurious.
- `classification` — `leading-positive`, `edge-degenerate`, `sign-indefinite`, or `zero-vector` (the latter appears only if the null vector vanishes numerically).
- `alphaRaw`, `alphaL1`, `alphaSum1` — raw oriented null vector, L1-normalised simplex vector, and sum-normalised vector (if the sum is stable) for traceability.
- `derivative` (triangle) and `gradient` (box) — slopes at the root to distinguish simple crossings from flat degeneracies.
- `residual` — absolute determinant value at the reported point, allowing quick identification of insufficient precision or tolerance settings.

## Next Steps
- Integrate the classifier into `physics_cli.wls` so `--task=landau-mapper` can optionally emit the null-vector diagnostics without separate invocation.
- Add adaptive refinement that bisects brackets until both the residual and smallest singular value fall below user-specified targets, automating convergence control for fat-tailed scan ranges.
- Extend the workflow to pentagon topologies by promoting the Cayley assembly to five propagators and reusing the same SVD-based classifier.

## References
- https://arxiv.org/abs/2203.08211
- https://arxiv.org/abs/2210.04675
