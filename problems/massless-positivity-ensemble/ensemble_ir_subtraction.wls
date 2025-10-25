#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Ensemble IR-subtracted positivity survey for forward 2 -> 2 amplitudes with
  massless t-channel exchanges. The script draws fat-tailed heavy spectra from
  Pareto-controlled parameter ranges, evaluates twice-subtracted dispersion
  integrals, and contrasts analytic pole subtraction against cutoff schemes.
  Outputs JSON capturing per-sample diagnostics together with aggregate order
  statistics for the renormalised Wilson coefficient bound and margins.
*)

SetDirectory[DirectoryName[$InputFileName]];

ClearAll[parseArgs, parseValue, toNumber, parseList];
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

parseList[val_List] := DeleteCases[N /@ val, _Missing];
parseList[_Missing] := {};
parseList[_] := {};

ClearAll[defaultOptions];
defaultOptions := <|
  "samples" -> 16,
  "seed" -> 20251025,
  "subtractions" -> 2,
  "cRen" -> Missing["NotProvided"],
  "poleMin" -> 0.08,
  "poleShape" -> 3.2,
  "poleCap" -> 0.35,
  "irCuts" -> {0.25, 0.15, 0.08},
  "irSamples" -> {0.25, 0.15, 0.08},
  "growthRange" -> {2.2, 3.4},
  "thresholdRange" -> {1.1, 1.8},
  "tailOffsetScale" -> 0.5,
  "tailOffsetShape" -> 2.6,
  "tailOffsetCap" -> 2.5,
  "scaleParetoMin" -> 2.0,
  "scaleParetoShape" -> 2.4,
  "scaleCap" -> 8.0,
  "strengthParetoMin" -> 0.6,
  "strengthParetoShape" -> 2.8,
  "strengthCap" -> 3.5,
  "precision" -> 60,
  "accuracyGoal" -> 12,
  "precisionGoal" -> 12,
  "integrationMax" -> Infinity,
  "maxRecursion" -> 10
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
  {subtractions = Round[opts["subtractions"]], growthRange, thresholdRange},
  growthRange = opts["growthRange"];
  thresholdRange = opts["thresholdRange"];
  If[subtractions =!= 2,
    Return[<|"valid" -> False,
      "message" -> "Only two subtractions supported."|>]
  ];
  If[!VectorQ[growthRange, NumericQ] || Length[growthRange] =!= 2,
    Return[<|"valid" -> False,
      "message" -> "growthRange must contain two numeric bounds."|>]
  ];
  If[!VectorQ[thresholdRange, NumericQ] || Length[thresholdRange] =!= 2,
    Return[<|"valid" -> False,
      "message" -> "thresholdRange must contain two numeric bounds."|>]
  ];
  If[thresholdRange[[1]] <= 0,
    Return[<|"valid" -> False,
      "message" -> "Threshold lower bound must be positive."|>]
  ];
  If[opts["poleMin"] <= 0,
    Return[<|"valid" -> False,
      "message" -> "poleMin must be positive."|>]
  ];
  If[opts["tailOffsetScale"] <= 0,
    Return[<|"valid" -> False,
      "message" -> "tailOffsetScale must be positive."|>]
  ];
  If[opts["samples"] < 1,
    Return[<|"valid" -> False,
      "message" -> "samples must be at least one."|>]
  ];
  <|"valid" -> True, "message" -> "OK"|>
];

ClearAll[prefactor, contactBound, randomPareto];
prefactor[subtractions_Integer] :=
  If[subtractions === 2, 2./Pi, Missing["Unsupported"]];

contactBound[val_, subtractions_Integer] := Module[{pf = prefactor[subtractions]},
  If[NumericQ[pf], (pf*val)/2., Missing["Unsupported"]]
];

randomPareto[min_, shape_, cap_] := Module[{draw},
  draw = RandomVariate[ParetoDistribution[min, shape]];
  Min[draw, cap]
];

ClearAll[sampleParameters];
sampleParameters[opts_Association] := Module[
  {growth, tailOffset, tailExponent, scale, strength, threshold, pole},
  growth = RandomReal[opts["growthRange"]];
  tailOffset = randomPareto[
    opts["tailOffsetScale"], opts["tailOffsetShape"], opts["tailOffsetCap"]
  ];
  tailExponent = growth + 2. + tailOffset;
  scale = randomPareto[
    opts["scaleParetoMin"], opts["scaleParetoShape"], opts["scaleCap"]
  ];
  strength = randomPareto[
    opts["strengthParetoMin"], opts["strengthParetoShape"], opts["strengthCap"]
  ];
  threshold = RandomReal[opts["thresholdRange"]];
  pole = randomPareto[opts["poleMin"], opts["poleShape"], opts["poleCap"]];
  <|
    "heavyThreshold" -> threshold,
    "heavyStrength" -> strength,
    "heavyScale" -> scale,
    "growthPower" -> growth,
    "tailOffset" -> tailOffset,
    "tailExponent" -> tailExponent,
    "poleStrength" -> pole
  |>
];

