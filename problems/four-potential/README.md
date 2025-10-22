# The Four-Potential: Covariance and Equipotentials

This directory contains a complete Wolfram Language solution for the two-part
problem about electromagnetic four-potentials and equipotentials of a moving
point charge. It follows the repository runbook: ASCII-only artifacts, WL-only
code, headless execution via wolframscript, and all files confined to this
directory.

Scope

- Part (a): From the four-vector character of the spacetime gradient and the
  Lorentz transformation laws of the electric and magnetic fields, deduce that
  the scalar potential together with the spatial vector potential assemble into
  a single covariant four-quantity. The time-like component is the scalar
  potential divided by the speed of light, and the spatial components are the
  usual magnetic vector potential. Gauge freedom is real but does not obstruct
  the conclusion: within a covariant gauge, the potentials transform linearly
  under Lorentz transformations so that their spacetime derivatives reproduce
  the known transformation behavior of the fields.

- Part (b): Show that the spherical equipotentials of a stationary point charge
  distort to oblate ellipsoids when the charge moves uniformly along a straight
  line. Provide a cross-sectional plot of a single equipotential for speeds
  equal to 0.3 times the speed of light, 0.5 times, 0.7 times, and 0.9 times,
  all overlaid in a single figure.

Conventions

- Units: pick constants so that the product of charge and the usual Coulomb
  prefactor equals one. The speed of light equals one inside the solver. These
  choices only set a length scale for the contour and do not affect the shape.
- Frame: the field is evaluated at a single laboratory time when the charge is
  at the origin and moving along the positive x axis at a constant speed.
- Gauge: the narrative explains the covariant gauge logic in words only. The
  numeric plot uses the standard retarded Lienard Wiechert potentials, which do
  not require symbolic gauge manipulation for this task.

How to run

- Ensure wolframscript is available. On macOS the runbook uses the binary in
  /Applications/Wolfram.app/Contents/MacOS.

- Execute the solver from the repository root:

  /Applications/Wolfram.app/Contents/MacOS/wolframscript \
    -file problems/four-potential/solve.wls

Outputs

- report.txt: plain text summary of part (a) reasoning and part (b) numeric
  validation, including measured intercepts and the predicted axis ratios.
- equipotential_cross_section.png: overlaid cross-sectional contour for the
  four speeds. Colors distinguish the speeds and a legend is included.

Notes on method

- Part (a) is presented in words without equations, aligning with the request
  and preserving strict ASCII output. The logic relies on two ingredients: the
  gradient as a spacetime covector and the empirically established Lorentz
  transformation of the electromagnetic field. Demanding that spacetime
  derivatives of a candidate potential reproduce the known field transformation
  forces the potential to transform as a single four-quantity, modulo the
  addition of a spacetime gradient of a scalar gauge field. Fixing a covariant
  gauge removes that ambiguity.

- Part (b) is produced by evaluating the retarded scalar potential of a
  uniformly moving charge in the laboratory frame at a fixed time slice.
  Level sets of that scalar potential are sampled numerically and the target
  contour value is chosen so that the static case produces a unit circle. The
  moving cases overlay as oblate ellipses with the short axis along the motion
  and the long axis transverse to it. The code also measures axis intercepts to
  confirm the predicted contraction along the direction of motion.

Reproducibility

- The script is headless, writes ASCII text, and exports a single PNG figure.
  No notebooks are required. All files are confined to this directory.

References

https://www.feynmanlectures.caltech.edu/II_26.html
https://en.wikipedia.org/wiki/Li%C3%A9nard%E2%80%93Wiechert_potential

