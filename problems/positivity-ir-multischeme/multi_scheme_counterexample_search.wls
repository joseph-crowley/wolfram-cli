#!/usr/bin/env wolframscript
(*
  Directed counterexample search for multi-scheme IR subtraction bounds.
  Randomly and adaptively samples heavy spectra to maximise the spread across
  analytic, cutoff, exclusion, band, and principal value schemes. Emits a JSON
  artifact containing either a counterexample with certified spread or an
  upper bound on the observed scheme spread under the search budget.
*)

SetDirectory[DirectoryName[$InputFileName]];

Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "Utils.wl"}]];
Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "IR.wl"}]];
Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "MultiScheme.wl"}]];

ClearAll[optionsSpec];
optionsSpec := <|
  "searchSeed" -> <|"Type" -> "Integer", "Default" -> 12345|>,
  "searchTimeCap" -> <|"Type" -> "PositiveReal", "Default" -> 120.|>,
  "intervalCount" -> <|"Type" -> "PositiveInteger", "Default" -> 8,
    "Min" -> 3, "Max" -> 24|>,
  "maxCandidates" -> <|"Type" -> "PositiveInteger", "Default" -> 96|>,
  "historyLimit" -> <|"Type" -> "PositiveInteger", "Default" -> 48|>,
  "schemes" -> <|"Type" -> "String", "Default" -> "Automatic"|>,
  "precision" -> <|"Type" -> "PositiveInteger", "Default" -> 60|>,
  "accuracyGoal" -> <|"Type" -> "PositiveInteger", "Default" -> 12|>,
  "precisionGoal" -> <|"Type" -> "PositiveInteger", "Default" -> 12|>,
  "maxRecursion" -> <|"Type" -> "PositiveInteger", "Default" -> 12|>,
  "intervalAbsTol" -> <|"Type" -> "PositiveReal", "Default" -> 1.*^-10|>,
  "intervalRelTol" -> <|"Type" -> "PositiveReal", "Default" -> 1.*^-6|>,
  "intervalTimeCap" -> <|"Type" -> "PositiveReal", "Default" -> 60.|>,
  "intervalMaxRefine" -> <|"Type" -> "PositiveInteger", "Default" -> 3|>,
  "intervalPrecisionBump" -> <|"Type" -> "PositiveInteger",
    "Default" -> 10|>,
  "intervalGoalBump" -> <|"Type" -> "PositiveInteger", "Default" -> 2|>,
  "intervalRecursionBump" -> <|"Type" -> "PositiveInteger",
    "Default" -> 2|>,
  "poleStrength" -> <|"Type" -> "PositiveReal", "Default" -> 0.2|>,
  "cRen" -> <|"Type" -> "Real", "Default" -> 0.|>,
  "useCoefficient" -> <|"Type" -> "Boolean", "Default" -> False|>,
  "heavyStrengthMin" -> <|"Type" -> "PositiveReal", "Default" -> 0.3|>,
  "heavyStrengthMax" -> <|"Type" -> "PositiveReal", "Default" -> 5.0|>,
  "heavyScaleMin" -> <|"Type" -> "PositiveReal", "Default" -> 0.8|>,
  "heavyScaleMax" -> <|"Type" -> "PositiveReal", "Default" -> 8.0|>,
  "heavyThresholdMin" -> <|"Type" -> "PositiveReal", "Default" -> 1.05|>,
  "heavyThresholdMax" -> <|"Type" -> "PositiveReal", "Default" -> 3.5|>,
  "growthPowerMin" -> <|"Type" -> "Real", "Default" -> 2.0|>,
  "growthPowerMax" -> <|"Type" -> "Real", "Default" -> 4.8|>,
  "tailMarginMin" -> <|"Type" -> "PositiveReal", "Default" -> 0.4|>,
  "tailMarginMax" -> <|"Type" -> "PositiveReal", "Default" -> 5.0|>,
  "integrationMaxMin" -> <|"Type" -> "PositiveReal", "Default" -> 3.5|>,
  "integrationMaxMax" -> <|"Type" -> "PositiveReal", "Default" -> 45.|>,
  "finiteIntegrationProbability" -> <|"Type" -> "PositiveReal",
    "Default" -> 0.35, "Min" -> 0., "Max" -> 1.|>,
  "spreadThreshold" -> <|"Type" -> "PositiveReal", "Default" -> 1.*^-4|>,
  "upperBoundTarget" -> <|"Type" -> "PositiveReal", "Default" -> 1.*^-6|>
|>;

