# wolframscript physics field manual

Last verified: 14 Oct 2025 on macOS with Mathematica installed at `/Applications/Wolfram.app`. The repository includes a runnable `scripts/` toolkit implementing the examples below with consistent `--key=value` flags and machine-readable outputs.

## 0. Why CLI Wolfram for Physics

- reproducibility: scripts live in source control and run on CI without a GUI.
- performance: you can pin threads, launch parallel kernels, and batch jobs on clusters.
- composability: `-code` one-liners or `.wls` programs slot into Make, Python, Rust, or Bash pipelines cleanly.
- coverage: the Wolfram Language has built-ins for calculus, PDEs/ODEs, transforms, special functions, statistics, units, symbolic tensors, and more; community paclets extend to QFT, Lie algebras, and FEM.

---

## 1. Prerequisites and Sanity Checks

Install a desktop kernel (Mathematica) or the free Wolfram Engine. Verify CLI tooling:

```sh
/Applications/Wolfram.app/Contents/MacOS/wolframscript -version
/Applications/Wolfram.app/Contents/MacOS/wolfram -h  # console kernel driver
```

`wolframscript` options are documented at the program reference; `wolfram` exposes the console kernel and `-script` runner.

Put binaries on `PATH` or use full paths:

```sh
export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
which wolframscript || ls /Applications/Wolfram.app/Contents/MacOS
```

Smoke tests:

```sh
wolframscript -code 'N[Zeta[3],50]'
wolframscript -code 'Range[5]^2 // InputForm'
printf 'FactorInteger[2^61-1]\nQuit[]\n' | wolfram -noprompt
wolframscript -code 'Export["bessel.pdf", Plot[BesselJ[0,x], {x,0,30}]]'
```

---

## 2. Shell-Level Execution Patterns

- one-liners: `wolframscript -code 'expr'`. set output format with `// InputForm` or emit JSON via `ExportString[..., "JSON"]`.
- script files: `wolframscript -file script.wls [args...]`. to make a script executable, add a shebang line and `chmod +x`. on Windows, use `.wls`.
- pure kernel stdin: `wolfram -noprompt < file.wl` or pipe expressions, then `Quit[]`.
- argument access: use `$ScriptCommandLine` (drop the program name with `Rest@...`). for raw stdin, use `$ScriptInputString`.
- where code runs: `wolframscript` can target a local kernel (`-local`) or a cloud kernel (`-cloud`). start with local for physics workloads.

---

## 3. Performance and Determinism

- parallel kernels: `LaunchKernels[]`, then `ParallelTable`, `ParallelMap`, etc. fix core count with `SetSystemOptions["ParallelOptions"->"ParallelThreadNumber"->n]`.

- linear algebra threads: many low-level ops use BLAS/LAPACK via Intel MKL. pin threads per process with environment variables before launch, for example

  ```sh
  export MKL_NUM_THREADS=4
  export OMP_NUM_THREADS=4
  wolframscript -file yourscript.wls ...
  ```

  This is the standard MKL control mechanism on Linux/macOS and applies to programs embedding MKL. Wolfram staff confirm environment overrides can influence effective core detection. Tune carefully on clusters to avoid oversubscription.

- reproducibility: set numeric seeds and global assumptions at the top of scripts:

  ```wl
  SeedRandom[1234];
  $Assumptions = Element[{m, ω}, Reals] && m>0 && ω>0;
  ```

- output discipline: for downstream scripts use `ExportString[value,"JSON"]` or `//InputForm`.

---

## 4. Paclets, Function Repository, and Argument Parsing

