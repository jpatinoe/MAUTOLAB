function vars = show_s_vars(sols, sol_idx, varnames)
%SHOW_S_VARS Display plottable variables for one solution from read_s_auto.
%
%   vars = show_s_vars(sols, sol_idx)
%   vars = show_s_vars(sols, sol_idx, varnames)
%
% INPUTS
%   sols     : cell array returned by read_s_auto
%   sol_idx  : index of the solution to inspect
%   varnames : optional cell array of names for the state variables,
%              e.g. {'x','y','z'}.
%
% OUTPUT
%   vars     : cell array of variable names, e.g. {'t','x','y','z'}
%
% EXAMPLE
%   sols = read_s_auto('s.lor');
%   show_s_vars(sols, 1, {'x','y','z'});

    if ~iscell(sols)
        error('sols must be the cell array returned by read_s_auto.');
    end

    if nargin < 2 || isempty(sol_idx)
        sol_idx = 1;
    end

    if sol_idx < 1 || sol_idx > numel(sols) || sol_idx ~= round(sol_idx)
        error('sol_idx must be an integer between 1 and %d.', numel(sols));
    end

    sol = sols{sol_idx};

    if nargin < 3 || isempty(varnames)
        varnames = arrayfun(@(k) sprintf('U%d', k), 1:sol.NDIM, 'UniformOutput', false);
    else
        validate_varnames(varnames, sol.NDIM);
    end

    vars = [{'t'}, varnames(:)'];

    fprintf('\n');
    fprintf('Solution %d\n', sol_idx);
    fprintf('  LAB   = %d\n', sol.LAB);
    fprintf('  BR    = %d\n', sol.IBR);
    fprintf('  PT    = %d\n', sol.PT);
    fprintf('  NDIM  = %d\n', sol.NDIM);
    fprintf('  NTPL  = %d\n', sol.NTPL);
    fprintf('  IPS   = %d\n', sol.IPS);
    fprintf('\n');
    fprintf('Plottable variables:\n');
    for i = 1:numel(vars)
        fprintf('  %s\n', vars{i});
    end
    fprintf('\n');
end

function validate_varnames(varnames, ndim)
    if ~iscell(varnames) || numel(varnames) ~= ndim
        error('varnames must be a cell array with exactly %d entries.', ndim);
    end
    if ~all(cellfun(@(s) ischar(s) || isstring(s), varnames))
        error('All entries in varnames must be text.');
    end
end