ClearAll[parseSchemes];
parseSchemes[str_String] := Module[{trim = StringTrim[str], parsed},
  If[trim === "Automatic", Return[Automatic]];
  parsed = Quiet@Check[ImportString[trim, "JSON"], $Failed];
  If[parsed === $Failed || !ListQ[parsed], Automatic, parsed]
];
parseSchemes[_] := Automatic;

ClearAll[buildBaseOptions];
buildBaseOptions[opts_Association] := Module[
  {defaults = PhysicsCLI`MultiScheme`MultiSchemeDefaultOptions[], overrides},
  overrides = <|
    "poleStrength" -> opts["poleStrength"],
    "precision" -> opts["precision"],
    "accuracyGoal" -> opts["accuracyGoal"],
    "precisionGoal" -> opts["precisionGoal"],
    "maxRecursion" -> opts["maxRecursion"],
    "intervalAbsTol" -> opts["intervalAbsTol"],
    "intervalRelTol" -> opts["intervalRelTol"],
    "intervalTimeCap" -> opts["intervalTimeCap"],
    "intervalMaxRefine" -> opts["intervalMaxRefine"],
    "intervalPrecisionBump" -> opts["intervalPrecisionBump"],
    "intervalGoalBump" -> opts["intervalGoalBump"],
    "intervalRecursionBump" -> opts["intervalRecursionBump"],
    "cRen" -> If[TrueQ[opts["useCoefficient"]], opts["cRen"],
      Missing["NotProvided"]]
  |>;
  PhysicsCLI`MultiScheme`MultiSchemeMergeOptions[defaults, overrides]
];

ClearAll[rangeConfig];
rangeConfig[opts_Association] := <|
  "heavyStrength" -> {opts["heavyStrengthMin"], opts["heavyStrengthMax"]},
  "heavyScale" -> {opts["heavyScaleMin"], opts["heavyScaleMax"]},
  "heavyThreshold" -> {opts["heavyThresholdMin"],
    Max[opts["heavyThresholdMin"] + 0.1, opts["heavyThresholdMax"]]},
  "growthPower" -> {opts["growthPowerMin"], opts["growthPowerMax"]},
  "tailMargin" -> {opts["tailMarginMin"], opts["tailMarginMax"]},
  "integrationMax" -> {opts["integrationMaxMin"], opts["integrationMaxMax"]},
  "finiteIntegrationProbability" -> opts["finiteIntegrationProbability"]
|>;

ClearAll[boundedValue];
boundedValue[val_, {min_, max_}] := Module[{upper = max},
  Which[
    upper === Infinity, Max[val, min],
    True, Min[Max[val, min], upper]
  ]
];

ClearAll[fatTailSample];
fatTailSample[{min_, max_}, alpha_: 2.7] := Module[{u = RandomReal[]},
  min + (max - min)*(1. - (1. - u)^(1./alpha))
];

ClearAll[globalCandidate];
globalCandidate[ranges_Association] := Module[
  {hs, hscale, hth, gp, tm, tailExp, finProb, intMax, marginFloor},
  hs = fatTailSample[ranges["heavyStrength"], 3.2];
  hscale = fatTailSample[ranges["heavyScale"], 2.4];
  hth = RandomReal[ranges["heavyThreshold"]];
  gp = RandomReal[ranges["growthPower"]];
  tm = RandomReal[ranges["tailMargin"]];
  marginFloor = ranges["tailMargin"][[1]];
  tailExp = gp + 2. + Max[tm, marginFloor];
  finProb = ranges["finiteIntegrationProbability"];
  intMax = If[RandomReal[] < finProb,
    Module[{candidate = fatTailSample[ranges["integrationMax"], 2.5]},
      Max[candidate, hth + 0.2]
    ],
    Infinity
  ];
  <|
    "heavyStrength" -> hs,
    "heavyScale" -> hscale,
    "heavyThreshold" -> hth,
    "growthPower" -> gp,
    "tailExponent" -> Max[tailExp, gp + 2.2],
    "integrationMax" -> intMax
  |>
];

