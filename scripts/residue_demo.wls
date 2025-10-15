#!/usr/bin/env wolframscript
(* residue_demo.wls: compute the residue of a hard-coded meromorphic function at z0. *)

ClearAll[f];
f[z_] := (z^2 + 1)/(z - I)^3;
z0 = I;
res = Quiet @ Residue[f[z], {z, z0}];
Print["Residue at z0=", z0 // InputForm, ": ", res // InputForm];
