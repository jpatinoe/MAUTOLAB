# MAUTOLAB

MAUTOLAB is a MATLAB toolkit for reading and working with output files produced by AUTO-07p.

The goal is to provide a clean, structured, and MATLAB-native interface for AUTO output files such as:

- `b.*` — bifurcation diagrams  
- `d.*` — diagnostics (eigenvalues / multipliers)  
- `s.*` — solutions *(planned)*  

Tested in MATLAB R2025a.

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
└── docs/
```

---

# Bifurcation diagram files (`b.*`)

## read_b_auto

Reads an AUTO `b.*` file and returns a struct array, one entry per branch.

Each branch contains:
- `branch_number`
- `data` (MATLAB table)
- `header` (parsed metadata)

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
- slider over continuation points
- unit circle always displayed
- arrows for out-of-range values
- warning if no multiplier near (1,0)

---

## d_plot_app

Interactive app combining all diagnostic visualisations.

```matlab
d_plot_app(diag)
```

---

# Basic usage

```matlab
branches = read_b_auto("b.lor");
plotbd(branches);

diag = read_d_auto("d.lor");
d_summary(diag)
d_plot_app(diag)
```

---

# Notes

- Eigenvalues: stability determined by sign of Re(λ)
- Multipliers: stability determined by |μ|
- One multiplier must satisfy μ = 1 (consistency check)

---

# Future work

- support for `s.*` files
- automatic bifurcation detection
- integration between `b.*` and `d.*`
