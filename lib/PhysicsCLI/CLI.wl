baseDir = DirectoryName[$InputFileName];
If[baseDir =!= $Failed && baseDir =!= Null,
  If[!MemberQ[$Path, baseDir], AppendTo[$Path, baseDir]];
  parentDir = FileNameJoin[{baseDir, ".."}];
  If[DirectoryQ[parentDir] && !MemberQ[$Path, parentDir], AppendTo[$Path, parentDir]];
];

BeginPackage["PhysicsCLI`CLI`", {"PhysicsCLI`Utils`", "PhysicsCLI`Analysis`", "PhysicsCLI`Classical`", "PhysicsCLI`Quantum`"}];

RunFromCommandLine::usage = "RunFromCommandLine[] dispatches based on $ScriptCommandLine.";
RunTask::usage = "RunTask[taskName, args] executes a registered task using parsed options association.";
TaskCatalog::usage = "TaskCatalog[] returns the registry of available tasks.";

Begin["`Private`"];

taskRegistry := Merge[
   {
    AnalysisTaskSpecifications[],
    ClassicalTaskSpecifications[],
    QuantumTaskSpecifications[]
   },
   First
  ];

validOutputFormats = <|"json" -> "json", "text" -> "text"|>;

extractOption[key_, args_List] :=
 Module[{remaining = {}, value = Missing["NotFound"], lower},
  Do[
   Which[
    StringMatchQ[arg, "--" <> key <> "=" ~~ ___],
    value = Last@StringSplit[StringDrop[arg, 2], "=", 2];
    ,
    StringMatchQ[arg, "--" <> key],
    value = "true";
    ,
    True,
    AppendTo[remaining, arg]
   ],
   {arg, args}
  ];
  {value, remaining}
 ];

TaskCatalog[] := taskRegistry;

formatWarnings[list_List] := Scan[EmitError, list];

RunTask[taskName_String, options_Association] :=
 Module[{registry = TaskCatalog[], task, handler, result},
  If[!KeyExistsQ[registry, taskName],
   EmitError["Unknown task: " <> taskName];
   Return[$Failed];
  ];
  task = registry[taskName];
  handler = task["Handler"];
  result = handler[options];
  result
 ];

renderResult[result_, outputFormat_] :=
 Switch[outputFormat,
  "json", EmitJSON[result],
  "text", EmitText[result],
  _, EmitError["Unsupported output format: " <> outputFormat]
 ];

RunFromCommandLine[] :=
 Module[{args = Rest@$ScriptCommandLine, taskName, outputFmt, remaining, parseResult, taskSpec, result, catalog},
  {taskName, remaining} = extractOption["task", args];
  If[TrueQ[MissingQ[taskName]] || taskName === Missing["NotFound"],
   EmitError["Missing required --task option. Available tasks: " <> StringRiffle[Keys[TaskCatalog[]], ", "]];
   Exit[1];
  ];
  {outputFmt, remaining} = extractOption["output", remaining];
  If[TrueQ[MissingQ[outputFmt]] || outputFmt === Missing["NotFound"], outputFmt = "json"];
  outputFmt = ToLowerCase[StringTrim[outputFmt]];
  If[!KeyExistsQ[validOutputFormats, outputFmt],
   EmitError["Unsupported output format: " <> outputFmt <> ". Choose from json,text."];
   Exit[1];
  ];
  catalog = TaskCatalog[];
  If[taskName === "list",
   renderResult[
    <|
      "Tasks" -> KeyValueMap[
        Function[{key, value},
         <|
           "Name" -> key,
           "Description" -> value["Description"],
           "Options" -> KeyValueMap[
             Function[{opt, cfg},
              <|
                "Type" -> cfg["Type"],
                "Default" -> Lookup[cfg, "Default", Missing["NotProvided"]],
                "Required" -> Lookup[cfg, "Required", False]
              |>
             ],
             value["Spec"]
            ]
         |>
        ],
        catalog
       ]
    |>,
    outputFmt
   ];
   Exit[0];
  ];
  taskSpec = TaskCatalog[][taskName];
  parseResult = ParseOptions[taskSpec["Spec"], remaining];
  If[Length[parseResult["Warnings"]] > 0, formatWarnings[parseResult["Warnings"]]];
  If[Length[parseResult["Errors"]] > 0,
   formatWarnings[parseResult["Errors"]];
   Exit[1];
  ];
  result = RunTask[taskName, parseResult["Options"]];
  If[result === $Failed,
   Exit[1];
  ];
  renderResult[result, outputFmt]
 ];

End[];
EndPackage[];
