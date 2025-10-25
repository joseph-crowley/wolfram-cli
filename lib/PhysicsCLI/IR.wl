baseDir = DirectoryName[$InputFileName];
If[baseDir =!= $Failed && baseDir =!= Null,
  If[!MemberQ[$Path, baseDir], AppendTo[$Path, baseDir]];
  parentDir = FileNameJoin[{baseDir, ".."}];
  If[DirectoryQ[parentDir] && !MemberQ[$Path, parentDir], AppendTo[$Path, parentDir]];
];

BeginPackage["PhysicsCLI`IR`", {"PhysicsCLI`Utils`"}];

(* Public API *)
SchemeTypes::usage = "SchemeTypes[] returns the canonical IR scheme names.";
CanonicalizeScheme::usage = "CanonicalizeScheme[spec] normalizes a scheme spec association and validates required fields.";
ValidateScheme::usage = "ValidateScheme[spec] returns <|\"Valid\"->bool,\"Message\"->str,\"Canonical\"->assoc|>.";
CanonicalizeSchemeList::usage = "CanonicalizeSchemeList[list] maps CanonicalizeScheme over a list and filters invalid entries.";
IntegrationIntervalsForScheme::usage = "IntegrationIntervalsForScheme[scheme, opts] returns integration intervals for heavy contribution.";
CountertermForScheme::usage = "CountertermForScheme[scheme, prefactor, opts] returns the massless counterterm contribution.";

Begin["`Private`"];

toAssoc[spec_Association] := spec;
toAssoc[rules_List] /; MatchQ[rules, {_Rule ..}] := Association[rules];
toAssoc[_] := <||>;

canonicalName[name_String] := Module[{s = ToLowerCase[StringTrim[name]]},
  Which[
    s === "analytic", "analytic",
    s === "cutoff", "cutoff",
    s === "exclude_below" || s === "excludebelow", "exclude_below",
    s === "band_gap" || s === "bandgap", "band_gap",
    s === "band_average" || s === "bandaverage", "band_average",
    s === "principal_value" || s === "principalvalue" || s === "pv", "principal_value",
    True, "unsupported"
  ]
];

SchemeTypes[] := {"analytic", "cutoff", "exclude_below", "band_gap", "principal_value", "band_average"};

requiredKeys["analytic"] := {};
requiredKeys["principal_value"] := {};
requiredKeys["cutoff"] := {"sCut"};
requiredKeys["exclude_below"] := {"sMin"};
requiredKeys["band_gap"] := {"sMin", "sMax"};
requiredKeys["band_average"] := {"bands"};
requiredKeys[_] := {};

numericPositiveQ[x_] := NumericQ[x] && x > 0;

(* Default option fillers per scheme. Keep minimal in Phase 0. *)
fillDefaults["analytic", spec_] := spec;
fillDefaults["principal_value", spec_] := spec; (* width optional later phases *)
fillDefaults["cutoff", spec_] := spec;
fillDefaults["exclude_below", spec_] := spec;
fillDefaults["band_gap", spec_] := spec;
fillDefaults[_, spec_] := spec;

validateFields[name_, spec_Association] := Module[{ok = True, msg = "OK"},
  Switch[name,
    "analytic", Null,
    "principal_value", Null,
    "cutoff",
      If[!KeyExistsQ[spec, "sCut"] || !numericPositiveQ[spec["sCut"]],
        ok = False; msg = "cutoff requires positive sCut";
      ],
    "exclude_below",
      If[!KeyExistsQ[spec, "sMin"] || !numericPositiveQ[spec["sMin"]],
        ok = False; msg = "exclude_below requires positive sMin";
      ],
    "band_gap",
      If[!KeyExistsQ[spec, "sMin"] || !numericPositiveQ[spec["sMin"]] ||
         !KeyExistsQ[spec, "sMax"] || !numericPositiveQ[spec["sMax"]] ||
         !(spec["sMax"] > spec["sMin"]),
        ok = False; msg = "band_gap requires sMin>0, sMax>0, and sMax>sMin";
      ],
    "band_average",
      Module[{bands = Lookup[spec, "bands", Missing["Invalid"]]},
        If[!ListQ[bands] || !AllTrue[bands, MatchQ[#, {_?NumericQ, _?NumericQ}] &],
          ok = False; msg = "band_average requires bands as list of {sMin,sMax}";
        ];
      ],
    _,
      ok = False; msg = "unsupported scheme"
  ];
  <|"Valid" -> ok, "Message" -> msg|>
];

CanonicalizeScheme[input_] := Module[{assoc = toAssoc[input], name, spec, check},
  name = canonicalName[ToString[Lookup[assoc, "scheme", ""]]];
  spec = KeyDrop[assoc, {"scheme"}];
  spec = fillDefaults[name, spec];
  check = validateFields[name, spec];
  If[TrueQ[check["Valid"]],
    <|"Valid" -> True, "Message" -> "OK", "Canonical" -> Append[spec, "scheme" -> name]|>,
    <|"Valid" -> False, "Message" -> check["Message"], "Canonical" -> <||>|>
  ]
];

ValidateScheme[input_] := CanonicalizeScheme[input];

CanonicalizeSchemeList[list_List] := Module[{results, valids},
  results = CanonicalizeScheme /@ list;
  valids = Select[results, TrueQ[#"Valid"] &];
  <|
    "All" -> results,
    "Valid" -> Lookup[#, "Canonical"] & /@ valids,
    "Invalid" -> Select[results, !TrueQ[#"Valid"] &]
  |>
];

(* Intervals are defined relative to a heavy-threshold and optional cap. *)
IntegrationIntervalsForScheme[spec_Association, opts_Association] := Module[
  {scheme = Lookup[spec, "scheme", "unsupported"], threshold, upper, sMin, sMax},
  threshold = N[Lookup[opts, "heavyThreshold", 0.]];
  upper = Lookup[opts, "integrationMax", Infinity];
  Switch[scheme,
    "analytic" | "principal_value" | "cutoff",
      {{threshold, upper}},
    "exclude_below",
      sMin = N[Lookup[spec, "sMin", threshold]];
      {{Max[threshold, sMin], upper}},
    "band_gap",
      sMin = N[Lookup[spec, "sMin", threshold]];
      sMax = N[Lookup[spec, "sMax", upper]];
      If[sMax <= threshold, {{threshold, upper}},
        If[sMin <= threshold,
          {{threshold, sMax}, {Max[sMax, threshold], upper}},
          {{threshold, sMin}, {sMax, upper}}
        ]
      ],
    "band_average",
      Module[{bands = Lookup[spec, "bands", {}], segs},
        segs = Table[
          {Max[threshold, N[b[[1]]]], Min[upper, N[b[[2]]]]},
          {b, bands}
        ];
        Select[segs, #[[2]] > #[[1]] &]
      ],
    _,
      Missing["InvalidScheme", "Unsupported scheme."]
  ]
];

CountertermForScheme[spec_Association, prefactor_, opts_Association] := Module[
  {scheme = Lookup[spec, "scheme", "unsupported"], pole},
  pole = N[Lookup[opts, "poleStrength", 0.]];
  Which[
    !NumericQ[prefactor], Missing["Unsupported"],
    scheme === "cutoff",
      Module[{sCut = N[Lookup[spec, "sCut", Missing["Invalid"]]]},
        If[!NumericQ[sCut] || sCut <= 0,
          Missing["InvalidScheme", "Positive sCut required for cutoff."],
          prefactor*pole/(3.*sCut^3)
        ]
      ],
    scheme === "analytic" || scheme === "principal_value",
      0.,
    True,
      0.
  ]
];

End[];
EndPackage[];