ClearAll[mutateCandidate];
mutateCandidate[best_Association, ranges_Association] := Module[
  {hs, hscale, hth, gp, baseMargin, newMargin, tailExp, intMax, finProb},
  hs = boundedValue[best["heavyStrength"]*
      Exp[RandomVariate[NormalDistribution[0., 0.35]]],
    ranges["heavyStrength"]];
  hscale = boundedValue[best["heavyScale"]*
      Exp[RandomVariate[NormalDistribution[0., 0.3]]],
    ranges["heavyScale"]];
  hth = boundedValue[best["heavyThreshold"] +
      RandomVariate[NormalDistribution[0., 0.12]],
    ranges["heavyThreshold"]];
  gp = boundedValue[best["growthPower"] +
      RandomVariate[NormalDistribution[0., 0.18]],
    ranges["growthPower"]];
  baseMargin = Max[best["tailExponent"] - (best["growthPower"] + 2.),
    ranges["tailMargin"][[1]]];
  newMargin = boundedValue[baseMargin*
      Exp[RandomVariate[NormalDistribution[0., 0.25]]],
    ranges["tailMargin"]];
  tailExp = gp + 2. + Max[newMargin, ranges["tailMargin"][[1]]];
  finProb = ranges["finiteIntegrationProbability"];
  intMax = Which[
    best["integrationMax"] === Infinity,
      If[RandomReal[] < finProb,
        Max[fatTailSample[ranges["integrationMax"], 2.], hth + 0.2],
        Infinity
      ],
    True,
      boundedValue[best["integrationMax"]*
        Exp[RandomVariate[NormalDistribution[0., 0.35]]],
        ranges["integrationMax"]]
  ];
  <|
    "heavyStrength" -> hs,
    "heavyScale" -> hscale,
    "heavyThreshold" -> hth,
    "growthPower" -> gp,
    "tailExponent" -> Max[tailExp, gp + 2.2],
    "integrationMax" -> intMax
  |>
];

ClearAll[normalizeCandidate];
normalizeCandidate[candidate_Association] := Module[
  {assoc = Association[candidate], value},
  value = Lookup[assoc, "integrationMax", Missing["KeyAbsent", "integrationMax"]];
  If[value === Infinity, assoc["integrationMax"] = "Infinity"];
  If[value === -Infinity, assoc["integrationMax"] = "-Infinity"];
  assoc
];
normalizeCandidate[other_] := other;