ClearAll[heavyIntegrand];
heavyIntegrand[s_, params_Association, subtractions_Integer] := Module[
  {threshold = params["heavyThreshold"], x},
  If[s <= threshold,
    0.,
    x = s - threshold;
    params["heavyStrength"]*(x^params["growthPower"]) /
      (1. + x/params["heavyScale"])^params["tailExponent"] /
      s^(subtractions + 1)
  ]
];

ClearAll[heavyIntegral];
heavyIntegral[params_Association, opts_Association, subtractions_Integer] :=
 Module[{integrand, upper = opts["integrationMax"], prec = opts["precision"],
   acc = opts["accuracyGoal"], goal = opts["precisionGoal"], rec = opts["maxRecursion"]},
  integrand[s_] := heavyIntegrand[s, params, subtractions];
  Quiet@Check[
    NIntegrate[
      integrand[s],
      {s, params["heavyThreshold"], upper},
      Method -> {"GlobalAdaptive", "SymbolicProcessing" -> 0},
      WorkingPrecision -> prec,
      AccuracyGoal -> acc,
      PrecisionGoal -> goal,
      MaxRecursion -> rec
    ],
    Missing["IntegrationFailure"]
  ]
];

ClearAll[masslessDivergence, cutoffCounterterms, analyticEntry];
masslessDivergence[pole_, epsList_List, subtractions_Integer] := Module[
  {pf = prefactor[subtractions]},
  If[!NumericQ[pf],
    {},
    Table[
      <|
        "epsilon" -> eps,
        "estimate" -> If[eps > 0, pf*pole/(3.*eps^3), Infinity]
      |>,
      {eps, epsList}
    ]
  ]
];

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

