#!/usr/bin/env wolframscript
(* damped_oscillator.wls: forced damped oscillator solution exported to CSV. *)

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
   "gamma" -> <|"Default" -> 0.1, "Parser" -> ToExpression|>,
   "omega0" -> <|"Default" -> 1., "Parser" -> ToExpression|>,
   "F" -> <|"Default" -> 1., "Parser" -> ToExpression|>,
   "Omega" -> <|"Default" -> 1., "Parser" -> ToExpression|>,
   "tmax" -> <|"Default" -> 50., "Parser" -> ToExpression|>,
   "out" -> <|"Default" -> "x.csv"|>
   |>;

params = parseArgs[spec];
{γ, ω0, Fdrv, Ωdrive, tmax, outfile} = Lookup[params, {"gamma", "omega0", "F", "Omega", "tmax", "out"}];

sol = NDSolveValue[
  {
    x''[t] + 2 γ x'[t] + ω0^2 x[t] == Fdrv Cos[Ωdrive t],
    x[0] == 0,
    x'[0] == 0
  },
  x, {t, 0, tmax},
  Method -> {"EquationSimplification" -> "Residual"}
];

samples = Table[{τ, sol[τ]}, {τ, 0., tmax, tmax/2000.}];
Export[outfile, samples, "CSV"];
Print["wrote ", outfile];
