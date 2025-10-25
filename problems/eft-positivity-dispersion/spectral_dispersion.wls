#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Dispersive positivity analysis for Euler-Heisenberg photon scattering.
  Builds the f2 and g2 coefficients from partial-wave spectral data using the
  sum rules of arXiv:2210.04675, Equation (3.11). Supports deterministic
  Pareto-sampled spectra to probe fat-tailed UV completions and optional user
  supplied discrete spectral records. Outputs ASCII-safe JSON containing the
  Wilson coefficients a1,a2 plus diagnostic breakdowns of tail dominance.
*)

SetDirectory[DirectoryName[$InputFileName]];

(* ------------------------------------------------------------------------- *)
(* Utilities                                                                 *)
(* ------------------------------------------------------------------------- *)

ClearAll[emitJSON];
emitJSON[data_] := Module[{sanitized},
  sanitized = ReplaceAll[data, Missing[_] :> Null];
  Print[
    ExportString[
      sanitized,
      "JSON",
      "Compact" -> True,
      "CharacterEncoding" -> "ASCII"
    ]
  ];
];

ClearAll[parseArgs];
parseArgs[] := Module[
  {raw = Rest[$ScriptCommandLine], parts, key, value, result = <||>},
  Do[
    If[StringMatchQ[item, "--" ~~ __ ~~ "=" ~~ ___],
      parts = StringSplit[StringDrop[item, 2], "=", 2];
      {key, value} = StringTrim /@ parts;
      result[key] = value;
    ],
    {item, raw}
  ];
  result
];

ClearAll[toNumber];
toNumber[str_String] := Module[{clean, parsed},
  clean = StringReplace[str, RegularExpression["([0-9])e([+-]?[0-9]+)"] :> "$1*^$2"];
  Quiet@Check[
    parsed = ToExpression[clean];
    If[NumericQ[parsed], parsed, Missing["NotNumeric"]],
    Missing["NotNumeric"]
  ]
];
toNumber[other_] := Missing["NotNumeric"];

ClearAll[parseJSON];
parseJSON[str_String] := Quiet@Check[
    ImportString[str, "JSON"],
    Missing["InvalidJSON"]
  ];
parseJSON[_] := Missing["InvalidJSON"];

ClearAll[safeLookup];
safeLookup[assoc_Association, key_, default_] := Lookup[assoc, key, default];
safeLookup[_, _, default_] := default;

(* ------------------------------------------------------------------------- *)
(* Option resolution                                                         *)
(* ------------------------------------------------------------------------- *)

defaultOptions = <|
   "samples" -> 18,
   "seed" -> 20251025,
   "tailExponent" -> 2.6,
  "massMinimum" -> 1.0,
   "massScale" -> 1.0,
   "rhoScale" -> 0.38,
   "rhoShape" -> 2.0,
   "rhoOneFractionMin" -> 0.05,
   "rhoOneFractionMax" -> 0.35,
   "rhoThreeScale" -> 0.22,
   "weightTailPower" -> 1.3,
   "precision" -> 60,
   "spins" -> {0, 2, 3, 4, 5},
   "candidateCoefficients" -> Missing["None"],
   "spectralData" -> Missing["None"],
   "alphaInverse" -> 137.035999206,
   "electronMassGeV" -> 0.000510998950
 |>;

numericKeys = {
   "samples", "seed", "tailExponent", "massMinimum", "massScale",
   "rhoScale", "rhoShape", "rhoOneFractionMin", "rhoOneFractionMax",
   "rhoThreeScale", "weightTailPower", "precision", "alphaInverse",
   "electronMassGeV"
  };

jsonKeys = {"spectralData", "candidateCoefficients", "spins"};

ClearAll[resolveOptions];
resolveOptions[raw_Association] := Module[
  {options = defaultOptions, value, numeric, parsed},
  Do[
    If[KeyExistsQ[raw, key],
      value = raw[key];
      Which[
        MemberQ[numericKeys, key],
        numeric = toNumber[value];
        If[numeric === Missing["NotNumeric"],
          Message[resolveOptions::badnum, key, value],
          options[key] = numeric
        ],
        MemberQ[jsonKeys, key],
        parsed = parseJSON[value];
        If[parsed === Missing["InvalidJSON"],
          Message[resolveOptions::badjson, key],
          options[key] = parsed
        ],
        True,
        options[key] = value
      ]
    ],
    {key, Keys[raw]}
  ];
  options
];