- install paclets at runtime:

  ```wl
  Needs["PacletManager`"];
  PacletInstall["Wolfram/CommandLineParser"];  (* once per machine *)
  Needs["Wolfram`CommandLineParser`"];
  ```

  `PacletInstall` installs by name, URL, or file; use options like `PacletSite` for custom indexes.
- use the `CommandLineParser` paclet for robust flags and help text in `.wls` programs.
- use the Wolfram Function Repository to add missing pieces, for example `NInverseFourierTransform` or FEM helper utilities. install with `ResourceFunction` on demand.
- physics paclets and packages you will typically load:

  - FeynCalc for Dirac and color algebra, traces, perturbation scaffolding. install via its bootstrapper.
  - FeynArts for diagram generation; FormCalc for amplitude code generation.
  - Package-X for analytic one-loop integrals.
  - FeynRules and SARAH for model Lagrangians and UFO export.
  - xAct (xTensor, xPerm, etc.) for GR and differential geometry.
  - FEMAddons for extra meshing and FEM tools.

---

## 5. Core Mathematical Methods You Will Call from CLI

### Transforms, Residues, Asymptotics

- Fourier and Laplace transforms: `FourierTransform`, `InverseFourierTransform`; `FourierParameters` must be set explicitly to match physics conventions. use `Assuming[...]` to control branch conditions.
- residue calculus for contour integrals: `Residue[f, {z,z0}]`. couple with `Series` and `SeriesCoefficient` for expansions.
- asymptotics at large parameters or near singularities: `AsymptoticIntegrate`, `AsymptoticSolve`, `AsymptoticProduct`, and related guide pages.

### PDEs, ODEs, FEM, Eigenproblems

- `NDSolveValue` with FEM over `ImplicitRegion` and meshes from `ToElementMesh`. for eigenmodes, use `NDEigensystem` or `DEigensystem`.

### Angular Momentum and Harmonic Analysis

- `SphericalHarmonicY`, `ClebschGordan`, `ThreeJSymbol`, `SixJSymbol` for coupled spins and partial-wave technology.

### Tensors and Index Gymnastics

- built-in symbolic tensor stack: `TensorProduct`, `TensorContract`, `TensorTranspose`, `TensorReduce`, `LeviCivitaTensor`. use `xAct` for full relativity workloads.

### Units and Dimensional Analysis

- represent and convert physical quantities with `Quantity`, `UnitConvert`, and `QuantityVariable`. these interoperate with solvers and plotting in headless mode.

---

## 6. Curated CLI Scripts by Course and Task

Each script is a complete, runnable `.wls`. For every script:

- inputs are parsed with `Wolfram/CommandLineParser` or `$ScriptCommandLine`.
- all outputs are either `Print[...]` text or `Export[...,...]` files for downstream tools.
- a one-line validation follows each file.

> Use the ready-made scripts in `scripts/`. All flags are `--key=value`.

### 6.1 Mathematical Methods for Physicists

#### 6.1.1 Fourier Transform Sanity – Gaussian

```wl
#!/usr/bin/env wolframscript
(* fourier_gaussian.wls: exact transform with explicit conventions and json output *)
Needs["Wolfram`CommandLineParser`"];
parse = CommandLineParser[
  <|
    "μ" -> <|"Type"->"Real", "Default"->0.|>,
    "σ" -> <|"Type"->"Real", "Default"->1.|>,
    "params" -> <|"Type"->"String", "Default"->"{-1,1}"|>,   (* physics-friendly default *)
    "t" -> <|"Type"->"Real", "Default"->0.|>,
    "json" -> <|"Type"->"Boolean", "Default"->True|>
  |>,
  "Help"->"Compute FT of exp(-(x-μ)^2/(2σ^2)) at frequency t with FourierParameters."
];
args = parse[$ScriptCommandLine];
{μ, σ, params, t, json} = args /@ {"μ","σ","params","t","json"};
fp = ToExpression[params];

