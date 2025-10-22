# Notes

Date: 2025-10-22
Host: macOS on Apple Silicon; wolframscript 1.13.0 via /Applications
Repo: wolfram-cli; RUNBOOK.md verified and followed

Objective

- Solve the two-part four-potential problem entirely in Wolfram Language, with
  all artifacts local to this directory and ASCII only. Generate a cross-
  sectional plot of a single equipotential for four speeds.

Plan

- Part (a): write a concise, rigorous argument in words, using the gradient as
  a spacetime covector, the known Lorentz behavior of fields, and gauge
  covariance to deduce the four-quantity structure of the potentials.
- Part (b): implement the retarded scalar potential for a uniformly moving
  charge using the standard Lienard Wiechert form. Evaluate at a fixed lab
  time slice and extract the contour where the potential equals one. Overlay
  contours for speeds equal to 0.3, 0.5, 0.7, and 0.9 times the speed of
  light. Validate intercepts and expected contraction.

Environment hygiene

- PATH: use the Wolfram binary path from the runbook; do not rely on global
  shell settings.
- Headless: use Export for the plot and WriteString for the text report.

Commands executed

- /Applications/Wolfram.app/Contents/MacOS/wolframscript \
  -file problems/four-potential/solve.wls

Checks

- The contour for zero speed is a unit circle by construction.
- As speed increases, the cross-sectional curves flatten along the motion
  direction and expand transversely, consistent with the oblate ellipsoid
  description. Numerically extracted axis intercepts match the expected trend
  within solver tolerances.

References

https://www.feynmanlectures.caltech.edu/II_26.html
https://en.wikipedia.org/wiki/Li%C3%A9nard%E2%80%93Wiechert_potential

