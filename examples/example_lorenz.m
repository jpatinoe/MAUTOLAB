%% MAUTOLAB — Worked Example: Lorenz System
%
% This script demonstrates how to use MAUTOLAB to read and visualise
% AUTO-07p continuation output for the Lorenz equations:
%
%   dx/dt = sigma*(y - x)
%   dy/dt = x*(rho - z) - y
%   dz/dt = x*y - beta*z
%
% with sigma = 10, beta = 8/3 (fixed), and rho as the continuation parameter.
%
% Files used:
%   b.lrz   — bifurcation diagram (equilibria + periodic orbits)
%   d.lrz   — diagnostics (eigenvalues and Floquet multipliers)
%   s.lrz   — solutions (full time profiles of periodic orbits)
%
% The AUTO run covers:
%   - Branch 1: trivial equilibrium (origin), rho in [0, 30]
%   - Branch 2: non-trivial equilibria (C+/C-), rho in [1, 30]
%   - Branches from label 4 onward: periodic orbits born at the Hopf
%     bifurcation near rho ≈ 24.74
%
% Prerequisites:
%   1. Add the MAUTOLAB root folder to your MATLAB path, e.g.:
%        addpath('/path/to/MAUTOLAB')
%   2. Place b.lrz, d.lrz, s.lrz in your working directory, or set
%      the path explicitly below.
%
% Tested in MATLAB R2025a.

%% 0. Setup
% --------------------------------------------------------------------------
% Point MATLAB at the MAUTOLAB toolkit.  If MAUTOLAB is already on your
% path you can skip this block.
% addpath('/path/to/MAUTOLAB')   % <-- uncomment and edit if needed

% Location of the AUTO output files (edit if they live elsewhere).
dataDir = pwd;   % assumes files are in the current directory

%% 1. Load all AUTO output files with the unified reader
% --------------------------------------------------------------------------
% MAUTOLAB('lrz') looks for b.lrz, d.lrz, and s.lrz in the current
% directory and returns a struct with three fields.

data = MAUTOLAB('lrz');

% What did we get?
disp('Fields loaded:')
disp(fieldnames(data))

% data.bif_diagram  — struct array, one entry per branch
% data.diagnostics  — struct array, one entry per continuation point
% data.solutions    — cell array, one cell per labelled solution

%% 2. Read and inspect the bifurcation diagram (b.lrz)
% --------------------------------------------------------------------------
branches = data.bif_diagram;
fprintf('\nNumber of branches: %d\n', numel(branches));

for k = 1:numel(branches)
    fprintf('  Branch %d — %d points, columns: %s\n', ...
        branches(k).branch_number, ...
        height(branches(k).data), ...
        strjoin(branches(k).data.Properties.VariableNames, ', '));
end

% Inspect the first few rows of the first branch (origin equilibrium)
disp(' ')
disp('Branch 1 (origin), first 5 rows:')
disp(branches(1).data(1:5, :))

%% 3. Plot the bifurcation diagram
% --------------------------------------------------------------------------
% NOTE: plotbd always creates its own figure unless you pass an 'Axes'
% handle.  The correct pattern is to create the figure+axes first, then
% pass the axes handle — never just call figure() before plotbd().

% Default plot: column 4 (rho) vs column 5 (L2-NORM).
fig1 = figure('Name', 'Bifurcation diagram — default');
ax1  = axes(fig1);
plotbd(branches, 'Axes', ax1);

% Plot rho vs x — restrict to equilibrium branches (1 and 2) only.
% Periodic orbit branches (4, 6, ...) store peak values (MAX_x, MAX_y, ...)
% rather than a plain 'x' column, so mixing them here would raise a warning.
fig2 = figure('Name', 'Bifurcation diagram — rho vs x (equilibria)');
ax2  = axes(fig2);
plotbd(branches, 'Axes', ax2, 'x', 'rho', 'y', 'x', 'branches', [1 2]);

% Show stability with dashed lines for unstable segments:
fig3 = figure('Name', 'Bifurcation diagram — stability');
ax3  = axes(fig3);
plotbd(branches, 'Axes', ax3, 'Stability', 'dashed');

%% 4. Read and inspect diagnostics (d.lrz)
% --------------------------------------------------------------------------
diag = data.diagnostics;
fprintf('\nNumber of diagnostic blocks: %d\n', numel(diag));

% Each block corresponds to one continuation point.
% Let's look at the first eigenvalue block (Branch 1, point 1):
d1 = diag(1);
fprintf('\nBranch %d, Point %d — spectrum type: %s\n', ...
    d1.branch, d1.point, d1.spectrum_type);

% Eigenvalues at this point:
ev = d1.spectrum{1};
fprintf('  Eigenvalue 1: %.5g + %.5g*i\n', ev(1).real, ev(1).imag);
fprintf('  Eigenvalue 2: %.5g + %.5g*i\n', ev(2).real, ev(2).imag);
fprintf('  Eigenvalue 3: %.5g + %.5g*i\n', ev(3).real, ev(3).imag);

% Print a tidy summary of all diagnostic blocks:
d_summary(diag);

