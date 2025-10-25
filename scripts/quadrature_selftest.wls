#!/usr/bin/env wolframscript
(*
  Certified quadrature self-test.
  Runs three integrals with known analytic values using QuadratureCertificate.
  Emits ASCII JSON with per-case results and an allWithin flag.
*)

SetDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{"..", "lib", "PhysicsCLI", "Analysis.wl"}]];

ClearAll[truth, runCase];

truth["gaussian"] := Sqrt[Pi];
truth["cauchy_finite"] := 2 ArcTan[5];
truth["gamma3"] := 2.;

runCase[label_, integrand_, var_, lower_, upper_, opts_] := Module[
  {config, cert, tval, within},
  config = <|
    "Integrand" -> integrand,
    "Variable" -> var,
    "Lower" -> lower,
    "Upper" -> upper,
    "precision" -> Lookup[opts, "precision", 60],
    "accuracyGoal" -> Lookup[opts, "accuracyGoal", 12],
    "precisionGoal" -> Lookup[opts, "precisionGoal", 12],
    "maxRecursion" -> Lookup[opts, "maxRecursion", 12],
    "timeCapSec" -> Lookup[opts, "timeCapSec", 20]
  |>;
  cert = PhysicsCLI`Analysis`QuadratureCertificate[config];
  tval = N[truth[label], 30];
  within = If[Lookup[cert, "status", "error"] === "ok",
    cert["lower"] <= tval <= cert["upper"],
    False
  ];
  If[Lookup[cert, "status", "error"] === "ok",
    <|
      "label" -> label,
      "status" -> "ok",
      "seconds" -> cert["seconds"],
      "value" -> cert["value"],
      "lower" -> cert["lower"],
      "upper" -> cert["upper"],
      "within" -> within
    |>,
    <|
      "label" -> label,
      "status" -> "aborted",
      "seconds" -> Lookup[cert, "seconds", Null],
      "value" -> Null,
      "lower" -> Null,
      "upper" -> Null,
      "within" -> False
    |>
  ]
];

opts = <|"precision" -> 60, "accuracyGoal" -> 12, "precisionGoal" -> 12,
    "maxRecursion" -> 12, "timeCapSec" -> 20|>;

cases = {
  runCase["gaussian", Exp[-x^2], x, -Infinity, Infinity, opts],
  runCase["cauchy_finite", 1./(1. + x^2), x, -5, 5, opts],
  runCase["gamma3", x^2 Exp[-x], x, 0, Infinity, opts]
};

allWithin = And @@ (Lookup[#, "within", False] & /@ cases);

Print[ExportString[
  <|"status" -> "ok", "allWithin" -> allWithin, "cases" -> cases|>,
  "JSON", "Compact" -> True
]];
