# MAUTOLAB

MAUTOLAB is a MATLAB toolkit for reading and working with output files produced by [AUTO-07p](https://sourceforge.net/projects/auto-07p/). The long-term goal is to provide a clean MATLAB interface for AUTO output files such as `b.*`, `d.*`, and `s.*`.

At the current stage, the toolkit includes a reader for **AUTO bifurcation diagram files** (`b.*`).

Tested in **MATLAB R2025a**.

## Current functionality

### `read_b_auto`

`read_b_auto` reads an AUTO `b.*` file and returns a MATLAB struct array, with one entry per branch.

Each branch contains:

- `branch_number`: the AUTO branch number
- `data`: a MATLAB table with the numerical columns for that branch
- `header`: a struct containing parsed metadata from the branch header

### `parse_header_lines`

This helper function parses metadata lines that appear in the header block of each branch in a `b.*` file.

Supported metadata currently includes:

- standard numeric AUTO constants such as `NDIM`, `IPS`, `NTST`, `DS`, etc.
- lowercase string fields such as `e`, `s`, `dat`, `sv`
- `User-specified parameters:` written either as numeric indices or as symbolic names
- `Active continuation parameters:` written either as numeric indices or as symbolic names
- indexed name maps such as
  - `parnames = {1: 'rho', 2: 'beta', 3: 'sigma'}`
  - `unames   = {1: 'x', 2: 'y', 3: 'z'}`

## Why this reader is needed

AUTO `b.*` files are not fully uniform across all problem types. In particular:

- header lines may mix numeric constants, strings, and indexed name maps
- continuation parameters may be listed by number or by symbolic name
- column labels may contain spaces, for example:
  - `MAX x`
  - `MAX U(1)`
  - `INTEGRAL U(1)`

Because of this, a plain whitespace-based parser is not sufficient.

The current implementation handles these cases explicitly so that different AUTO demos and problem files can be read into MATLAB more robustly.

## Files in this repository

- `read_b_auto.m` — main reader for AUTO `b.*` files
- `parse_header_lines.m` — helper for parsing header metadata

## Basic usage

Place the `.m` files on your MATLAB path, then run:

```matlab
branches = read_b_auto("b.lor");
```

You can then inspect the result, for example:

```matlab
branches(1).branch_number
branches(1).header
branches(1).data(1:5,:)
```

## Output format

For a file with several branches, the output has the form

```matlab
branches(k).branch_number
branches(k).header
branches(k).data
```

where `branches(k).data` is a MATLAB table.

The first numerical column in the AUTO `b.*` file is the signed branch number. This column is **not** duplicated in the output table; instead it is stored as `branch_number`.

## Notes on column names

The reader converts AUTO column labels into MATLAB-safe table variable names. For example:

- `PAR(1)` becomes `PAR_1`
- `MAX U(1)` becomes `MAX_U_1`
- `L2-NORM` becomes `L2_NORM`

This makes the columns easy to access in MATLAB code.

## Example

```matlab
branches = read_b_auto("b.het");
T = branches(1).data;
plot(T.eps, T.MAX_x)
```

The exact column names depend on the labels present in the AUTO file being read.

## Current limitations

This repository is currently focused on `b.*` files only.

Planned future extensions include readers for:

- `s.*` solution files
- `d.*` diagnostics files

There is also room for additional utilities, for example:

- branch filtering and selection
- conversion utilities between AUTO output and MATLAB plotting workflows
- higher-level functions for accessing continuation parameters and labelled solution points

## Suggested repository setup on GitHub

A simple repository structure is:

```text
MAUTOLAB/
├── README.md
├── read_b_auto.m
└── parse_header_lines.m
```

## How to upload to GitHub

If you create a GitHub repository named `MAUTOLAB`, you can upload these files through the GitHub web interface, or from the command line:

```bash
git init
git branch -M main
git remote add origin https://github.com/<your-username>/MAUTOLAB.git
git add README.md read_b_auto.m parse_header_lines.m
git commit -m "Initial commit: add b-file reader for AUTO outputs"
git push -u origin main
```

## Version note

The code in this repository was prepared for sharing after testing with **MATLAB R2025a**.