analyticEntry[pole_, subtractions_Integer] := Module[
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

ClearAll[userAssessment];
userAssessment[cRen_, bound_] := Module[{margin},
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

ClearAll[sanitize];
sanitize[val_] := Which[
  val === Infinity, "Infinity",
  val === -Infinity, "-Infinity",
  NumericQ[val], N[val, 16],
  True, val
];

ClearAll[evaluateSample];
evaluateSample[index_Integer, opts_Association, subtractions_Integer] := Module[
  {params, integral, bound, divergence, counterterms, analytic, user, record,
   heavyContribution, poleBlock, mergedCounterterms, marginValue},
  params = sampleParameters[opts];
  integral = heavyIntegral[params, opts, subtractions];
  If[integral === Missing["IntegrationFailure"],
    Return[<|
      "status" -> "failed",
      "sampleIndex" -> index,
      "parameters" -> Map[sanitize, params],
      "message" -> "Failed to integrate heavy spectrum."
    |>]
  ];
  bound = contactBound[integral, subtractions];
  heavyContribution = prefactor[subtractions]*integral;
  divergence = masslessDivergence[params["poleStrength"], opts["irSamples"],
    subtractions];
  counterterms = cutoffCounterterms[params["poleStrength"], opts["irCuts"],
    subtractions];
  analytic = analyticEntry[params["poleStrength"], subtractions];
  mergedCounterterms = If[analytic === <||>, counterterms,
    Append[counterterms, analytic]
  ];
  user = userAssessment[opts["cRen"], bound];
  marginValue = user["margin"];
  poleBlock = <|
    "poleStrength" -> params["poleStrength"],
    "divergenceSamples" -> divergence,
    "counterterms" -> mergedCounterterms
  |>;
  record = <|
    "status" -> "ok",
    "sampleIndex" -> index,
    "parameters" -> params,
    "heavyIntegral" -> integral,
    "heavyContribution" -> heavyContribution,
    "cRenBound" -> bound,
    "margin" -> If[NumericQ[marginValue], marginValue, "NotEvaluated"],
    "user" -> user,
    "masslessPole" -> poleBlock
  |>;
  Map[sanitize, record, {0, Infinity}]
];

ClearAll[orderStats];
orderStats[list_List] /; list =!= {} := Module[
  {sorted = Sort[list], qs = {0.1, 0.25, 0.5, 0.75, 0.9}},
  <|
    "min" -> First[sorted],
    "q10" -> Quantile[sorted, qs[[1]]],
    "q25" -> Quantile[sorted, qs[[2]]],
    "q50" -> Quantile[sorted, qs[[3]]],
    "q75" -> Quantile[sorted, qs[[4]]],
    "q90" -> Quantile[sorted, qs[[5]]],
    "max" -> Last[sorted]
  |>
];
orderStats[_] := <||>;

ClearAll[aggregateStats];
aggregateStats[results_List, opts_Association] := Module[
  {success, bounds, margins, poleValues, paramList, heavyStrengths, scales,
   thresholds, growths, tailExponents, tailOffsets, violationPositions,
   violationFraction, aggregate},
  success = Select[results, #"status" === "ok" &];
  If[success === {},
    Return[<|
      "evaluated" -> Length[results],
      "message" -> "No successful samples to analyse."
    |>]
  ];
  bounds = Lookup[success, "cRenBound"];
  margins = Select[Lookup[success, "margin"], NumericQ];
  violationPositions = Lookup[
    Select[success, NumericQ[#"margin"] && #"margin" < 0 &],
    "sampleIndex"
  ];
  violationFraction = If[margins === {}, "NotEvaluated",
    N[Count[margins, _?(# < 0 &)]/Length[margins], 16]
  ];
  paramList = Lookup[success, "parameters"];
  poleValues = Lookup[paramList, "poleStrength"];
  heavyStrengths = Lookup[paramList, "heavyStrength"];
  scales = Lookup[paramList, "heavyScale"];
  thresholds = Lookup[paramList, "heavyThreshold"];
  growths = Lookup[paramList, "growthPower"];
  tailExponents = Lookup[paramList, "tailExponent"];
  tailOffsets = Lookup[paramList, "tailOffset"];
  aggregate = <|
    "successCount" -> Length[success],
    "bounds" -> <|
      "sorted" -> Sort[bounds],
      "orderStats" -> orderStats[bounds]
    |>,
    "margins" -> If[margins === {},
      <|"evaluated" -> "NotProvided"|>,
      <|
        "sorted" -> Sort[margins],
        "orderStats" -> orderStats[margins],
        "violationIndices" -> violationPositions,
        "violationFraction" -> violationFraction
      |>
    ],
    "parameters" -> <|
      "poleStrength" -> orderStats[poleValues],
      "heavyStrength" -> orderStats[heavyStrengths],
      "heavyScale" -> orderStats[scales],
      "heavyThreshold" -> orderStats[thresholds],
      "growthPower" -> orderStats[growths],
      "tailExponent" -> orderStats[tailExponents],
      "tailOffset" -> orderStats[tailOffsets]
    |>
  |>;
  Map[sanitize, aggregate, {0, Infinity}]
];

ClearAll[main];
main[] := Module[
  {args, opts, validity, subtractions, samples, results, aggregate, payload},
  args = parseArgs[];
  opts = mergeOptions[defaultOptions[], args];
  opts["irCuts"] = parseList[opts["irCuts"]];
  opts["irSamples"] = parseList[opts["irSamples"]];
  validity = validateOptions[opts];
  If[!validity["valid"],
    Print[ExportString[
      <|"status" -> "error", "message" -> validity["message"]|>,
      "JSON", "Compact" -> True
    ]];
    Return[];
  ];
  subtractions = Round[opts["subtractions"]];
  SeedRandom[opts["seed"]];
  samples = Range[opts["samples"]];
  results = evaluateSample[#, opts, subtractions] & /@ samples;
  aggregate = aggregateStats[results, opts];
  payload = <|
    "status" -> "ok",
    "subtractions" -> subtractions,
    "seed" -> opts["seed"],
    "samplesRequested" -> opts["samples"],
    "evaluation" -> <|
      "successCount" -> Count[results, _?(#"status" === "ok" &)],
      "failureCount" -> Count[results, _?(#"status" =!= "ok" &)]
    |>,
    "options" -> <|
      "irCuts" -> opts["irCuts"],
      "irSamples" -> opts["irSamples"],
      "growthRange" -> opts["growthRange"],
      "thresholdRange" -> opts["thresholdRange"],
      "tailOffset" -> <|
        "scale" -> opts["tailOffsetScale"],
        "shape" -> opts["tailOffsetShape"],
        "cap" -> opts["tailOffsetCap"]
      |>,
      "scalePareto" -> <|
        "min" -> opts["scaleParetoMin"],
        "shape" -> opts["scaleParetoShape"],
        "cap" -> opts["scaleCap"]
      |>,
      "strengthPareto" -> <|
        "min" -> opts["strengthParetoMin"],
        "shape" -> opts["strengthParetoShape"],
        "cap" -> opts["strengthCap"]
      |>,
      "polePareto" -> <|
        "min" -> opts["poleMin"],
        "shape" -> opts["poleShape"],
        "cap" -> opts["poleCap"]
      |>,
      "precision" -> opts["precision"],
      "accuracyGoal" -> opts["accuracyGoal"],
      "precisionGoal" -> opts["precisionGoal"],
      "integrationMax" -> opts["integrationMax"],
      "maxRecursion" -> opts["maxRecursion"]
    |>,
    "ensemble" -> results,
    "aggregate" -> aggregate
  |>;
  Print[ExportString[Map[sanitize, payload, {0, Infinity}], "JSON",
    "Compact" -> True]];
];

main[];
