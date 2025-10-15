#!/usr/bin/env wolframscript
(* asymptotic_integral.wls: demonstrate AsymptoticIntegrate for a Gaussian-modulated oscillatory integral. *)

$Assumptions = λ > 0 && a > 0;
expr = Cos[λ x^2] Exp[-a x^2];
series = AsymptoticIntegrate[expr, {x, -Infinity, Infinity}, λ -> Infinity, SeriesTermGoal -> 2];
Print[series // InputForm];
