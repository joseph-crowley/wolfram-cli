#!/usr/bin/env wolframscript
(*
  Heavy spectrum admissibility validator self-test.
  Generates random spectra definitions and checks validator decisions.
*)

SetDirectory[DirectoryName[$InputFileName]];

ClearAll[validQ];
validQ[spec_Association] := Module[{th, gp, te, w},
  th = Lookup[spec, "threshold", -1];
  gp = Lookup[spec, "growthPower", -1];
  te = Lookup[spec, "tailExponent", -1];
  w = Lookup[spec, "weights", {}];
  And[
    NumericQ[th] && th > 0,
    NumericQ[gp] && gp >= 0,
    NumericQ[te] && te > gp + 2,
    ListQ[w] && AllTrue[w, NumericQ[#] && # >= 0 &]
  ]
];

randValid[] := Module[{gp = RandomReal[{0.0, 4.0}]},
  <|
    "threshold" -> RandomReal[{0.5, 2.0}],
    "growthPower" -> gp,
    "tailExponent" -> gp + RandomReal[{2.1, 4.5}],
    "weights" -> RandomReal[{0.0, 1.0}, 8]
  |>
];

randInvalid[] := RandomChoice[{
  <|"threshold" -> -0.5, "growthPower" -> 1.0, "tailExponent" -> 4.0, "weights" -> {0.1, 0.2}|>,
  <|"threshold" -> 1.0, "growthPower" -> -1.0, "tailExponent" -> 4.0, "weights" -> {0.1}|>,
  <|"threshold" -> 1.0, "growthPower" -> 2.0, "tailExponent" -> 3.0, "weights" -> {-0.1, 0.2}|>,
  <|"threshold" -> 1.0, "growthPower" -> 3.0, "tailExponent" -> 4.5, "weights" -> {0.1, -0.3}|>
}];

val = Table[randValid[], {20}];
inv = Table[randInvalid[], {10}];
vp = Count[val, _?(validQ)];
ip = Count[inv, s_ /; Not[validQ[s]]];

Print[ExportString[
  <|"status" -> "ok", "validPass" -> vp, "invalidPass" -> ip|>,
  "JSON", "Compact" -> True
]];
