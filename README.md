# MAUTOLAB

MAUTOLAB is a MATLAB toolkit for reading and working with output files produced by AUTO-07p.

The goal is to provide a clean, structured, and MATLAB-native interface for AUTO output files:

* `b.*` — bifurcation diagrams  
* `d.*` — diagnostics (eigenvalues / multipliers)  
* `s.*` — solutions  

Tested in **MATLAB R2025a**.

---

## Repository structure

```
MAUTOLAB/
│
├── MAUTOLAB.m          % unified reader
├── MAUTOLAB_app.m      % unified GUI launcher
│
├── b_files/
│   ├── read_b_auto.m
│   ├── parse_header_lines.m
│   ├── plotbd.m
│   ├── showbdvars.m
│   └── plotbd_app.m
│
├── d_files/
│   ├── read_d_auto.m
│   ├── read_d_blocks.m
│   ├── read_d_table.m
│   ├── d_summary.m
│   ├── d_plot_spectrum.m
│   ├── plot_complex_slider.m
│   ├── get_multipliers.m
│   └── d_plot_app.m
│
├── s_files/
│   ├── read_s_auto.m
│   ├── plot_s_auto.m
│   ├── show_s_vars.m
│   └── plot_s_app.m
│
└── docs/
```

---

# Unified interface

## MAUTOLAB

```matlab
data = MAUTOLAB('lor');
```

Attempts to read:

```
b.lor   → bifurcation diagram
d.lor   → diagnostics
s.lor   → solutions
```

Only existing files are loaded. Missing files are skipped with warnings.

### Output structure

```matlab
data.bif_diagram
data.diagnostics
data.solutions
```

---

## MAUTOLAB_app

```matlab
MAUTOLAB_app
```

Features:

* Load data from a base filename
* Automatically detect available files
* Enable/disable plotting tools accordingly
* Launch specialised apps:
  * bifurcation diagrams
  * solutions
  * diagnostics

---

# Bifurcation diagram files (`b.*`)

## read_b_auto

Reads an AUTO `b.*` file and returns a struct array, one entry per branch.

Each branch contains:

* `branch_number`
* `data` (MATLAB table)
* `header`

---

## plotbd

```matlab
plotbd(branches)
plotbd(branches, 'x', 4, 'y', 5)
plotbd(branches, 'x', 'PAR_1', 'y', 'L2_NORM')
plotbd(branches, 'x', 4, 'y', 5, 'z', 6)
```

---

## plotbd_app

```matlab
plotbd_app(branches)
```

---

# Diagnostics files (`d.*`)

## Workflow

```
read_d_auto → read_d_blocks → read_d_table → plotting
```

---

## d_summary

```matlab
d_summary(diag)
```

---

## d_plot_spectrum

```matlab
d_plot_spectrum(diag)
```

---

## plot_complex_slider

```matlab
plot_complex_slider(diag)
```

---

## d_plot_app

```matlab
d_plot_app(diag)
```

---

# Solution files (`s.*`)

## read_s_auto

Returns a cell array of solutions.

Each solution contains:

* `t`
* `U`
* identifiers (`LAB`, `IBR`, `PT`)
* metadata

---

## plot_s_auto

```matlab
plot_s_auto(sols, 1, {'t','U1'});
plot_s_auto(sols, 1, {'U1','U2','U3'});
```

---

## show_s_vars

```matlab
show_s_vars(sols, 1)
```

---

## plot_s_app

```matlab
plot_s_app(sols)
```

---

# Basic usage

```matlab
data = MAUTOLAB('lor');

branches = read_b_auto("b.lor");
plotbd(branches);

diag = read_d_auto("d.lor");
d_plot_app(diag);

sols = read_s_auto("s.lor");
plot_s_app(sols);
```

---

# Notes

* Eigenvalues: stability via Re(λ)
* Multipliers: stability via |μ|
* One multiplier must satisfy μ = 1

---

# Future work

* automatic bifurcation detection
* tighter integration
* unified plotting interface
