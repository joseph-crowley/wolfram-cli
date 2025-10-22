# Notes

Date: 2025-10-22
Host: macOS on Apple Silicon, wolframscript 1.13.0
Repo: wolfram-cli (RUNBOOK.md verified)

Objective

- Solve the transverse-field zeroes problem entirely in Wolfram Language.
- Keep artifacts and documentation confined to this directory.

Summary of Method

- Defined the complex scalar psi with a traveling-wave factor and an affine
  polynomial in x and y prime. Verified it satisfies the source-free wave
  equation in free space under the dispersion relation c equals omega over k.
- Built E with transverse components proportional to psi and deduced the
  longitudinal component from Gauss law by integrating minus the transverse
  divergence with respect to z. Chose zero integration constant to obtain the
  minimal longitudinal field compatible with propagation.
- Constructed B from Faraday law for time-harmonic fields with temporal factor
  exp of minus i omega t, yielding B equals one over i omega times the curl of
  E. Verified Ampere law with the same dispersion relation.
- Analyzed the regime g much larger than 1 by dropping the k x squared sin
  delta contribution in psi. This preserves the coupling between y and z via
  y prime while simplifying the x dependence.

Results

- Wave equation holds exactly with the dispersion relation. The symbolic check
  returns True.
- The deduced longitudinal electric field is proportional to the traveling
  phase and contains a constant term in x plus a linear term in x. Magnetic
  field components satisfy Ampere law identically when c equals omega over k.
- Electric zero locus in the g much greater than 1 limit is characterized by
  x equals 0 and y prime equals 0. The latter implies the straight line
  y equals negative z tan delta in the plane x equals 0. This is the axis
  of symmetry, which we denote z prime.
- Magnetic transverse zeroes in the same limit are obtained using polar
  coordinates defined by g x equals r cos theta and y prime equals r sin
  theta. Enforcing the simultaneous vanishing of the real transverse magnetic
  components yields a fixed radius r equals sin delta over k and a phase angle
  theta that equals negative of k z minus omega t. The resulting locus is an
  elliptic helix of radius components r over g along x and r along y prime,
  rotating in time with angular frequency omega and advancing with wavevector
  k along the propagation direction. The helix winds around the electric zero
  axis z prime.

Artifacts

- report.txt summarizes the symbolic checks and the zero-locus conditions.
- sketch.png provides a visualization with two projections versus z, showing
  both the x and y prime components of the magnetic zero helix; the electric
  zero axis is the line x equals 0, y prime equals 0.

Commands Executed

- wolframscript -file problems/transverse-field-zeroes/solve.wls

Notes

- All intermediate manipulations use symbolic calculus with assumptions that
  k, omega, g, c are positive and variables are real. No numeric substitution
  is needed beyond the plotting phase, which uses a fixed time slice.
- The sketch intentionally uses y prime as an axis to make the orthogonal
  relationship between y prime and z prime explicit without rotating the full
  coordinate system.