resolveOptions::badnum = "Option `1` expects a numeric value, got `2`.";
resolveOptions::badjson = "Option `1` expects valid JSON.";

(* ------------------------------------------------------------------------- *)
(* Spectral generation                                                       *)
(* ------------------------------------------------------------------------- *)

ClearAll[generateSpectralData];
generateSpectralData[options_Association] := Module[
  {
   samples = Round[options["samples"]],
   tailExponent = N[options["tailExponent"]],
   massMinimum = N[options["massMinimum"]],
   massScale = N[options["massScale"]],
   rhoScale = N[options["rhoScale"]],
   rhoShape = N[options["rhoShape"]],
   rhoOneMin = N[options["rhoOneFractionMin"]],
   rhoOneMax = N[options["rhoOneFractionMax"]],
   rhoThreeScale = N[options["rhoThreeScale"]],
   weightTailPower = N[options["weightTailPower"]],
   spins = options["spins"],
   seed = options["seed"],
   pareto, rhoDist, rhoThreeDist, data, spin, mass, baseWeight, rho2,
   rho1Frac, rho1, rho3, entry
  },
  SeedRandom[seed, Method -> "MersenneTwister"];
  pareto = ParetoDistribution[massMinimum, tailExponent];
  rhoDist = GammaDistribution[rhoShape, rhoScale];
  rhoThreeDist = GammaDistribution[rhoShape, rhoThreeScale];
  data = Table[
    spin = RandomChoice[spins];
    mass = massScale*RandomVariate[pareto];
    baseWeight = mass^-weightTailPower;
    rho2 = baseWeight*RandomVariate[rhoDist];
    rho1Frac = If[EvenQ[spin],
      RandomReal[{rhoOneMin, rhoOneMax}],
      0.0
    ];
    rho1 = rho1Frac*rho2;
    rho3 = Which[
      EvenQ[spin] && spin >= 2,
      baseWeight*RandomVariate[rhoThreeDist],
      OddQ[spin] && spin >= 3,
      baseWeight*RandomVariate[rhoThreeDist],
      True,
      0.0
    ];
    entry = <|
      "spin" -> spin,
      "mass" -> mass,
      "rho1" -> rho1,
      "rho2" -> rho2,
      "rho3" -> rho3
    |>;
    entry,
    {samples}
   ];
  data
];

ClearAll[normalizeSpectralRecord];
normalizeSpectralRecord[assoc_Association] := Module[
  {
   spin = Round[safeLookup[assoc, "spin", 0]],
   mass = N[safeLookup[assoc, "mass", Missing["NotProvided"]]],
   rho1 = N[safeLookup[assoc, "rho1", 0.0]],
   rho2 = N[safeLookup[assoc, "rho2", 0.0]],
   rho3 = N[safeLookup[assoc, "rho3", 0.0]]
  },
  If[!NumericQ[mass] || mass <= 0,
    Message[normalizeSpectralRecord::badmass, mass];
    Return[$Failed];
  ];
  If[rho1 < 0 || rho2 < 0 || rho3 < 0,
    Message[normalizeSpectralRecord::badweight, {rho1, rho2, rho3}];
    Return[$Failed];
  ];
  <|
    "spin" -> spin,
    "mass" -> mass,
    "rho1" -> rho1,
    "rho2" -> rho2,
    "rho3" -> rho3
  |>
];

normalizeSpectralRecord::badmass = "Spectral entry mass must be positive, got `1`.";
normalizeSpectralRecord::badweight = "Spectral weights must be non-negative, got `1`.";

ClearAll[resolveSpectralData];
resolveSpectralData[options_Association] := Module[
  {raw = options["spectralData"], normalized},
  Which[
    raw === Missing["None"],
    generateSpectralData[options],
    Head[raw] === List,
    normalized = DeleteCases[
      normalizeSpectralRecord /@ raw,
      _Failed
    ];
    normalized,
    True,
    Message[resolveSpectralData::badinput];
    generateSpectralData[options]
  ]
];

resolveSpectralData::badinput = "Spectral data must be a JSON list of objects.";