%% 5. Plot eigenvalue / multiplier spectra
% --------------------------------------------------------------------------
% Plot all spectra — d_plot_spectrum creates its own figure(s) internally,
% so just call it directly (no preceding figure() call needed).
d_plot_spectrum(diag);

% Interactive slider to scroll through points:
% d_plot_app(diag)      % uncomment to open the interactive app

%% 6. Build a flat table from the diagnostics
% --------------------------------------------------------------------------
% read_d_table converts the diagnostic struct array into a tidy MATLAB
% table, one row per continuation point, with columns for each eigenvalue
% or multiplier component.
branch_tables = read_d_table(diag);

% The keys are 'B1', 'B2', ... (one per branch number found).
disp(' ')
disp('Diagnostic table — Branch 1, first 5 rows:')
disp(branch_tables.B1(1:5, :))

%% 7. Read and inspect solutions (s.lrz)
% --------------------------------------------------------------------------
sols = data.solutions;
fprintf('\nNumber of solutions stored: %d\n', numel(sols));

% The first few entries are equilibria (trivial); the periodic orbit
% solutions start from label 4 onward.  Let's look at solution 4:
sol = sols{4};
fprintf('\nSolution 4 — IBR=%d  PT=%d  ITP=%d  LAB=%d  NTST=%d  NCOL=%d\n', ...
    sol.IBR, sol.PT, sol.ITP, sol.LAB, sol.NTST, sol.NCOL);
fprintf('  Parameters stored: rho=%.4f  beta=%.4f  sigma=%.4f\n', ...
    sol.PAR(1), sol.PAR(2), sol.PAR(3));

% Show available variables for this solution:
show_s_vars(sols, 4);

%% 8. Plot a periodic orbit time profile
% --------------------------------------------------------------------------
% plot_s_auto(sols, index, variables)
%   variables is a cell array: first entry is 't' for time, or a pair/
%   triple of state variable names for a phase portrait.
%
% IMPORTANT — figure ownership:
%   plot_s_auto creates its own figure unless you pass 'Parent' with an
%   axes handle.  It also calls cla() on entry, so calling it multiple
%   times on the same axes clears the previous plot.  To overlay several
%   variables on one axes, pass all solution indices at once with
%   'Overlay', true — or do the plotting manually after extracting data.
%
% The first periodic orbit solutions in this run start at index 4
% (LAB=4, branch 4 — Hopf bifurcation point on the + branch) and
% index 6 (LAB=6 — same Hopf on the - branch).  Use index 8 onward
% for proper limit cycles.

sol_idx = 8;   % first fully-developed periodic orbit (LAB=8)
sol = sols{sol_idx};
fprintf('\nPlotting solution %d — LAB=%d, IBR=%d, rho=%.4f, T=%.4f\n', ...
    sol_idx, sol.LAB, sol.IBR, sol.PAR(1), sol.PAR(end));

% Time profile of x(t) — let plot_s_auto create its own figure.
plot_s_auto(sols, sol_idx, {'t', 'U1'});

% To plot x, y, z on the same axes, create the axes first and pass it
% via 'Parent'.  Note: each call to plot_s_auto calls cla(), so you
% cannot stack calls on the same axes.  Instead, extract the data
% manually and plot with hold on:
fig = figure('Name', sprintf('Solution %d — time profiles', sol_idx));
ax  = axes(fig);
hold(ax, 'on');
plot(ax, sol.t, sol.U(:,1), 'DisplayName', 'x(t)');
plot(ax, sol.t, sol.U(:,2), 'DisplayName', 'y(t)');
plot(ax, sol.t, sol.U(:,3), 'DisplayName', 'z(t)');
xlabel(ax, 't / T');  ylabel(ax, 'State');
legend(ax, 'Location', 'best');
title(ax, sprintf('Solution %d (LAB=%d, rho=%.2f) — time profiles', ...
    sol_idx, sol.LAB, sol.PAR(1)), 'Interpreter', 'none');
grid(ax, 'on');

% Phase portrait in (x, y) — pass 'Parent' to control the figure:
fig2 = figure('Name', sprintf('Solution %d — phase portrait x-y', sol_idx));
ax2  = axes(fig2);
plot_s_auto(sols, sol_idx, {'U1', 'U2'}, 'Parent', ax2);

% Phase portrait in 3-D (x, y, z):
fig3 = figure('Name', sprintf('Solution %d — 3D phase portrait', sol_idx));
ax3  = axes(fig3);
plot_s_auto(sols, sol_idx, {'U1', 'U2', 'U3'}, 'Parent', ax3);
view(ax3, 45, 30);

%% 9. Interactive solution browser
% --------------------------------------------------------------------------
% plot_s_app opens a GUI that lets you choose which solution and which
% variables to display.

% plot_s_app(sols)   % uncomment to open the interactive app

%% 10. Interactive bifurcation diagram app
% --------------------------------------------------------------------------
% plotbd_app lets you interactively select x/y axes and branches.

% plotbd_app(branches)   % uncomment to open the interactive app

%% 11. One-line convenience: launch the master app
% --------------------------------------------------------------------------
% MAUTOLAB_app lets you load files, inspect what was found, and launch
% any of the sub-apps from a single GUI window.

% MAUTOLAB_app   % uncomment to open