expr[x_] := Exp[-(x-μ)^2/(2 σ^2)];
ft = Assuming[σ>0, FourierTransform[expr[x], x, t, FourierParameters->fp]];
val = Assuming[σ>0, ft // Simplify];

out = <|"μ"->μ, "σ"->σ, "t"->t, "FourierParameters"->fp, "FT"->val|>;
If[TrueQ[json],
  Print @ ExportString[out, "JSON"],
  Print[out // InputForm]
];
```

Validation (toolkit): `wolframscript -file scripts/fourier_gaussian.wls --mu=0 --sigma=1 --t=0 | jq -r .transform` emits an InputForm string inside JSON. References: transform machinery and parameters.

#### 6.1.2 Complex Analysis – Residue Extraction

```wl
#!/usr/bin/env wolframscript
(* residue_demo.wls: compute residue of f at z0 and return in InputForm *)
f[z_] := (z^2 + 1)/(z - I)^3;
z0 = I;
res = Residue[f[z], {z, z0}];
Print["Residue at z0 = ", z0 // InputForm, " is ", res // InputForm];
```

Validation (toolkit): `wolframscript -file scripts/residue_demo.wls` prints `Residue at z0=I: 1`. Reference: residue.

#### 6.1.3 Asymptotics – Stationary Phase Sketch

```wl
#!/usr/bin/env wolframscript
(* asymptotic_integral.wls: illustrate AsymptoticIntegrate for large λ *)
$Assumptions = λ>0 && a>0;
expr = Cos[λ x^2] Exp[-a x^2];
asym = AsymptoticIntegrate[expr, {x,-Infinity,Infinity}, λ -> Infinity, SeriesTermGoal->2];
Print[asym // InputForm];
```

Validation (toolkit): `wolframscript -file scripts/asymptotic_integral.wls` prints a two-term asymptotic series. Reference: asymptotic integrate.

---

### 6.2 Classical Mechanics and EM

#### 6.2.1 ODE Flow – Damped Oscillator Response

```wl
#!/usr/bin/env wolframscript
(* damped_oscillator.wls: forced damped oscillator; export response as csv *)
Needs["Wolfram`CommandLineParser`"];
opts = CommandLineParser[
  <|
    "γ"-><|"Type"->"Real","Default"->0.1|>, "ω0"-><|"Type"->"Real","Default"->1.|>,
    "F"-><|"Type"->"Real","Default"->1.|>,  "Ω"-><|"Type"->"Real","Default"->1.|>,
    "tmax"-><|"Type"->"Real","Default"->50.|>, "out"-><|"Type"->"String","Default"->"x.csv"|>
  |>,
  "Help"->"Solve x''+2γ x'+ω0^2 x = F cos(Ω t) with x(0)=0, x'(0)=0."
];
a = opts[$ScriptCommandLine];
{γ, ω0, F0, Ω, tmax, out} = a /@ {"γ","ω0","F","Ω","tmax","out"};

x = x[t];
sol = NDSolveValue[
  {x'' + 2 γ x' + ω0^2 x == F0 Cos[Ω t], x[0]==0, x'[0]==0},
  x, {t,0,tmax}
];

data = Table[{t, sol[t]}, {t,0., tmax, tmax/2000.}];
Export[out, data, "CSV"];
Print["wrote ", out];
```

Validation (toolkit): `wolframscript -file scripts/damped_oscillator.wls --gamma=0.1 --omega0=1 --F=1 --Omega=1 --tmax=50 --out=resp.csv` writes `resp.csv`. Reference: `NDSolveValue`.

#### 6.2.2 Helmholtz on a Square – FEM PDE

```wl
#!/usr/bin/env wolframscript
(* helmholtz_square.wls: 2d Helmholtz with Dirichlet boundary on unit square *)
Needs["NDSolve`FEM`"];
Ω = ImplicitRegion[0 <= x <= 1 && 0 <= y <= 1, {x,y}];
mesh = ToElementMesh[Ω, MaxCellMeasure->1/300];
ω = 25.; c = 1.; k = ω/c;

u = NDSolveValue[
  {
    Laplacian[u[x,y], {x,y}] + k^2 u[x,y] == 0,
    DirichletCondition[u[x,y]==Sin[Pi y], x==0],
    DirichletCondition[u[x,y]==0, x==1 || y==0 || y==1]
  },
  u, Element[mesh]
];

Export["helmholtz.png",
  DensityPlot[u[x,y], {x,0,1},{y,0,1}, PlotRange->All, ColorFunction->"AvocadoColors"]
];
Print["mesh elements: ", mesh["MeshOrder"], " exported helmholtz.png"];
```

Validation (toolkit): `wolframscript -file scripts/helmholtz_square.wls` produces `helmholtz.png` (requires FEM-enabled license). References: `ImplicitRegion`, `ToElementMesh`, FEM tutorial.

---

### 6.3 Quantum Mechanics

#### 6.3.1 1D Harmonic Oscillator Spectrum by FEM

```wl
#!/usr/bin/env wolframscript
(* qho_eigs.wls: N lowest eigenpairs for 1D QHO via NDEigensystem *)
Needs["NDSolve`FEM`"];
Needs["Wolfram`CommandLineParser`"];

p = CommandLineParser[
  <|"N"-><|"Type"->"Integer","Default"->6|>, "L"-><|"Type"->"Real","Default"->8.|>,
    "m"-><|"Type"->"Real","Default"->1.|>, "ω"-><|"Type"->"Real","Default"->1.|>|>
];
a = p[$ScriptCommandLine]; {N, L, m, ω} = a /@ {"N","L","m","ω"};

Ω = ImplicitRegion[-L <= x <= L, {x}];
mesh = ToElementMesh[Ω, MaxCellMeasure->L/500.];
V[x_] := 0.5 m ω^2 x^2;

{vals, funs} = NDEigensystem[
  {-1/(2 m) D[ψ[x], {x,2}] + V[x] ψ[x], DirichletCondition[ψ[x]==0, x==-L || x==L]},
  ψ[x], {x} ∈ mesh, N, Method->{"Eigensystem"->{"Arnoldi","MaxIterations"->10000}}
];

energies = N[vals, 10];
Export["qho_energies.json", energies, "JSON"];
Print["E[0..", N-1, "] ≈ ", Take[energies, UpTo[6]] // InputForm];
```

Validation (toolkit): `wolframscript -file scripts/qho_eigs.wls --n=6 --L=8 --m=1 --omega=1 --out=qho_energies.json` then `jq . qho_energies.json`. Compare `E_n ~ ω (n + 1/2)` for `m=ω=1`, `L` large enough. Reference: `NDEigensystem`.

#### 6.3.2 Angular Momentum Algebra – Clebsch-Gordan

```wl
#!/usr/bin/env wolframscript
(* clebsch_gordan_table.wls: table for j1,j2 -> J,m combinations *)
Needs["Wolfram`CommandLineParser`"];
p = CommandLineParser[
  <|"j1"-><|"Type"->"Real","Default"->1/2|>, "j2"-><|"Type"->"Real","Default"->1/2|>, "J"-><|"Type"->"Real","Default"->1.|>|>
];
a = p[$ScriptCommandLine]; {j1,j2,J} = a /@ {"j1","j2","J"};

vals = Flatten[Table[
  With[{cg = ClebschGordan[{j1,m1},{j2,m2},{J,m}]},
    If[NumericQ[cg] && cg!=0, <|"m1"->m1,"m2"->m2,"m"->m,"CG"->cg|>, Nothing]
  ],
  {m1, -j1, j1, 1}, {m2, -j2, j2, 1}, {m, -J, J, 1}], 2];

Print @ ExportString[<|"j1"->j1,"j2"->j2,"J"->J,"terms"->vals|>, "JSON"];
```

Validation (toolkit): `wolframscript -file scripts/clebsch_gordan_table.wls --j1=1 --j2=1 --J=2` emits nonzero couplings. References: `ClebschGordan`, `ThreeJSymbol`, selection rules.

---

### 6.4 Statistical Mechanics

#### 6.4.1 Canonical Partition Function for Discrete Spectrum

```wl
#!/usr/bin/env wolframscript
(* partition_fn.wls: Z(β)=∑ e^{-β E_n} from a user-supplied spectrum file *)
Needs["Wolfram`CommandLineParser`"];
p = CommandLineParser[<|"beta"-><|"Type"->"Real","Default"->1.|>, "in"-><|"Type"->"String","Default"->"qho_energies.json"|>|>];
a = p[$ScriptCommandLine]; {β, infile} = a /@ {"beta","in"};

energies = Import[infile, "JSON"] /. List -> List;
Z = Total[Exp[-β energies]];
U = -D[Log[Z], β];
C = D[U, β] β^2;

Print @ ExportString[<|"beta"->β,"Z"->N[Z,15],"U"->N[U,15],"C"->N[C,15]|>, "JSON"];
```

Validation (toolkit): `wolframscript -file scripts/partition_fn.wls --beta=1 --in=qho_energies.json` returns Z, U, C in JSON.

---

### 6.5 Quantum Field Theory

#### 6.5.1 Gamma-Matrix Traces and Contraction with FeynCalc

```wl
#!/usr/bin/env wolframscript
(* dirac_trace.wls: minimal FeynCalc example in cli *)
InstallIfMissing[name_String, install_:Null] := Module[{ff=FindFile[name<>"`"]},
  If[ff===$Failed && install=!=Null, install[]; FindFile[name<>"`"], ff]
];

fcInstall[] := (Import["https://www.feyncalc.org/install.m"]; InstallFeynCalc[]);  (* official bootstrap *)
If[InstallIfMissing["FeynCalc", fcInstall] === $Failed, Print["failed to install FeynCalc"]; Exit[1]];

Needs["FeynCalc`"];
expr = DiracTrace[GA[\[Mu]].GA[\[Nu]]];
res = DiracSimplify[expr];  (* gives 4 g^{μν} in D=4 *)
Print["trace gamma^μ gamma^ν -> ", res // InputForm];
```

Validation: `wolframscript -file dirac_trace.wls` should print a result proportional to `MetricTensor[μ, ν]` with the expected dimension factor; consult `FeynCalc` docs if using D dimensions. References: FeynCalc docs and install method.

> Diagram generation: use FeynArts to generate topologies, amplitudes, and model insertions, then simplify with FeynCalc; FormCalc exports numerical code. See package manuals.

#### 6.5.2 One-Loop Scalar Integrals – Package-X

For analytic one-loop integrals with dimensional regularization, use Package-X (separate install and external prerequisites may apply). Consult the tutorial slides for the operator set and syntax.

---

### 6.6 General Relativity and Differential Geometry

#### 6.6.1 Symbolic Tensors without External Paclets

```wl
#!/usr/bin/env wolframscript
(* levi_civita_check.wls: vector identity using LeviCivitaTensor and TensorReduce *)
Clear[a,b];
id = TensorReduce[
  LeviCivitaTensor[3, {i,j,k}] a[j] b[k],
  TensorReduce`TensorVariables -> {a, b}
];
Print[id // InputForm];  (* equals cross product in index form *)
```

Validation (toolkit): `wolframscript -file scripts/levi_civita_check.wls` prints the cross product components as polynomials in ax[i], bx[i]. References: `LeviCivitaTensor`.

#### 6.6.2 Full GR Stacks

For curvature, spin connections, and tetrads, prefer xAct’s `xTensor` and friends; they bring index types, symmetries, and kernels tailored for relativity. Documentation and references are extensive.

---

### 6.7 PDE Eigenmodes – NDEigensystem for Waveguides and Quantum Billiards

```wl
#!/usr/bin/env wolframscript
(* billiard_eigs.wls: first M eigenmodes in a stadium region *)
Needs["NDSolve`FEM`"]; Needs["Wolfram`CommandLineParser`"];
p = CommandLineParser[<|"m"-><|"Type"->"Integer","Default"->8|>, "h"-><|"Type"->"Real","Default"->0.03|>|>];
a = p[$ScriptCommandLine]; {m,h} = a /@ {"m","h"};

r = RegionUnion[Disk[{-.5,0}, .5], Rectangle[{-0.5, -0.5}, {0.5, 0.5}], Disk[{.5,0}, .5]];
mesh = ToElementMesh[r, MaxCellMeasure->h];
{vals, funs} = NDEigensystem[{-(Laplacian[u[x,y],{x,y}]), DirichletCondition[u[x,y]==0, True]}, u[x,y], {x,y} ∈ mesh, m];
Export["eigs.json", N[vals, 8], "JSON"];
Do[
  Export[ToString@StringTemplate["mode``.png"][k],
    DensityPlot[Evaluate[funs[[k]][x,y]], {x,-1.5,1.5}, {y,-1,1}, PlotRange->All]
  ],
  {k,1,Min[m,6]}
];
Print["wrote eigs.json and first modes as images"];
```

Validation (toolkit): `wolframscript -file scripts/billiard_eigs.wls` writes eigenvalues and a few modes (requires FEM-enabled license). References: `NDEigensystem`.

---

## 7. I/O Patterns That Play Well with Other Tools

- tables and arrays: `Export["file.csv", table, "CSV"]` or `ExportString[..., "JSON"]` for interop.
- raw symbolic output: append `//InputForm` for stable text.
- graphics: `Export["plot.png", expr]` works headless.
- units: prefer `Quantity` and `UnitConvert` to keep dimensions explicit even in CLI runs.

---

## 8. Testing and Continuous Integration

- quick assertions: `VerificationTest[input, expected, SameTest->(Chop[#1-#2,1.*^-8]==0&)]`. in CLI contexts, you can gather tests in a `.wl` and print a summary.
- test notebooks exist, but headless pipelines typically use `VerificationTest` programmatically; see the systematic testing guide.
- pattern:

```wl
#!/usr/bin/env wolframscript
(* smoke_tests.wls: run a few unit tests and exit with code *)
tests = {
  VerificationTest[FourierTransform[Exp[-x^2], x, k, FourierParameters->{-1,1}],
                   Sqrt[Pi] Exp[-k^2/4]],
  VerificationTest[Residue[(z^2+1)/(z-I)^3, {z, I}], 1/(2 I)]
};
fails = Count[tests /. TestResultObject[assoc_] :> assoc["Outcome"], "Failure"];
Print["tests run: ", Length@tests, " failures: ", fails];
Exit[If[fails==0, 0, 1]];
```

Validation: `wolframscript -file smoke_tests.wls` returns exit code 0 on success. References: `VerificationTest`.

---

## 9. Robust CLI Patterns and Failure-Mode Mitigation

- defensive assumptions: set `$Assumptions` and use `Assuming[...]` inside transforms and symbolic simplification to avoid branch and distributional ambiguities.
- kernel lifecycle: for streamed sessions, always send `Quit[]` at the end when piping to the kernel to avoid zombie processes.
- argument parsing: favor the `CommandLineParser` paclet for named flags, defaults, and help. this avoids brittle positional argument handling.
- performance traps: do not oversubscribe cores. if you use Wolfram parallel tools and MKL simultaneously, coordinate `LaunchKernels[]` with `MKL_NUM_THREADS=1..n` to avoid `n_kernels × n_blas_threads` explosions. standard MKL guidance applies.
- FEM meshing: prefer `ToElementMesh` with explicit `MaxCellMeasure`; check diagnostics if meshing fails. the FEM docs cover strategies and error messages.
- conventions: for Fourier, always set `FourierParameters` explicitly; for angular momentum coefficients expect zeroes when triangle rules fail, and handle messages programmatically if needed.

---

## 10. Updated Runbook Essentials

### 10.1 wolframscript Flags You Will Actually Use

- `-code expr`, `-file path`, `-print` to force printing the last value from a file, `-local` vs `-cloud`, `-api` to call deployed cloud APIs, pass trailing args to your script. see the program page for the full option set.

### 10.2 PATH Discovery on macOS

```sh
ls /Applications/Wolfram.app/Contents/MacOS  # expected: wolframscript, WolframKernel, wolfram
```

### 10.3 Common One-Liners

```sh
wolframscript -code 'NSolve[x^5 - x + 1 == 0, x] // InputForm'
wolframscript -code 'UnitConvert[Quantity[1,"eV"],"Joule"]'
```

References: `UnitConvert`, `Quantity`.

---

## 11. Appendix: Minimal Project Layout

```
physics-cli/
  scripts/
    fourier_gaussian.wls
    residue_demo.wls
    damped_oscillator.wls
    helmholtz_square.wls
    qho_eigs.wls
    clebsch_gordan_table.wls
    billiard_eigs.wls
    dirac_trace.wls
    partition_fn.wls
    smoke_tests.wls
  Makefile
```

`Makefile` sketch (also provided in repo):

```make
all: smoke

smoke:
	wolframscript -file scripts/smoke_tests.wls

qho:
	wolframscript -file scripts/qho_eigs.wls --N 8 --L 10 --m 1 --ω 1

helmholtz:
	wolframscript -file scripts/helmholtz_square.wls
```

---

## 12. Frequently Used Documentation Anchors

- wolframscript usage and workflows.
- console kernels: `wolfram`, `-script`.
- `$ScriptCommandLine`, scripting workflow.
- FEM and PDE stack: `NDSolveValue`, `ImplicitRegion`, `ToElementMesh`, `NDEigensystem`.
- Fourier transforms, series, residues, asymptotics.
- units.
- angular momentum symbols.
- symbolic tensors.
- FeynCalc, FeynArts, Package-X, FeynRules, xAct, FEMAddons.
- parallel options.
- MKL threading environment variables (general guidance).

---

## 13. What to Do Next

- wrap these scripts with a few `make` targets per course: transforms, ODE/PDE, QM eigensystems, QFT traces and reductions, GR tensor identities.
- pin threads and core counts per machine. bench with small matrices to ensure you are not oversubscribed.
- add `VerificationTest` paths for the pieces you rely on in talks, papers, or production runs.

Physics is a contact sport with conventions. For any script that touches transforms, distributions, or branch cuts, annotate the exact `FourierParameters`, domains, and assumptions you chose. You can then compute boldly without chasing ghosts.
