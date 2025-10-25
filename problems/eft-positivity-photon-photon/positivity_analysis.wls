#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Photon-photon EFT positivity for Euler-Heisenberg interactions.
  Outputs forward-limit helicity amplitudes, s^2 coefficients, and the
  resulting positivity inequalities. Accepts optional --c1= and --c2=
  flags to test specific Wilson coefficients; always reports the Standard
  Model electron loop sample for reference.
*)

SetDirectory[DirectoryName[$InputFileName]];

$Assumptions = {
  Element[s, Reals], s > 0,
  Element[c1, Reals],
  Element[c2, Reals]
};

ClearAll[parseArgs];
parseArgs[] := Module[
  {raw = Rest[$ScriptCommandLine], result = <||>, key, value, numeric},
  Do[
    If[StringMatchQ[item, "--" ~~ __ ~~ "=" ~~ __],
      {key, value} = StringSplit[StringDrop[item, 2], "=", 2];
      value = StringReplace[StringTrim[value], RegularExpression["[eE]"] :> "*^"];
      Quiet@Check[
        numeric = ToExpression[value];
        If[NumericQ[numeric], result[key] = N[numeric]],
        Null
      ]
    ],
    {item, raw}
  ];
  result
];

ClearAll[amplitudeForms, coefficientForms, inequalityForms];
amplitudeForms = <|
  "++++" -> 16 (c1 + c2) s^2,
  "++--" -> 8 c1 s^2,
  "+-+-" -> 8 c2 s^2
|>;
coefficientForms = Association[
  KeyValueMap[#1 -> Coefficient[#2, s, 2] &, amplitudeForms]
];
inequalityForms = <|
  "++++" -> Simplify[c1 + c2 > 0],
  "++--" -> Simplify[c1 > 0],
  "+-+-" -> Simplify[c2 > 0]
|>;

ClearAll[stringifyAssociation];
stringifyAssociation[assoc_Association] := Association[
  KeyValueMap[#1 -> ToString[#2, InputForm] &, assoc]
];

ClearAll[evaluateInequalities];
evaluateInequalities[assoc_Association, values_Association] := Association[
  KeyValueMap[
    #1 -> Quiet@Check[Simplify[assoc[#1] /. values], Missing["EvaluationFailure"]] &,
    assoc
  ]
];

ClearAll[standardModelCoefficients];
standardModelCoefficients[] := Module[
  {alpha, electronMassEV, base},
  alpha = 1/137.035999206;
  electronMassEV = 0.510998950*^6; (* eV *)
  base = alpha^2/(90 electronMassEV^4);
  <|
    "c1" -> base,
    "c2" -> (7/4) base
  |>
];

ClearAll[evaluationReport];
evaluationReport[name_, coeffs_Association, inequalities_Association] := Module[
  {values, evaluated},
  values = <|
    c1 -> coeffs["c1"],
    c2 -> coeffs["c2"]
  |>;
  evaluated = evaluateInequalities[inequalities, values];
  <|
    "label" -> name,
    "coefficients" -> coeffs,
    "inequalities" -> evaluated
  |>
];

ClearAll[main];
main[] := Module[
  {args, userCoeffs, smCoeffs, reports, payload},
  args = parseArgs[];
  userCoeffs = Association[];
  If[
    KeyExistsQ[args, "c1"] && args["c1"] =!= Missing["Invalid"],
    userCoeffs["c1"] = args["c1"]
  ];
  If[
    KeyExistsQ[args, "c2"] && args["c2"] =!= Missing["Invalid"],
    userCoeffs["c2"] = args["c2"]
  ];
  smCoeffs = standardModelCoefficients[];
  reports = {
    evaluationReport["StandardModel", smCoeffs, inequalityForms]
  };
  If[KeyExistsQ[userCoeffs, "c1"] && KeyExistsQ[userCoeffs, "c2"],
    AppendTo[
      reports,
      evaluationReport["UserInput", userCoeffs, inequalityForms]
    ]
  ];
  payload = <|
    "forwardAmplitudes" -> stringifyAssociation[amplitudeForms],
    "sSquaredCoefficients" -> stringifyAssociation[coefficientForms],
    "positivityInequalities" -> stringifyAssociation[inequalityForms],
    "evaluations" -> reports,
    "inputArguments" -> args
  |>;
  Print[ExportString[payload, "JSON", "Compact" -> True]];
];

main[];
