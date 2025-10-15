#!/usr/bin/env wolframscript
(* dirac_trace.wls: minimal CLI FeynCalc example computing a Dirac trace. *)

InstallIfMissing[name_String, installer_: Null] :=
  Module[{ff = Quiet@FindFile[name <> "`"]},
    If[ff === $Failed && installer =!= Null,
      installer[];
      Quiet@FindFile[name <> "`"],
      ff
    ]
  ];

fcInstaller[] := Block[{$ContextPath},
  Import["https://www.feyncalc.org/install.m"];
  InstallFeynCalc[];
];

If[InstallIfMissing["FeynCalc", fcInstaller] === $Failed,
  WriteString[err, "FeynCalc is not available and automatic installation failed.\n"];
  Exit[1];
];

Needs["FeynCalc`"];
expr = DiracTrace[GA[\[Mu]].GA[\[Nu]]];
res = DiracSimplify[expr];
Print["DiracTrace[γ^μ γ^ν] -> ", res // InputForm];
