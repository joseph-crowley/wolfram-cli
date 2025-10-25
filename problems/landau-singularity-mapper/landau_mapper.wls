#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Landau singularity mapper for one loop triangle and box topologies.
  Given internal masses and external kinematic invariants, the script
  evaluates the Cayley determinant condition det(Y) = 0 that marks the
  leading Landau surfaces. It supports single variable scans for the
  triangle task and two dimensional s,t sweeps for the box, producing
  ASCII JSON outputs with numerical evaluations and approximate zero
  loci suitable for downstream plotting or regression tests.
*)

SetDirectory[DirectoryName[$InputFileName]];

(* ------------------------------------------------------------------ *)
(* Command line parsing                                               *)
(* ------------------------------------------------------------------ *)

ClearAll[parseArgs, parseValue, toNumber, parseList, parseRange];
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
    StringStartsQ[trim, "{"] && StringEndsQ[trim, "}"],
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

parseRange[val_List] := Module[{clean = parseList[val]},
  If[Length[clean] == 3 && clean[[3]] >= 2,
    clean,
    Missing["InvalidRange"]
  ]
];
parseRange[_] := Missing["InvalidRange"];

(* ------------------------------------------------------------------ *)
(* Core Landau determinant machinery                                  *)
(* ------------------------------------------------------------------ *)

ClearAll[cayleyDeterminant];
cayleyDeterminant[topology_String, masses_List, diff_Association] :=
 Module[{n = Length[masses], getDiff, matrix},
  getDiff[i_, j_] := With[{key = Sort[{i, j}]},
    If[KeyExistsQ[diff, key],
      diff[key],
      Message[cayleyDeterminant::missing, key];
      Return[$Failed, Module]
    ]
  ];
  matrix = Table[
    If[i == j,
      2 masses[[i]]^2,
      masses[[i]]^2 + masses[[j]]^2 - getDiff[i, j]
    ],
    {i, 1, n}, {j, 1, n}
  ];
  Det[matrix]
];
cayleyDeterminant::missing = "Missing invariant for key `1`.";

ClearAll[triangleDiffs, boxDiffs];
triangleDiffs[externalSquares_List] := Module[{},
  Association[
    {1, 2} -> externalSquares[[1]],
    {2, 3} -> externalSquares[[2]],
    {1, 3} -> externalSquares[[3]]
  ]
];

boxDiffs[externalSquares_List, s_, t_] := Module[{assoc},
  assoc = Association[
    {1, 2} -> externalSquares[[1]],
    {2, 3} -> externalSquares[[2]],
    {3, 4} -> externalSquares[[3]],
    {1, 4} -> externalSquares[[4]],
    {1, 3} -> s,
    {2, 4} -> t
  ];
  assoc
];

ClearAll[landauDetValue];
landauDetValue["triangle", masses_List, externalSquares_List] :=
 Module[{diffs = triangleDiffs[externalSquares]},
  cayleyDeterminant["triangle", masses, diffs]
];

landauDetValue["box", masses_List, externalSquares_List, s_, t_] :=
 Module[{diffs = boxDiffs[externalSquares, s, t]},
  cayleyDeterminant["box", masses, diffs]
];

(* ------------------------------------------------------------------ *)
(* Scan utilities                                                     *)
(* ------------------------------------------------------------------ *)

ClearAll[scanTriangle];
scanTriangle[masses_List, bases_List, varIndex_Integer, range_List] :=
 Module[{grid = Subdivide[range[[1]], range[[2]], range[[3]] - 1],
   dets},
  dets = Table[
    N@landauDetValue[
      "triangle",
      masses,
      ReplacePart[bases, varIndex -> value]
    ],
    {value, grid}
  ];
  <|
    "variableIndex" -> varIndex,
    "gridValues" -> grid,
    "determinants" -> dets,
    "zeroCandidates" -> zeroBrackets[grid, dets],
    "roots" -> approximateRootsTriangle[
      masses, bases, varIndex, grid, dets
    ]
  |>
];

ClearAll[zeroBrackets];
zeroBrackets[grid_List, dets_List] := Module[
  {pairs = Partition[Transpose[{grid, dets}], 2, 1], zeros = {}, a, b},
  Do[
    {a, b} = pair;
    If[PossibleZeroQ[a[[2]]],
      AppendTo[zeros, <|"interval" -> {a[[1]], a[[1]]}, "type" -> "exact"|>],
      If[PossibleZeroQ[b[[2]]],
        AppendTo[zeros, <|"interval" -> {b[[1]], b[[1]]}, "type" -> "exact"|>],
        If[Sign[a[[2]]] != Sign[b[[2]]],
          AppendTo[zeros,
            <|"interval" -> Sort[{a[[1]], b[[1]]}], "type" -> "bracket"|>
          ]
        ]
      ]
    ],
    {pair, pairs}
  ];
  zeros
];

