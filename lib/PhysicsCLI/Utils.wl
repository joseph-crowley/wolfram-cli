baseDir = DirectoryName[$InputFileName];
If[baseDir =!= $Failed && baseDir =!= Null,
  If[!MemberQ[$Path, baseDir], AppendTo[$Path, baseDir]];
  parentDir = FileNameJoin[{baseDir, ".."}];
  If[DirectoryQ[parentDir] && !MemberQ[$Path, parentDir], AppendTo[$Path, parentDir]];
];

BeginPackage["PhysicsCLI`Utils`"];

ParseOptions::usage = "ParseOptions[spec, args] validates CLI --key=value arguments and returns <|\"Options\"->Association,\"Errors\"->list,\"Warnings\"->list|>.";
EmitJSON::usage = "EmitJSON[data] prints a JSON string with deterministic formatting.";
EmitText::usage = "EmitText[str] prints a plain ASCII line to $Output.";
EmitError::usage = "EmitError[str] prints a plain ASCII line to the error stream.";
NumericStringQ::usage = "NumericStringQ[str] returns True when the string encodes a numeric literal under the restricted grammar.";
RealVectorStringQ::usage = "RealVectorStringQ[str] checks whether the string is a JSON array of real numbers.";
WithTimingPayload::usage = "WithTimingPayload[label, expr] evaluates expr and returns <|\"Label\"->label,\"Seconds\"->Real,\"Result\"->result|>.";

Begin["`Private`"];

realPattern = RegularExpression["^[+-]?(?:\\d+\\.?\\d*|\\d*\\.?\\d+)(?:[eE][+-]?\\d+)?$"];
rationalPattern = RegularExpression["^[+-]?\\d+\\/[+-]?\\d+$"];
integerPattern = RegularExpression["^[+-]?\\d+$"];
trueSet = {"true", "1", "yes", "on"};
falseSet = {"false", "0", "no", "off"};

errorStream[] := If[ValueQ[$StandardError], $StandardError, $Output];

safeToNumber[str_] :=
 Module[{trim = StringTrim[str]},
  Which[
   StringMatchQ[trim, realPattern], ToExpression[trim],
   StringMatchQ[trim, rationalPattern], Quiet@Check[ToExpression[trim], $Failed],
   True, $Failed
  ]
 ];

safeToInteger[str_] :=
 Module[{trim = StringTrim[str]},
  If[StringMatchQ[trim, integerPattern],
   Quiet@Check[ToExpression[trim], $Failed],
   $Failed
  ]
 ];

safeToRealVector[str_] :=
 Module[{parsed},
  parsed = Quiet@Check[ImportString[str, "JSON"], $Failed];
  If[MatchQ[parsed, {_?NumericQ ..}],
   N[parsed],
   $Failed
  ]
 ];

NumericStringQ[str_String] :=
 Or[StringMatchQ[StringTrim[str], realPattern], StringMatchQ[StringTrim[str], rationalPattern]];
NumericStringQ[_] := False;

RealVectorStringQ[str_String] := MatchQ[safeToRealVector[str], {_?NumericQ ..}];
RealVectorStringQ[_] := False;

normalizeSpec[spec_Association] :=
 AssociationMap[
   Function[key,
    Merge[{<|"Type" -> "String", "Default" -> Missing["NotProvided"], "Required" -> False|>, spec[key]},
     First
    ]
   ],
   Keys[spec]
 ];

parseValue[type_, raw_] :=
 Module[{trim = StringTrim[raw], lower = ToLowerCase[StringTrim[raw]]},
  Switch[type,
   "Real",
   safeToNumber[trim],
   "PositiveReal",
   With[{val = safeToNumber[trim]},
    If[val === $Failed || !(NumericQ[val] && val > 0), $Failed, N[val]]
   ],
   "Integer",
   safeToInteger[trim],
   "PositiveInteger",
   With[{val = safeToInteger[trim]},
    If[val === $Failed || !(IntegerQ[val] && val > 0), $Failed, val]
   ],
   "Boolean",
   Which[
    MemberQ[trueSet, lower], True,
    MemberQ[falseSet, lower], False,
    True, $Failed
   ],
   "RealVector",
   safeToRealVector[trim],
   "String",
   trim,
   _,
   $Failed
  ]
 ];

validateBounds[value_, spec_] :=
 Module[{min = Lookup[spec, "Min", None], max = Lookup[spec, "Max", None]},
  Which[
   value === $Failed, $Failed,
   min =!= None && NumberQ[min] && NumericQ[value] && value < min, $Failed,
   max =!= None && NumberQ[max] && NumericQ[value] && value > max, $Failed,
   True, value
  ]
 ];

ParseOptions[rawSpec_Association, args_List] :=
 Module[{spec = normalizeSpec[rawSpec], defaults, options, errors = {}, warnings = {}, seen = <||>},
  defaults = AssociationMap[spec[#]["Default"] &, Keys[spec]];
  options = defaults;
  Do[
   Which[
    StringMatchQ[arg, "--" ~~ ___ ~~ "=" ~~ ___],
    With[{splits = StringSplit[StringDrop[arg, 2], "=", 2]},
     If[Length[splits] == 2,
      With[{key = First[splits], value = Last[splits]},
       If[KeyExistsQ[spec, key],
        Module[{parsed = parseValue[spec[key]["Type"], value], bounded},
         bounded = validateBounds[parsed, spec[key]];
         If[bounded === $Failed,
          AppendTo[errors, "Invalid value for --" <> key <> ": " <> value],
          options[key] = bounded;
          seen[key] = True;
         ]
        ],
        AppendTo[warnings, "Ignoring unknown option --" <> key]
       ]
      ],
      AppendTo[errors, "Malformed argument " <> arg]
     ]
    ],
    StringMatchQ[arg, "--" ~~ ___],
    With[{key = StringDrop[arg, 2]},
     If[KeyExistsQ[spec, key],
      If[spec[key]["Type"] === "Boolean",
       options[key] = True;
       seen[key] = True,
       AppendTo[errors, "Option --" <> key <> " requires --" <> key <> "=value form"]
      ],
      AppendTo[warnings, "Ignoring unknown option --" <> key]
     ]
    ],
    True,
    AppendTo[warnings, "Ignoring positional argument " <> arg]
   ],
   {arg, args}
  ];
  KeyValueMap[
   Function[{key, cfg},
    If[TrueQ[cfg["Required"]] && !TrueQ[seen[key]],
     AppendTo[errors, "Missing required option --" <> key]
    ]
   ],
   spec
  ];
  <|"Options" -> options, "Errors" -> errors, "Warnings" -> warnings|>
 ];

EmitJSON[data_] :=
 Module[{json = Quiet@Check[ExportString[data, "JSON", "Compact" -> True], $Failed]},
  If[json === $Failed,
   EmitError["Failed to encode JSON payload."],
   Print[json]
  ]
 ];

EmitText[str_String] := WriteString[$Output, str <> "\n"];
EmitText[expr_] := EmitText[ToString[expr, InputForm]];

EmitError[str_String] := WriteString[errorStream[], str <> "\n"];
EmitError[expr_] := EmitError[ToString[expr, InputForm]];

WithTimingPayload[label_String, expr_] :=
 Module[{time, result},
  {time, result} = AbsoluteTiming[expr];
  <|"Label" -> label, "Seconds" -> time, "Result" -> result|>
 ];

End[];
EndPackage[];