(* ------------------------------------------------------------------------- *)
(* Sum rule evaluation                                                       *)
(* ------------------------------------------------------------------------- *)

ClearAll[entryContributions];
entryContributions[entry_Association, precision_] := Module[
  {
   spin = entry["spin"],
   mass = SetPrecision[entry["mass"], precision],
   rho1 = SetPrecision[safeLookup[entry, "rho1", 0.0], precision],
   rho2 = SetPrecision[safeLookup[entry, "rho2", 0.0], precision],
   rho3 = SetPrecision[safeLookup[entry, "rho3", 0.0], precision],
   factor, massPower, plus = 0., minus = 0., even = 0., odd = 0.
  },
  If[mass <= 0,
    Return[<|"plus" -> 0., "minus" -> 0., "even" -> 0., "odd" -> 0.|>];
  ];
  factor = SetPrecision[16.0*Pi*(2 spin + 1), precision];
  massPower = mass^6;
  If[EvenQ[spin],
    plus = (factor/2.0)*(rho2 + rho1)/massPower;
    minus = (factor/2.0)*(rho2 - rho1)/massPower;
    If[spin >= 2,
      even = factor*rho3/massPower;
    ],
    If[spin >= 3,
      odd = factor*rho3/massPower;
    ]
  ];
  <|
    "plus" -> plus,
    "minus" -> minus,
    "even" -> even,
    "odd" -> odd
  |>
];

