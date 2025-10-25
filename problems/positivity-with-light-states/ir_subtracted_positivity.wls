#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  IR-subtracted positivity analysis for forward 2 -> 2 amplitudes with
  massless t-channel exchanges. The script isolates the heavy-state
  contribution to the twice-subtracted dispersion relation and reports
  the associated positivity bound on the renormalised s^2 Wilson
  coefficient. It documents the divergence of the massless pole under
  unsubtracted integration and tabulates counterterms for representative
  subtraction schemes. Outputs machine-readable JSON for downstream use.
*)

SetDirectory[DirectoryName[$InputFileName]];

$Assumptions = {
  Element[s, Reals], s >= 0,
  Element[x, Reals], x >= 0
};

ClearAll[parseArgs, parseValue, toNumber, parseList];
parseArgs[] := Module[
  {raw = Rest[$ScriptCommandLine], result = <||>, key, value},
  Do[
    If[StringMatchQ[item, "--" ~~ __ ~~ "=" ~~ __],
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

parseList[val_List] := DeleteCases[N /@ val, _Missing];
parseList[_Missing] := {};
parseList[_] := {};

ClearAll[defaultOptions];
defaultOptions := <|
  "poleStrength" -> 0.2,
  "sCuts" -> {0.2, 0.4, 0.8},
  "irSamples" -> {0.2, 0.1, 0.05},
  "subtractions" -> 2,
  "cRen" -> Missing["NotProvided"],
  "heavyStrength" -> 1.,
  "heavyScale" -> 3.,
  "heavyThreshold" -> 1.5,
  "growthPower" -> 3.,
  "tailExponent" -> 6.5,
  "precision" -> 60,
  "accuracyGoal" -> 12,
  "precisionGoal" -> 12,
  "integrationMax" -> Infinity
|>;

ClearAll[mergeOptions, validateOptions];
mergeOptions[defaults_Association, overrides_Association] := Module[
  {result = defaults},
  KeyValueMap[
    If[#2 =!= Missing["Invalid"], result[#1] = #2] &,
    overrides
  ];
  result
];

validateOptions[opts_Association] := Module[
  {subtractions = Round[opts["subtractions"]]},
  If[subtractions =!= 2,
    Return[<|"valid" -> False, "message" -> "Only two subtractions supported."|>]
  ];
  If[opts["poleStrength"] < 0,
    Return[<|"valid" -> False, "message" -> "poleStrength must be nonnegative."|>]
  ];
  If[opts["heavyStrength"] < 0,
    Return[<|"valid" -> False, "message" -> "heavyStrength must be nonnegative."|>]
  ];
  If[opts["tailExponent"] <= opts["growthPower"] + 2,
    Return[<|"valid" -> False,
      "message" -> "tailExponent must exceed growthPower + 2 for convergence."|>]
  ];
  If[opts["integrationMax"] =!= Infinity && opts["integrationMax"] <= opts["heavyThreshold"],
    Return[<|"valid" -> False,
      "message" -> "integrationMax must exceed heavyThreshold."|>]
  ];
  <|"valid" -> True, "message" -> "OK"|>
];

ClearAll[heavySpectrum];
heavySpectrum[s_, opts_Association] := Module[
  {threshold = opts["heavyThreshold"], scl = opts["heavyScale"],
   strength = opts["heavyStrength"], growth = opts["growthPower"],
   tail = opts["tailExponent"], x},
  If[s <= threshold, 0.,
    x = s - threshold;
    strength * (x^growth) / (1. + x/scl)^tail
  ]
];

ClearAll[heavyIntegral];
heavyIntegral[opts_Association] := Module[
  {integrand, max, threshold = opts["heavyThreshold"], subtractions,
   prec = opts["precision"], acc = opts["accuracyGoal"],
   goal = opts["precisionGoal"]},
  subtractions = Round[opts["subtractions"]];
  integrand[s_] := heavySpectrum[s, opts]/s^(subtractions + 1);
  max = opts["integrationMax"];
  Quiet@Check[
    NIntegrate[
      integrand[s],
      {s, threshold, max},
      Method -> {"GlobalAdaptive", "SymbolicProcessing" -> 0},
      WorkingPrecision -> prec,
      AccuracyGoal -> acc,
      PrecisionGoal -> goal,
      MaxRecursion -> 12
    ],
    Missing["IntegrationFailure"]
  ]
];

ClearAll[prefactor, heavyContribution, contactBound];
prefactor[subtractions_Integer] := Module[{},
  If[subtractions =!= 2,
    Missing["Unsupported"],
    2./Pi
  ]
];

heavyContribution[val_, subtractions_Integer] := prefactor[subtractions]*val;

contactBound[val_, subtractions_Integer] := Module[{pf = prefactor[subtractions]},
  If[NumericQ[pf],
    (pf*val)/2.,
    Missing["Unsupported"]
  ]
];

ClearAll[masslessDivergenceSamples];
masslessDivergenceSamples[pole_, epsList_List, subtractions_Integer] := Module[
  {pf = prefactor[subtractions]},
  If[!NumericQ[pf],
    {},
    Table[
      <|
        "epsilon" -> eps,
        "estimate" -> If[eps > 0,
          pf*pole/(3.*eps^3),
          Infinity
        ]
      |>,
      {eps, epsList}
    ]
  ]
];

ClearAll[cutoffCounterterms];
cutoffCounterterms[pole_, cuts_List, subtractions_Integer] := Module[
  {pf = prefactor[subtractions]},
  If[!NumericQ[pf],
    {},
    Table[
      <|
        "scheme" -> "cutoff",
        "sCut" -> cut,
        "counterterm" -> If[cut > 0, pf*pole/(3.*cut^3), Infinity]
      |>,
      {cut, cuts}
    ]
  ]
];

ClearAll[analyticCountertermEntry];
analyticCountertermEntry[pole_, subtractions_Integer] := Module[
  {pf = prefactor[subtractions]},
  If[!NumericQ[pf],
    <||>,
    <|
      "scheme" -> "analytic",
      "description" -> "Exact t-channel removal",
      "counterterm" -> 0.,
      "note" -> "Massless pole subtracted at amplitude level."
    |>
  ]
];

ClearAll[userCheck];
userCheck[cRen_, bound_] := Module[{margin},
  If[!NumericQ[cRen],
    <|
      "provided" -> "NotProvided",
      "bound" -> bound,
      "satisfies" -> "NotEvaluated",
      "margin" -> "NotEvaluated"
    |>,
    margin = cRen - bound;
    <|
      "provided" -> cRen,
      "bound" -> bound,
      "satisfies" -> (margin >= 0),
      "margin" -> margin
    |>
  ]
];

ClearAll[formatValue];
formatValue[val_] := Which[
  val === Infinity, "Infinity",
  val === -Infinity, "-Infinity",
  True, val
];

ClearAll[main];
main[] := Module[
  {args, opts, validity, subtractions, hVal, hContribution, bound, samples,
   counterterms, analyticEntry, cReport, payload},
  args = parseArgs[];
  opts = mergeOptions[defaultOptions[], args];
  opts["sCuts"] = parseList[opts["sCuts"]];
  opts["irSamples"] = parseList[opts["irSamples"]];
  validity = validateOptions[opts];
  If[!validity["valid"],
    Print[ExportString[<|"status" -> "error", "message" -> validity["message"]|>,
      "JSON", "Compact" -> True]];
    Return[];
  ];
  subtractions = Round[opts["subtractions"]];
  hVal = heavyIntegral[opts];
  If[hVal === Missing["IntegrationFailure"],
    Print[ExportString[
      <|
        "status" -> "error",
        "message" -> "Failed to integrate heavy spectrum.",
        "options" -> opts
      |>,
      "JSON", "Compact" -> True]];
    Return[];
  ];
  hContribution = heavyContribution[hVal, subtractions];
  bound = contactBound[hVal, subtractions];
  samples = masslessDivergenceSamples[
    opts["poleStrength"], opts["irSamples"], subtractions
  ];
  counterterms = cutoffCounterterms[
    opts["poleStrength"], opts["sCuts"], subtractions
  ];
  analyticEntry = analyticCountertermEntry[
    opts["poleStrength"], subtractions
  ];
  cReport = userCheck[opts["cRen"], bound];
  payload = <|
    "status" -> "ok",
    "subtractions" -> subtractions,
    "prefactor" -> prefactor[subtractions],
    "inputs" -> <|
      "poleStrength" -> opts["poleStrength"],
      "heavyStrength" -> opts["heavyStrength"],
      "heavyScale" -> opts["heavyScale"],
      "heavyThreshold" -> opts["heavyThreshold"],
      "growthPower" -> opts["growthPower"],
      "tailExponent" -> opts["tailExponent"],
      "integrationMax" -> formatValue[opts["integrationMax"]],
      "precision" -> opts["precision"],
      "accuracyGoal" -> opts["accuracyGoal"],
      "precisionGoal" -> opts["precisionGoal"]
    |>,
    "heavyIntegral" -> hVal,
    "heavyContribution" -> hContribution,
    "cRenBound" -> bound,
    "userCoefficient" -> cReport,
    "masslessPole" -> <|
      "poleStrength" -> opts["poleStrength"],
      "divergenceSamples" -> samples,
      "counterterms" -> If[analyticEntry === <||>,
        counterterms,
        Append[counterterms, analyticEntry]
      ]
    |>
  |>;
  Print[ExportString[payload, "JSON", "Compact" -> True]];
];

main[];
