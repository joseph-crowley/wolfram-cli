# Transverse-Field Zeroes

This directory contains a complete Wolfram Language solution following the
repo runbook. It verifies the scalar seed, constructs E and B fields that
satisfy Maxwell equations in free space, analyzes the g >> 1 limit, and
produces a sketch of the loci of electric and magnetic transverse zeroes.

How to run

- Ensure `wolframscript` is on PATH. The runbook uses
  `/Applications/Wolfram.app/Contents/MacOS` on macOS.

- Execute the solver:

  wolframscript -file problems/transverse-field-zeroes/solve.wls

Outputs

- `report.txt` summarizing symbolic checks and derived conditions.
- `sketch.png` showing the electric zero line and the elliptic helix of
  transverse magnetic zeroes around its axis.

All files in this directory are ASCII-safe.