ClearAll[approximateRootsTriangle];
approximateRootsTriangle[
  masses_List, bases_List, varIndex_Integer, grid_List, dets_List
] := Module[
  {var = Unique["s"], func, brackets, roots = {}, detVal},
  func[val_] := N@landauDetValue[
    "triangle",
    masses,
    ReplacePart[bases, varIndex -> val]
  ];
  brackets = Select[
    zeroBrackets[grid, dets],
    #["type"] == "bracket" &
  ];
  Do[
    Quiet@Check[
      detVal = FindRoot[func[var] == 0.,
        {var, Mean[bracket["interval"]]},
        Method -> "Secant"
      ][[1, 2]];
      AppendTo[roots, detVal],
      Null
    ],
    {bracket, brackets}
  ];
  DeleteDuplicates[roots, (Abs[#1 - #2] < 10^-8) &]
];

ClearAll[scanBox];
scanBox[masses_List, bases_List, sRange_List, tRange_List] :=
 Module[
  {sGrid = Subdivide[sRange[[1]], sRange[[2]], sRange[[3]] - 1],
   tGrid = Subdivide[tRange[[1]], tRange[[2]], tRange[[3]] - 1],
   detTable, rowRoots, colRoots},
  detTable = Table[
    N@landauDetValue["box", masses, bases, s, t],
    {t, tGrid}, {s, sGrid}
  ];
  rowRoots = findRowRoots[masses, bases, sGrid, tGrid, detTable];
  colRoots = findColumnRoots[masses, bases, sGrid, tGrid, detTable];
  <|
    "sGrid" -> sGrid,
    "tGrid" -> tGrid,
    "determinants" -> detTable,
    "rowRoots" -> rowRoots,
    "columnRoots" -> colRoots,
    "curvePoints" -> DeleteDuplicates[
      Join[rowRoots, colRoots],
      Norm[#1 - #2] < 10^-8 &
    ]
  |>
];

ClearAll[findRowRoots];
findRowRoots[masses_List, bases_List, sGrid_List, tGrid_List,
  detTable_List] :=
 Module[{roots = {}, func, brackets, row, dets, tValue},
  Do[
    tValue = tGrid[[rowIndex]];
  dets = detTable[[rowIndex]];
  brackets = Select[
    zeroBrackets[sGrid, dets],
    #["type"] == "bracket" &
  ];
  func[val_] := N@landauDetValue["box", masses, bases, val, tValue];
    Do[
      Quiet@Check[
        AppendTo[roots,
          {FindRoot[func[s] == 0., {s, Mean[bracket["interval"]]},
            Method -> "Secant"
          ][[1, 2]], tValue}
        ],
        Null
      ],
      {bracket, brackets}
    ];
    ,
    {rowIndex, Length[tGrid]}
  ];
  roots
];

ClearAll[findColumnRoots];
findColumnRoots[masses_List, bases_List, sGrid_List, tGrid_List,
  detTable_List] :=
 Module[{roots = {}, func, brackets, col, dets, sValue},
  Do[
    sValue = sGrid[[colIndex]];
  dets = detTable[[All, colIndex]];
  brackets = Select[
    zeroBrackets[tGrid, dets],
    #["type"] == "bracket" &
  ];
  func[val_] := N@landauDetValue["box", masses, bases, sValue, val];
    Do[
      Quiet@Check[
        AppendTo[roots,
          {sValue,
           FindRoot[func[t] == 0., {t, Mean[bracket["interval"]]},
             Method -> "Secant"
           ][[1, 2]]}
        ],
        Null
      ],
      {bracket, brackets}
    ];
    ,
    {colIndex, Length[sGrid]}
  ];
  roots
];

(* ------------------------------------------------------------------ *)
(* Validation                                                         *)
(* ------------------------------------------------------------------ *)

ClearAll[validateInputs];
validateInputs[opts_Association] := Module[
  {top = opts["topology"], imasses, emasses},
  Which[
    ! MemberQ[{"triangle", "box"}, top],
      <|"valid" -> False, "message" -> "topology must be triangle or box."|>,
    True,
      imasses = parseList[opts["internalMasses"]];
      If[top === "triangle",
        emasses = parseList[opts["externalSquares"]];
        Which[
          Length[imasses] != 3,
            <|"valid" -> False,
              "message" -> "triangle needs 3 internal masses."|>,
          Length[emasses] != 3,
            <|"valid" -> False,
              "message" -> "triangle needs 3 external squares."|>,
          ! IntegerQ[Round[opts["scanIndex"]]] ||
            Round[opts["scanIndex"]] < 1 ||
            Round[opts["scanIndex"]] > 3,
            <|"valid" -> False,
              "message" -> "triangle scanIndex must be 1,2,3."|>,
          opts["scanRange"] === Missing["InvalidRange"] &&
            ! NumericQ[opts["scanValue"]],
            <|"valid" -> False,
              "message" -> "triangle requires scanRange or scanValue."|>,
          True,
            <|"valid" -> True, "message" -> "OK"|>
        ],
        (* box validation *)
        emasses = parseList[opts["externalSquares"]];
        Which[
          Length[imasses] != 4,
            <|"valid" -> False,
              "message" -> "box needs 4 internal masses."|>,
          Length[emasses] != 4,
            <|"valid" -> False,
              "message" -> "box needs 4 external squares."|>,
          (opts["sRange"] === Missing["InvalidRange"] &&
            ! NumericQ[opts["s"]]),
            <|"valid" -> False,
              "message" -> "box requires s or sRange."|>,
          (opts["tRange"] === Missing["InvalidRange"] &&
            ! NumericQ[opts["t"]]),
            <|"valid" -> False,
              "message" -> "box requires t or tRange."|>,
          True,
            <|"valid" -> True, "message" -> "OK"|>
        ]
      ]
  ]
];

(* ------------------------------------------------------------------ *)
(* Handlers                                                           *)
(* ------------------------------------------------------------------ *)

ClearAll[handleTriangleCase];
handleTriangleCase[opts_Association, imasses_List, emasses_List] :=
 Module[
  {index, scanResult, value, detExpr,
   evalValue},
  index = Clip[
    Round[opts["scanIndex"]],
    {1, Length[emasses]}
  ];
  value = If[NumericQ[opts["scanValue"]],
    opts["scanValue"],
    Missing["NotSet"]
  ];
  detExpr = landauDetValue["triangle", imasses, emasses];
  evalValue = If[value =!= Missing["NotSet"],
    landauDetValue[
      "triangle",
      imasses,
      ReplacePart[emasses, index -> value]
    ],
    Missing["NotComputed"]
  ];
  scanResult = If[opts["scanRange"] === Missing["InvalidRange"],
    Missing["NoScan"],
    scanTriangle[imasses, emasses, index, opts["scanRange"]]
  ];
  <|
    "topology" -> "triangle",
    "internalMasses" -> imasses,
    "externalSquares" -> emasses,
    "determinant" -> ToString[detExpr, InputForm],
    "evaluation" -> evalValue,
    "scan" -> scanResult
  |>
];

ClearAll[handleBoxCase];
handleBoxCase[opts_Association, imasses_List, emasses_List] :=
 Module[
  {sVal = opts["s"], tVal = opts["t"], sRange = opts["sRange"],
   tRange = opts["tRange"], detExpr, scanResult, uVal},
  detExpr = landauDetValue["box", imasses, emasses,
    If[NumericQ[sVal], sVal, Symbol["s"]],
    If[NumericQ[tVal], tVal, Symbol["t"]]
  ];
  uVal = If[NumericQ[sVal] && NumericQ[tVal],
    Total[emasses] - sVal - tVal,
    Missing["NotComputed"]
  ];
  scanResult = If[sRange === Missing["InvalidRange"] ||
      tRange === Missing["InvalidRange"],
    Missing["NoScan"],
    scanBox[imasses, emasses, sRange, tRange]
  ];
  <|
    "topology" -> "box",
    "internalMasses" -> imasses,
    "externalSquares" -> emasses,
    "s" -> sVal,
    "t" -> tVal,
    "u" -> uVal,
    "determinant" -> ToString[detExpr, InputForm],
    "scan" -> scanResult
  |>
];

(* ------------------------------------------------------------------ *)
(* Main execution                                                     *)
(* ------------------------------------------------------------------ *)

Module[
  {args, defaults, opts, validation, imasses, emasses, output},
  defaults = <|
    "topology" -> "triangle",
    "internalMasses" -> Missing["Required"],
    "externalSquares" -> Missing["Required"],
    "scanIndex" -> 3,
    "scanRange" -> Missing["InvalidRange"],
    "scanValue" -> Missing["NotSet"],
    "s" -> Missing["NotSet"],
    "t" -> Missing["NotSet"],
    "sRange" -> Missing["InvalidRange"],
    "tRange" -> Missing["InvalidRange"]
  |>;

  args = parseArgs[];
  opts = defaults;
  KeyValueMap[
    If[#2 =!= Missing["Invalid"], opts[#1] = #2] &,
    args
  ];

  (* Normalise range inputs *)
  If[AssociationQ[args] && KeyExistsQ[args, "scanRange"],
    opts["scanRange"] = parseRange[args["scanRange"]]
  ];
  If[AssociationQ[args] && KeyExistsQ[args, "sRange"],
    opts["sRange"] = parseRange[args["sRange"]]
  ];
  If[AssociationQ[args] && KeyExistsQ[args, "tRange"],
    opts["tRange"] = parseRange[args["tRange"]]
  ];

  validation = validateInputs[opts];
  If[validation["valid"] =!= True,
    Print[ExportString[
      <|"status" -> "error", "message" -> validation["message"]|>,
      "JSON", "Compact" -> True
    ]];
    Exit[1];
  ];

  imasses = parseList[opts["internalMasses"]];
  emasses = parseList[opts["externalSquares"]];

  output = Which[
    opts["topology"] === "triangle",
      handleTriangleCase[opts, imasses, emasses],
    opts["topology"] === "box",
      handleBoxCase[opts, imasses, emasses]
  ];

  Print[ExportString[
    output /. Missing[_] :> Null,
    "JSON",
    "Compact" -> True
  ]];
];
