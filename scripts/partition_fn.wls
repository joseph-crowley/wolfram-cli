#!/usr/bin/env wolframscript
(* partition_fn.wls: compute canonical partition function from supplied discrete spectrum. *)

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
   "beta" -> <|"Default" -> 1., "Parser" -> ToExpression|>,
   "in" -> <|"Default" -> "qho_energies.json"|>
   |>;

params = parseArgs[spec];
{β, infile} = Lookup[params, {"beta", "in"}];

energies = Quiet@Check[Import[infile, "JSON"], $Failed];
If[energies === $Failed,
  WriteString[err, "Failed to read spectrum from " <> infile <> "\n"];
  Exit[1];
];

energiesList = N[Flatten[{energies}]];
w = Exp[-β energiesList];
Z = Total[w];
U = Total[energiesList*w]/Z;
Cv = β^2 (Total[energiesList^2*w]/Z - U^2);

payload = <|"beta" -> β, "Z" -> N[Z, 15], "U" -> N[U, 15], "C" -> N[Cv, 15]|>;
Print @ ExportString[payload, "JSON"];
