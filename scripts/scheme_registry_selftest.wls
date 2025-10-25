#!/usr/bin/env wolframscript
(*
  Scheme registry self-test harness.
  Parses and validates a mixed corpus of scheme specs across all types.
  Emits ASCII JSON summary. Guards are enforced externally by caller.
*)

SetDirectory[DirectoryName[$InputFileName]];
(* Load IR package via relative path to repo root. *)
Get[FileNameJoin[{"..", "lib", "PhysicsCLI", "IR.wl"}]];

ClearAll[validCorpus, invalidCorpus];

validCorpus = {
  <|"scheme" -> "analytic"|>,
  <|"scheme" -> "cutoff", "sCut" -> 0.2|>,
  <|"scheme" -> "excludeBelow", "sMin" -> 1.9|>,
  <|"scheme" -> "bandGap", "sMin" -> 2.2, "sMax" -> 3.1|>,
  <|"scheme" -> "principal_value"|>,
  <|"scheme" -> "bandAverage", "bands" -> {{1.8, 2.2}, {2.6, 3.0}}|>,
  {"scheme" -> "cutoff", "sCut" -> 0.1},
  <|"scheme" -> "Exclude_Below", "sMin" -> 2.0|>,
  <|"scheme" -> "BANDGAP", "sMin" -> 2.4, "sMax" -> 2.8|>
};

invalidCorpus = {
  <|"scheme" -> "cutoff"|>,
  <|"scheme" -> "cutoff", "sCut" -> -0.1|>,
  <|"scheme" -> "exclude_below"|>,
  <|"scheme" -> "band_gap", "sMin" -> 2.5|>,
  <|"scheme" -> "band_gap", "sMin" -> 3.0, "sMax" -> 2.0|>,
  <|"scheme" -> "unknown"|>
};

ClearAll[run];
run[] := Module[{valRes, invalRes, okNames},
  valRes = PhysicsCLI`IR`CanonicalizeScheme /@ validCorpus;
  invalRes = PhysicsCLI`IR`CanonicalizeScheme /@ invalidCorpus;
  okNames = Union[PhysicsCLI`IR`SchemeTypes[]];
  Print[ExportString[
    <|
      "status" -> "ok",
      "types" -> okNames,
      "validCount" -> Count[valRes, _?(TrueQ[#["Valid"]] &)],
      "invalidCount" -> Count[invalRes, _?(Not[TrueQ[#["Valid"]]] &)],
      "validFailures" -> Select[valRes, Not[TrueQ[#["Valid"]]] &],
      "invalidPasses" -> Select[invalRes, TrueQ[#["Valid"]] &]
    |>,
    "JSON", "Compact" -> True
  ]];
];

run[];
