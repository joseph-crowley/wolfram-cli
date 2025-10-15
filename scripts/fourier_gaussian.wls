#!/usr/bin/env wolframscript
(* fourier_gaussian.wls: exact Fourier transform of a Gaussian with explicit conventions.
   Outputs either JSON (default) or InputForm for downstream tooling. *)

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
   "mu" -> <|"Default" -> 0., "Parser" -> ToExpression|>,
   "sigma" -> <|"Default" -> 1., "Parser" -> ToExpression|>,
   "params" -> <|"Default" -> "{-1,1}"|>,
   "t" -> <|"Default" -> 0., "Parser" -> ToExpression|>,
   "json" -> <|"Default" -> True, "Flag" -> True, "Parser" -> (Which[# === "true", True, # === "false", False, True, ToExpression[#]] &)|>
   |>;

options = parseArgs[spec];
{μ, σ, paramsSpec, t, emitJSON} = Lookup[options, {"mu", "sigma", "params", "t", "json"}];

fourierParams = Quiet@Check[ToExpression[paramsSpec, StandardForm, Hold], Hold[{-1, 1}]] // ReleaseHold;
If[!MatchQ[fourierParams, {_?NumericQ, _?NumericQ}],
  WriteString[err, "Invalid FourierParameters specification; defaulting to {-1,1}.\n"];
  fourierParams = {-1, 1};
];

expr[x_] := Exp[-(x - μ)^2/(2 σ^2)];
assumptions = σ > 0;
ft = Assuming[assumptions, FourierTransform[expr[x], x, t, FourierParameters -> fourierParams]];
result = Assuming[assumptions, Simplify[ft]];

If[TrueQ[emitJSON],
  resultStr = ToString[result // InputForm, InputForm];
  payload = <|
    "mu" -> μ,
    "sigma" -> σ,
    "frequency" -> t,
    "FourierParameters" -> fourierParams,
    "transform" -> resultStr
  |>;
  Print @ ExportString[payload, "JSON"],
  payload = <|
    "mu" -> μ,
    "sigma" -> σ,
    "frequency" -> t,
    "FourierParameters" -> fourierParams,
    "transform" -> result
  |>;
  Print[payload // InputForm]
];
