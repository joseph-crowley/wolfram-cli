#!/usr/bin/env wolframscript

(* Landau singularity mapper wrapper delegating to the shared PhysicsCLI
   library so command line usage stays aligned with the unified driver. *)

root = DirectoryName[$InputFileName];
If[root === $Failed || root === Null, root = Directory[]];
SetDirectory[root];

repoRoot = FileNameJoin[{root, "..", ".."}];
utilsPath = FileNameJoin[{repoRoot, "lib", "PhysicsCLI", "Utils.wl"}];
analysisPath = FileNameJoin[{repoRoot, "lib", "PhysicsCLI", "Analysis.wl"}];

Get[utilsPath];
Get[analysisPath];

spec = PhysicsCLI`Analysis`AnalysisTaskSpecifications[][
    "landau-mapper"
   ]["Spec"];

args = Rest[$ScriptCommandLine];
parse = PhysicsCLI`Utils`ParseOptions[spec, args];

If[Length[parse["Warnings"]] > 0,
  Scan[PhysicsCLI`Utils`EmitError, parse["Warnings"]]
 ];

If[Length[parse["Errors"]] > 0,
  Print[ExportString[
    <|"status" -> "error", "message" -> First[parse["Errors"]]|>,
    "JSON", "Compact" -> True
  ]];
  Exit[1];
];

result = PhysicsCLI`Analysis`LandauMapper[parse["Options"]];

If[result === $Failed,
  Exit[1];
];

Print[ExportString[result /. Missing[_] :> Null, "JSON", "Compact" -> True]];
