#!/usr/bin/env wolframscript
(* qho_eigs.wls: approximate the first N eigenvalues of the 1D harmonic oscillator using FEM. *)

(* no explicit FEM mesh needed for 1D interval domain *)

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
   "n" -> <|"Default" -> 6, "Parser" -> ToExpression|>,
   "L" -> <|"Default" -> 8., "Parser" -> ToExpression|>,
   "m" -> <|"Default" -> 1., "Parser" -> ToExpression|>,
   "omega" -> <|"Default" -> 1., "Parser" -> ToExpression|>,
   "out" -> <|"Default" -> "qho_energies.json"|>
   |>;

params = parseArgs[spec];
{n, L, m, ω, outfile} = Lookup[params, {"n", "L", "m", "omega", "out"}];

V[x_] := 1/2 m ω^2 x^2;

{vals, funcs} = NDEigensystem[
  {
    -(1/(2 m)) D[u[x], {x, 2}] + V[x] u[x],
    DirichletCondition[u[x] == 0, x == -L || x == L]
  },
  u[x], {x, -L, L}, n,
  Method -> {"Eigensystem" -> {"Arnoldi", "MaxIterations" -> 10000}}
];

energies = N[vals, 12];
Export[outfile, energies, "JSON"];

preview = Take[energies, UpTo[6]];
Print["wrote ", outfile];
Print["Energies preview: ", preview // InputForm];
