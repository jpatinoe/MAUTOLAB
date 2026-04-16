function ax = plot_s_auto(sols, sol_idx, vars, varargin)
%PLOT_S_AUTO Plot one or several solutions from read_s_auto output.
%
%   ax = plot_s_auto(sols, sol_idx, vars)
%   ax = plot_s_auto(..., Name, Value)
%
% INPUTS
%   sols     : cell array returned by read_s_auto
%   sol_idx  : scalar index or vector of indices of solutions to plot
%   vars     : cell array specifying axes variables
%
%              Examples with default names:
%                {'t','U1'}           -> 2D plot
%                {'U1','U2'}          -> 2D phase plane
%                {'U1','U2','U3'}     -> 3D phase space
%
%              Examples with custom varnames:
%                {'t','x'}
%                {'x','y'}
%                {'x','y','z'}
%
% NAME-VALUE OPTIONS
%   'Parent'      : axes handle
%   'LineWidth'   : line width (default 1.5)
%   'Color'       : line color (default [])
%   'Marker'      : marker style (default 'none')
%   'LabelStyle'  : 'index', 'lab', 'full', or 'none' (default 'full')
%   'Title'       : custom title (default automatic)
%   'VarNames'    : optional variable names for U columns,
%                   e.g. {'x','y','z'}
%   'Overlay'     : true/false, overlay multiple solutions (default false)
%   'Legend'      : true/false, show legend when overlaying (default true)
%
% OUTPUT
%   ax : axes handle
%
% EXAMPLES
%   sols = read_s_auto('s.lor');
%
%   % Default names
%   plot_s_auto(sols, 1, {'t','U1'});
%   plot_s_auto(sols, 1, {'U1','U2','U3'});
%
%   % Custom names
%   plot_s_auto(sols, 1, {'x','y'}, 'VarNames', {'x','y','z'});
%   plot_s_auto(sols, [1 2 3], {'x','z'}, ...
%       'VarNames', {'x','y','z'}, 'Overlay', true);

    % -------------------------
    % Validate main inputs
    % -------------------------
    if ~iscell(sols) || isempty(sols)
        error('sols must be a non-empty cell array returned by read_s_auto.');
    end

    if nargin < 2 || isempty(sol_idx)
        sol_idx = 1;
    end

    if any(sol_idx < 1) || any(sol_idx > numel(sols)) || any(sol_idx ~= round(sol_idx))
        error('sol_idx must contain valid integer indices between 1 and %d.', numel(sols));
    end

    if ~iscell(vars) || ~(numel(vars) == 2 || numel(vars) == 3)
        error('vars must be a cell array with 2 or 3 entries.');
    end

    % -------------------------
    % Parse options
    % -------------------------
    p = inputParser;
    addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'LineWidth', 1.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'Color', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 3));
    addParameter(p, 'Marker', 'none', @(x) ischar(x) || isstring(x));
    addParameter(p, 'LabelStyle', 'full', @(x) any(strcmpi(x, {'index','lab','full','none'})));
    addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'VarNames', [], @(x) isempty(x) || iscell(x));
    addParameter(p, 'Overlay', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'Legend', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    opts = p.Results;

    % -------------------------
    % Variable naming logic
    % -------------------------
    ndim0 = sols{sol_idx(1)}.NDIM;

    if isempty(opts.VarNames)
        varnames = arrayfun(@(k) sprintf('U%d', k), 1:ndim0, 'UniformOutput', false);
    else
        varnames = opts.VarNames;
        validate_varnames(varnames, ndim0);
    end

    % Check consistency across selected solutions
    for k = 1:numel(sol_idx)
        if sols{sol_idx(k)}.NDIM ~= ndim0
            error('All selected solutions must have the same NDIM.');
        end
    end

    % -------------------------
    % Axes
    % -------------------------
    if isempty(opts.Parent)
        figure;
        ax = axes;
    else
        ax = opts.Parent;
    end

    cla(ax);
    hold(ax, 'on');

    % If multiple indices but Overlay=false, use first only
    if numel(sol_idx) > 1 && ~opts.Overlay
        sol_idx = sol_idx(1);
    end

    % -------------------------
    % Plot selected solutions
    % -------------------------
    for j = 1:numel(sol_idx)
        idx = sol_idx(j);
        sol = sols{idx};

        coords = cell(1, numel(vars));
        labels = cell(1, numel(vars));

        for k = 1:numel(vars)
            [coords{k}, labels{k}] = get_axis_data(sol, vars{k}, varnames);
        end

        plotArgs = {'LineWidth', opts.LineWidth, 'Marker', opts.Marker};
        if ~isempty(opts.Color)
            plotArgs = [plotArgs, {'Color', opts.Color}];
        end

        if numel(vars) == 2
            plot(ax, coords{1}, coords{2}, plotArgs{:}, ...
                'DisplayName', make_legend_label(sol, idx));
            xlabel(ax, labels{1}, 'Interpreter', 'none');
            ylabel(ax, labels{2}, 'Interpreter', 'none');
        else
            plot3(ax, coords{1}, coords{2}, coords{3}, plotArgs{:}, ...
                'DisplayName', make_legend_label(sol, idx));
            xlabel(ax, labels{1}, 'Interpreter', 'none');
            ylabel(ax, labels{2}, 'Interpreter', 'none');
            zlabel(ax, labels{3}, 'Interpreter', 'none');
            view(ax, 3);
        end
    end

    grid(ax, 'on');
    box(ax, 'on');

    if numel(sol_idx) > 1 && opts.Overlay && opts.Legend
        legend(ax, 'show', 'Location', 'best');
    end

    % -------------------------
    % Title
    % -------------------------
    if strlength(string(opts.Title)) > 0
        title(ax, opts.Title, 'Interpreter', 'none');
    else
        if numel(sol_idx) == 1
            title(ax, make_title(sols{sol_idx}, sol_idx, opts.LabelStyle), ...
                'Interpreter', 'none');
        else
            title(ax, sprintf('%d overlaid solutions', numel(sol_idx)), ...
                'Interpreter', 'none');
        end
    end
end


function [data, label] = get_axis_data(sol, varspec, varnames)
%GET_AXIS_DATA Return axis data from solution struct.
%
% Allowed specs:
%   't'
%   'U1', 'U2', ...   (always accepted)
%   custom names such as 'x','y','z' if varnames is provided

    varspec = char(string(varspec));
    varspec = strtrim(varspec);

    if strcmpi(varspec, 't')
        data = sol.t(:);
        label = 't';
        return;
    end

    % Case 1: default-style U1, U2, ...
    tok = regexp(varspec, '^U(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        idx = str2double(tok{1});
        if idx < 1 || idx > size(sol.U, 2)
            error('Requested %s, but this solution only has %d state variables.', ...
                varspec, size(sol.U, 2));
        end
        data = sol.U(:, idx);
        if idx <= numel(varnames)
            label = char(string(varnames{idx}));
        else
            label = sprintf('U(%d)', idx);
        end
        return;
    end

    % Case 2: custom variable names
    idx = find(strcmp(varspec, varnames), 1, 'first');
    if ~isempty(idx)
        data = sol.U(:, idx);
        label = char(string(varnames{idx}));
        return;
    end

    error('Unknown variable spec "%s". Use ''t'', ''U1'', ''U2'', ... or one of the custom names.', varspec);
end


function ttl = make_title(sol, sol_idx, labelStyle)
%MAKE_TITLE Automatic plot title.

    switch lower(labelStyle)
        case 'index'
            ttl = sprintf('Solution %d', sol_idx);

        case 'lab'
            ttl = sprintf('LAB = %d', sol.LAB);

        case 'full'
            ttl = sprintf('Solution %d   |   LAB = %d   |   BR = %d   |   PT = %d', ...
                sol_idx, sol.LAB, sol.IBR, sol.PT);

        case 'none'
            ttl = '';

        otherwise
            ttl = sprintf('Solution %d', sol_idx);
    end
end


function txt = make_legend_label(sol, idx)
%MAKE_LEGEND_LABEL Legend label for overlay plots.
    txt = sprintf('%d | LAB=%d | BR=%d', idx, sol.LAB, sol.IBR);
end


function validate_varnames(varnames, ndim)
%VALIDATE_VARNAMES Check variable-name list.
    if ~iscell(varnames) || numel(varnames) ~= ndim
        error('VarNames must be a cell array with exactly %d entries.', ndim);
    end
    if ~all(cellfun(@(s) ischar(s) || isstring(s), varnames))
        error('All entries in VarNames must be text.');
    end
end