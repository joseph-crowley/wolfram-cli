#!/usr/bin/env wolframscript
(* billiard_eigs.wls: compute eigenvalues and sample modes of a stadium billiard. *)

Needs["NDSolve`FEM`"];

parseArgs[spec_Association] :=
 Module[{args = Rest@$ScriptCommandLine, assoc, defaults, keyRaw, valRaw, parser, err},
  err = If[ValueQ[$StandardError], $StandardError, $Output];
  defaults = Values[spec][[All, "Default"]];
  assoc = AssociationThread[Keys[spec], defaults];
  Do[
   Which[
    StringMatchQ[arg, "--" ~~ ___ ~~ "=" ~~ ___],
    {keyRaw, valRaw} = StringSplit[StringDrop[arg, 2], "=", 2];
    If[KeyExistsQ[spec, keyRaw],
     parser = Lookup[spec[keyRaw], "Parser", Identity];
     assoc[keyRaw] = parser[valRaw],
     WriteString[err, "Ignoring unknown option --" <> keyRaw <> "\n"]
    ],
    StringMatchQ[arg, "--" ~~ ___],
    keyRaw = StringDrop[arg, 2];
    If[KeyExistsQ[spec, keyRaw],
     If[TrueQ[Lookup[spec[keyRaw], "Flag", False]],
      assoc[keyRaw] = True,
      WriteString[err, "Option --" <> keyRaw <> " requires --" <> keyRaw <> "=value form.\n"]
     ],
     WriteString[err, "Ignoring unknown option --" <> keyRaw <> "\n"]
    ],
    True,
    WriteString[err, "Ignoring positional argument " <> ToString[arg] <> "\n"]
   ],
   {arg, args}
  ];
  assoc
 ];

spec = <|
   "m" -> <|"Default" -> 8, "Parser" -> ToExpression|>,
   "h" -> <|"Default" -> 0.03, "Parser" -> ToExpression|>,
   "prefix" -> <|"Default" -> "mode"|>
   |>;

params = parseArgs(spec);
{modesCount, maxCell, prefix} = Lookup[params, {"m", "h", "prefix"}];

region = RegionUnion[
  Disk[{-0.5, 0}, 0.5],
  Rectangle[{-0.5, -0.5}, {0.5, 0.5}],
  Disk[{0.5, 0}, 0.5]
];
mesh = ToElementMesh[region, MaxCellMeasure -> maxCell];

{vals, funs} = NDEigensystem[
  {
    -Laplacian[u[x, y], {x, y}],
    DirichletCondition[u[x, y] == 0, True]
  },
  u[x, y], {x, y} ∈ mesh, modesCount,
  Method -> {"Eigensystem" -> {"Arnoldi", "MaxIterations" -> 5000}}
];

energies = N[vals, 8];
Export["eigs.json", energies, "JSON"];

upper = Min[modesCount, 6];
Do[
  Export[
    StringTemplate["`1``2`.png"][prefix, k],
    DensityPlot[Evaluate[funs[[k]][x, y]], {x, -1.5, 1.5}, {y, -1, 1},
      PlotRange -> All,
      ColorFunction -> "SunsetColors",
      FrameLabel -> {"x", "y"}
    ]
  ],
  {k, 1, upper}
];

Print["Computed ", Length[energies], " eigenvalues; saved eigs.json and ", upper, " mode plots."];
