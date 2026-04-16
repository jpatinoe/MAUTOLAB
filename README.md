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

# Bifurcation diagram files (`b.*`)

## read_b_auto

Reads an AUTO `b.*` file and returns a struct array, one entry per branch.

Each branch contains:

* `branch_number`
* `data` (MATLAB table)
* `header` (parsed metadata)

---

## plotbd

Main plotting function for bifurcation diagrams.

```matlab
plotbd(branches)
plotbd(branches, 'x', 4, 'y', 5)
plotbd(branches, 'x', 'PAR_1', 'y', 'L2_NORM')
plotbd(branches, 'x', 4, 'y', 5, 'z', 6)
```

---

## plotbd_app

Interactive GUI for exploring bifurcation diagrams.

```matlab
plotbd_app(branches)
```

---

# Diagnostics files (`d.*`)

## Workflow

```
read_d_auto → read_d_blocks → read_d_table → analysis/plotting
```

---

## d_summary

Prints a formatted summary of spectral data.

```matlab
d_summary(diag)
```

---

## d_plot_spectrum

Plots spectral quantities along continuation.

```matlab
d_plot_spectrum(diag)
```

---

## plot_complex_slider

Interactive complex-plane visualisation.

```matlab
plot_complex_slider(diag)
```

Features:

* slider over continuation points
* unit circle always displayed
* arrows for out-of-range values
* warning if no multiplier near (1,0)

---

## d_plot_app

Interactive app combining diagnostic visualisations.

```matlab
d_plot_app(diag)
```

---

# Solution files (`s.*`)

## read_s_auto

Reads an AUTO `s.*` file and returns a **cell array of solutions**.

Each solution is a struct containing:

* `t` — time vector
* `U` — state variables (`NTPL × NDIM`)
* `LAB`, `IBR`, `PT` — AUTO identifiers
* additional metadata (e.g. `NDIM`, `NTPL`, `IPS`)

---

## plot_s_auto

Flexible plotting function for individual or multiple solutions.

Supports:

* 2D and 3D plots
* time series and phase space plots
* overlay of multiple solutions
* custom variable names

```matlab
% Default variable names (U1, U2, ...)
plot_s_auto(sols, 1, {'t','U1'});
plot_s_auto(sols, 1, {'U1','U2','U3'});

% Custom variable names
varnames = {'x','y','z'};
plot_s_auto(sols, 1, {'x','y'}, 'VarNames', varnames);

% Overlay multiple solutions
plot_s_auto(sols, [1 2 3], {'x','z'}, ...
    'VarNames', varnames, 'Overlay', true);
```

---

## show_s_vars

Displays available variables for a given solution.

```matlab
show_s_vars(sols, 1)
show_s_vars(sols, 1, {'x','y','z'})
```

---

## plot_s_app

Interactive GUI for exploring solution trajectories.

```matlab
plot_s_app(sols)
plot_s_app(sols, {'x','y','z'})
```

Features:

* 2D and 3D plotting
* selection of variables (`t`, `U1`, or custom names)
* multi-selection of solutions
* overlay mode
* live metadata display

---

## Variable naming (`VarNames`)

State variables in AUTO are stored as columns of `U`:

```
U(:,1), U(:,2), ..., U(:,NDIM)
```

By default these are referred to as:

```
U1, U2, U3, ...
```

You can assign meaningful names:

```matlab
varnames = {'x','y','z'};
plot_s_auto(sols, 1, {'x','z'}, 'VarNames', varnames);
```

This improves readability when working with known systems.

---

# Basic usage

```matlab
% --- Bifurcation diagram
branches = read_b_auto("b.lor");
plotbd(branches);

% --- Diagnostics
diag = read_d_auto("d.lor");
d_summary(diag)
d_plot_app(diag)

% --- Solutions
sols = read_s_auto("s.lor");
plot_s_auto(sols, 1, {'t','U1'});
plot_s_app(sols)
```

---

# Notes

* Eigenvalues: stability determined by sign of Re(λ)
* Multipliers: stability determined by |μ|
* One multiplier must satisfy μ = 1 (consistency check)

---

# Future work

* automatic bifurcation detection
* tighter integration between `b.*`, `d.*`, and `s.*`
* support for parameter-dependent solution visualisation
* improved export and publication-quality plotting