ClearAll[evaluateCandidate];
evaluateCandidate[base_Association, schemeSpecs_, candidate_Association] :=
 Module[{optsAssoc = Association[base]},
  KeyValueMap[(optsAssoc[#1] = #2) &, candidate];
  PhysicsCLI`MultiScheme`MultiSchemeEvaluatePayload[optsAssoc, schemeSpecs]
];

ClearAll[historyEntry];
historyEntry[index_Integer, elapsed_, candidate_Association, payload_] :=
 Module[{status = Lookup[payload, "status", "error"], aggregate, spread,
   message = Lookup[payload, "message", ""], record,
   cand = normalizeCandidate[candidate]},
  If[status === "ok",
    aggregate = Lookup[payload, "aggregate", <||>];
    spread = Lookup[aggregate, "spread", Missing["NoSpread"]];
    record = <|
      "index" -> index,
      "status" -> status,
      "elapsedSec" -> elapsed,
      "spread" -> spread,
      "minBound" -> Lookup[aggregate, "minBound", Missing["NoMin"]],
      "maxBound" -> Lookup[aggregate, "maxBound", Missing["NoMax"]],
      "consistent" -> Lookup[aggregate, "consistentWithBase", Missing["NA"]],
      "candidate" -> cand
    |>,
    record = <|
      "index" -> index,
      "status" -> status,
      "elapsedSec" -> elapsed,
      "message" -> message,
      "candidate" -> cand
    |>
  ];
  record
 ];

ClearAll[clipHistory];
clipHistory[history_List, limit_Integer] :=
 If[Length[history] <= limit, history, Take[history, -limit]];

ClearAll[sanitizeValue];
sanitizeValue[assoc_Association] := AssociationMap[sanitizeValue, assoc];
sanitizeValue[list_List] := sanitizeValue /@ list;
sanitizeValue[Infinity] := "Infinity";
sanitizeValue[-Infinity] := "-Infinity";
sanitizeValue[DirectedInfinity[_]] := "Infinity";
sanitizeValue[ComplexInfinity] := "ComplexInfinity";
sanitizeValue[Missing[__]] := "Missing";
sanitizeValue[val_?NumericQ] := N[val, 16];
sanitizeValue[other_] := other;

main[] := Module[
  {parsed, errors, warnings, opts, baseOptions, ranges, schemeSpecs,
   searchSeed, timeCap, intervalBudget, maxCandidates, historyLimit,
   spreadThreshold, upperBoundTarget, startTime, elapsed, timeout,
   evaluations = 0, history = {}, best = <|"spread" -> -Infinity|>,
   candidate, payload, summary, aggregate, spread, elapsedNow, chooseLocal,
   randomChoice, candidateClean, resultBlock, artifact, warningsBlock},
  parsed = PhysicsCLI`Utils`ParseOptions[
    optionsSpec,
    Rest[$ScriptCommandLine]
  ];
  errors = parsed["Errors"];
  warnings = parsed["Warnings"];
  If[errors =!= {},
    PhysicsCLI`Utils`EmitJSON[<|
      "status" -> "error",
      "message" -> StringRiffle[errors, "; " ]
    |>];
    Return[];
  ];
  opts = parsed["Options"];
  baseOptions = buildBaseOptions[opts];
  ranges = rangeConfig[opts];
  schemeSpecs = parseSchemes[opts["schemes"]];
  searchSeed = opts["searchSeed"];
  timeCap = opts["searchTimeCap"];
  intervalBudget = opts["intervalCount"];
  maxCandidates = opts["maxCandidates"];
  historyLimit = opts["historyLimit"];
  spreadThreshold = opts["spreadThreshold"];
  upperBoundTarget = opts["upperBoundTarget"];
  SeedRandom[searchSeed];
  startTime = AbsoluteTime[];
  timeout = False;
  While[evaluations < maxCandidates,
    elapsedNow = AbsoluteTime[] - startTime;
    If[elapsedNow >= timeCap, timeout = True; Break[]];
    chooseLocal = evaluations >= intervalBudget;
    randomChoice = RandomReal[];
    candidate = Which[
      !chooseLocal, globalCandidate[ranges],
      Lookup[best, "payload", None] === None, globalCandidate[ranges],
      randomChoice < 0.3, globalCandidate[ranges],
      True, mutateCandidate[best["candidate"], ranges]
    ];
    payload = evaluateCandidate[baseOptions, schemeSpecs, candidate];
    elapsedNow = AbsoluteTime[] - startTime;
    summary = historyEntry[evaluations + 1, elapsedNow, candidate, payload];
    history = clipHistory[Append[history, summary], historyLimit];
    If[Lookup[payload, "status", "error"] === "ok",
      aggregate = Lookup[payload, "aggregate", <||>];
      spread = Lookup[aggregate, "spread", -Infinity];
      If[spread > Lookup[best, "spread", -Infinity],
        best = <|
          "spread" -> spread,
          "candidate" -> candidate,
          "payload" -> payload,
          "elapsedSec" -> elapsedNow
        |>
      ];
    ];
    evaluations++;
  ];
  elapsed = AbsoluteTime[] - startTime;
  If[elapsed >= timeCap, timeout = True];
  candidateClean = normalizeCandidate[
    Lookup[best, "candidate", <||>]
  ];
  resultBlock = Which[
    Lookup[best, "payload", None] === None,
      <|
        "result" -> "no-success",
        "message" -> "No candidate completed without errors."
      |>,
    best["spread"] >= spreadThreshold,
      <|
        "result" -> "counterexample",
        "spread" -> best["spread"],
        "threshold" -> spreadThreshold,
        "candidate" -> candidateClean,
        "elapsedSec" -> best["elapsedSec"],
        "payload" -> PhysicsCLI`MultiScheme`MultiSchemeSanitizeJSON[best["payload"]]
      |>,
    True,
      <|
        "result" -> "non-detection",
        "maxObservedSpread" -> best["spread"],
        "upperBoundTarget" -> upperBoundTarget,
        "achieved" -> (best["spread"] < upperBoundTarget),
        "candidate" -> candidateClean,
        "elapsedSec" -> best["elapsedSec"],
        "payload" -> PhysicsCLI`MultiScheme`MultiSchemeSanitizeJSON[best["payload"]]
      |>
  ];
  warningsBlock = If[warnings === {}, Nothing, <|"warnings" -> warnings|>];
  artifact = <|
    "status" -> "ok",
    "search" -> <|
      "seed" -> searchSeed,
      "intervalCount" -> intervalBudget,
      "maxCandidates" -> maxCandidates,
      "evaluations" -> evaluations,
      "timeLimitSec" -> timeCap,
      "elapsedSec" -> elapsed,
      "timeout" -> timeout
    |>,
    "result" -> resultBlock,
    "history" -> history
  |>;
  If[warningsBlock =!= Nothing,
    artifact = Join[artifact, warningsBlock]
  ];
  PhysicsCLI`Utils`EmitJSON[sanitizeValue[artifact]];
];

main[];
