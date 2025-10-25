#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Multi-scheme IR-subtracted positivity analysis for forward 2 -> 2
  amplitudes with a massless t-channel exchange. The script evaluates the
  twice-subtracted dispersion integral for a fat-tailed heavy spectrum and
  compares renormalised bounds across analytic subtraction, cutoff
  regularisation, and partial-wave exclusion windows. Outputs ASCII JSON
  capturing scheme diagnostics, spreads, and worst-case requirements on the
  renormalised s^2 Wilson coefficient.
*)

SetDirectory[DirectoryName[$InputFileName]];
(* Load IR package via relative path to repo root. *)
Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "IR.wl"}]];
Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "MultiScheme.wl"}]];

$Assumptions = {
  Element[s, Reals], s >= 0
};

ClearAll[parseArgs, parseValue, toNumber];
parseArgs[] := Module[
  {raw = Rest[$ScriptCommandLine], result = <||>, key, value},
  Do[
    If[StringStartsQ[item, "--"] && StringContainsQ[item, "="],
      {key, value} = StringSplit[StringDrop[item, 2], "=", 2];
      result[key] = parseValue[value];
    ],
    {item, raw}
  ];
  result
];

parseValue[str_String] := Module[{trim = StringTrim[str]},
  Which[
    StringStartsQ[trim, "["] && StringEndsQ[trim, "]"],
      Quiet@Check[ImportString[trim, "JSON"], Missing["Invalid"]],
    StringMatchQ[trim, NumberString ~~ ___],
      toNumber[trim],
    trim === "Infinity", Infinity,
    trim === "-Infinity", -Infinity,
    True,
      trim
  ]
];
parseValue[other_] := other;

toNumber[str_String] := Module[{normalized, expr},
  normalized = StringReplace[str, RegularExpression["[eE]"] :> "*^"];
  Quiet@Check[
    expr = ToExpression[normalized];
    If[NumericQ[expr], N[expr], Missing["Invalid"]],
    Missing["Invalid"]
  ]
];
toNumber[val_] /; NumericQ[val] := N[val];
toNumber[_] := Missing["Invalid"];

ClearAll[main];
main[] := Module[
  {args, defaults, opts, schemeSpecs, payload},
  args = parseArgs[];
  defaults = PhysicsCLI`MultiScheme`MultiSchemeDefaultOptions[];
  opts = PhysicsCLI`MultiScheme`MultiSchemeMergeOptions[
    defaults,
    KeyDrop[args, {"schemes"}]
  ];
  schemeSpecs = Lookup[args, "schemes", Automatic];
  payload = PhysicsCLI`MultiScheme`MultiSchemeEvaluatePayload[opts, schemeSpecs];
  Print[ExportString[
    PhysicsCLI`MultiScheme`MultiSchemeSanitizeJSON[payload],
    "JSON",
    "Compact" -> True
  ]];
];

main[];