ClearAll[aggregateBrackets];
aggregateBrackets[data_List, precision_] := Module[
  {contribs, totals},
  contribs = entryContributions[#, precision] & /@ data;
  totals = Total /@ Transpose[Values /@ contribs];
  <|
    "plus" -> totals[[1]],
    "minus" -> totals[[2]],
    "even" -> totals[[3]],
    "odd" -> totals[[4]],
    "perEntry" -> MapThread[
      Join,
      {data, contribs}
    ]
  |>
];

ClearAll[computeCoefficients];
computeCoefficients[brackets_Association] := Module[
  {
   plus = brackets["plus"],
   minus = brackets["minus"],
   even = brackets["even"],
   odd = brackets["odd"],
   f2, g2, a1, a2
  },
  f2 = plus - minus;
  g2 = plus + minus + even + odd;
  a1 = (g2 + f2)/16.;
  a2 = (g2 - f2)/16.;
  <|
    "f2" -> f2,
    "g2" -> g2,
    "a1" -> a1,
    "a2" -> a2
  |>
];

ClearAll[standardModelCoefficients];
standardModelCoefficients[options_Association] := Module[
  {
   alphaInverse = N[options["alphaInverse"]],
   electronMass = N[options["electronMassGeV"]],
   alpha, base, a1, a2, f2, g2
  },
  alpha = 1.0/alphaInverse;
  base = alpha^2/(90.0*electronMass^4);
  a1 = base;
  a2 = (7.0/4.0)*base;
  g2 = 8.0*(a1 + a2);
  f2 = 8.0*(a1 - a2);
  <|"a1" -> a1, "a2" -> a2, "f2" -> f2, "g2" -> g2|>
];

ClearAll[evaluateCandidate];
evaluateCandidate[candidate_, coeffs_] := Module[
  {
   candidateAssoc,
   a1Raw,
   a2Raw,
   a1, a2, conditions
  },
  candidateAssoc = Which[
    AssociationQ[candidate], candidate,
    MatchQ[candidate, {_Rule ..}], Association[candidate],
    True, <||>
  ];
  a1Raw = safeLookup[candidateAssoc, "a1", Missing["NotProvided"]];
  a2Raw = safeLookup[candidateAssoc, "a2", Missing["NotProvided"]];
  a1 = Quiet@Check[N[a1Raw], Missing["NotNumeric"]];
  a2 = Quiet@Check[N[a2Raw], Missing["NotNumeric"]];
  If[!NumericQ[a1] || !NumericQ[a2],
    Return[
      <|"status" -> "invalid", "reason" -> "Candidate requires numeric a1 and a2."|>
    ];
  ];
  conditions = <|
    "a1Positive" -> (a1 > 0),
    "a2Positive" -> (a2 > 0),
    "sumPositive" -> (a1 + a2 > 0)
  |>;
  <|
    "status" -> "evaluated",
    "input" -> <|"a1" -> a1, "a2" -> a2|>,
    "conditions" -> conditions,
    "comparisonToModel" -> <|
      "a1FractionOfModel" -> If[coeffs["a1"] =!= 0,
        a1/coeffs["a1"],
        Missing["Undefined"]
      ],
      "a2FractionOfModel" -> If[coeffs["a2"] =!= 0,
        a2/coeffs["a2"],
        Missing["Undefined"]
      ]
    |>
  |>
];

ClearAll[tailDiagnostics];
tailDiagnostics[perEntry_List, coeffs_Association] := Module[
  {
   gContribs, a1Contribs, a2Contribs, sortedG, quantiles, cumulative,
   takeTop
  },
  gContribs = perEntry /. assoc_Association :> safeLookup[assoc, "plus", 0.] +
      safeLookup[assoc, "minus", 0.] +
      safeLookup[assoc, "even", 0.] +
      safeLookup[assoc, "odd", 0.];
  a1Contribs = (gContribs + (perEntry /. assoc_Association :> safeLookup[assoc, "plus", 0.] -
          safeLookup[assoc, "minus", 0.]))/16.;
  a2Contribs = (gContribs - (perEntry /. assoc_Association :> safeLookup[assoc, "plus", 0.] -
          safeLookup[assoc, "minus", 0.]))/16.;
  sortedG = Reverse@SortBy[Transpose[{perEntry, gContribs}], Last];
  quantiles = Quantile[gContribs, {0.1, 0.25, 0.5, 0.75, 0.9}];
  cumulative = Accumulate[Last /@ sortedG];
  takeTop = Min[Length[sortedG], 5];
  <|
    "g2Quantiles" -> quantiles,
    "topContributors" -> Table[
      <|
        "rank" -> idx,
        "spin" -> sortedG[[idx, 1, "spin"]],
        "mass" -> sortedG[[idx, 1, "mass"]],
        "g2Share" -> sortedG[[idx, 2]],
        "cumulativeFraction" -> If[coeffs["g2"] =!= 0,
          cumulative[[idx]]/coeffs["g2"],
          Missing["Undefined"]
        ]
      |>,
      {idx, takeTop}
     ],
    "a1Contributions" -> <|
      "total" -> coeffs["a1"],
      "min" -> Min[a1Contribs],
      "max" -> Max[a1Contribs]
     |>,
    "a2Contributions" -> <|
      "total" -> coeffs["a2"],
      "min" -> Min[a2Contribs],
      "max" -> Max[a2Contribs]
     |>
  |>
];

(* ------------------------------------------------------------------------- *)
(* Main driver                                                               *)
(* ------------------------------------------------------------------------- *)

ClearAll[main];
main[] := Module[
  {
   rawArgs = parseArgs[],
  options, spectralData, precision, brackets, coeffs, smCoeffs,
   candidateEval, diagnostics, payload, optionsOut
  },
  options = resolveOptions[rawArgs];
  precision = Max[20, Round[options["precision"]]];
  spectralData = resolveSpectralData[options];
  brackets = aggregateBrackets[spectralData, precision];
  coeffs = computeCoefficients[brackets];
  smCoeffs = standardModelCoefficients[options];
  candidateEval = If[options["candidateCoefficients"] === Missing["None"],
    Missing["Skipped"],
    evaluateCandidate[options["candidateCoefficients"], coeffs]
  ];
  diagnostics = tailDiagnostics[brackets["perEntry"], coeffs];
  optionsOut = Association[Normal[options]];
  optionsOut["spectralData"] = If[
    options["spectralData"] === Missing["None"],
    "generated",
    options["spectralData"]
  ];
  optionsOut["candidateCoefficients"] = If[
    options["candidateCoefficients"] === Missing["None"],
    "skipped",
    options["candidateCoefficients"]
  ];
  payload = <|
    "options" -> optionsOut,
    "spectralData" -> brackets["perEntry"],
    "brackets" -> KeyDrop[brackets, "perEntry"],
    "coefficients" -> coeffs,
    "standardModelReference" -> smCoeffs,
    "candidateEvaluation" -> candidateEval,
    "diagnostics" -> diagnostics
  |>;
  emitJSON[payload];
];

main[];
