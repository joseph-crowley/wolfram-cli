#!/usr/bin/env wolframscript
(* clebsch_gordan_table.wls: produce nonzero Clebsch-Gordan coefficients for given j1, j2, total J. *)

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
   "j1" -> <|"Default" -> 1/2, "Parser" -> ToExpression|>,
   "j2" -> <|"Default" -> 1/2, "Parser" -> ToExpression|>,
   "J" -> <|"Default" -> 1., "Parser" -> ToExpression|>
   |>;

params = parseArgs[spec];
{j1, j2, Jtot} = Lookup[params, {"j1", "j2", "J"}];

coeffs = Flatten[
  Table[
    Module[{cg = Quiet @ Check[ClebschGordan[{j1, m1}, {j2, m2}, {Jtot, m}], Indeterminate]},
      If[NumericQ[cg] && cg =!= 0,
        <|"m1" -> m1, "m2" -> m2, "m" -> m, "Coefficient" -> N[cg]|>,
        Nothing
      ]
    ],
    {m1, -j1, j1, 1},
    {m2, -j2, j2, 1},
    {m, -Jtot, Jtot, 1}
  ],
  2
];

payload = <|"j1" -> j1, "j2" -> j2, "J" -> Jtot, "terms" -> coeffs|>;
Print @ ExportString[payload, "JSON"];
