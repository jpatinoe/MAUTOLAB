function h = plotbd(branches, varargin)
%PLOTBD Plot AUTO bifurcation branches in 2D or 3D.
%
%   2D:
%       h = plotbd(branches)
%       h = plotbd(branches, 'x', 'PAR(1)', 'y', 'L2-NORM')
%       h = plotbd(branches, 'x', 4, 'y', 5)
%
%   3D:
%       h = plotbd(branches, 'x', 4, 'y', 5, 'z', 6)
%       h = plotbd(branches, 'x', 'PAR(1)', 'y', 'MAX U(1)', 'z', 'PERIOD')
%
% INPUT
%   branches : structure array returned by a b-file reader. Each element is
%              expected to contain:
%                 - branches(i).branch_number
%                 - branches(i).data   (table)
%
% NAME-VALUE OPTIONS
%   'x'                  : variable name or column index for x-axis
%   'y'                  : variable name or column index for y-axis
%   'z'                  : variable name or column index for z-axis
%                          If omitted or empty, plot is 2D.
%   'branches'           : 'all' (default) or numeric array of branch numbers
%   'Axes'               : target axes handle
%   'SpecialPoints'      : true/false, plot special points and labels
%   'SpecialPointLabels' : true/false, show special-point text labels
%   'Stability'          : 'off' | 'dashed' | 'pale'
%   'Interpolate'        : true/false
%   'InterpMethod'       : interpolation method for interp1
%   'InterpFactor'       : density factor for interpolation
%   'LineWidth'          : line width for branch curves
%   'MarkerSize'         : marker size for special points
%   'Title'              : custom plot title; [] gives automatic title
%   'Legend'             : true/false
%   'Grid'               : true/false
%
% DEFAULTS
%   If 'x' is not specified, the default is column 4.
%   If 'y' is not specified, the default is column 5.
%   If those columns do not exist, the function throws a clear error and
%   asks the user to specify what to plot explicitly.
%   There is no default z-variable; 3D is used only if 'z' is specified.
%
% OUTPUT
%   h : structure with plot handles and resolved options
%
% NOTES
%   - Stability is inferred from the sign of PT, following the previous
%     convention: PT < 0 is treated as stable.
%   - Variable names may differ across b-files, so defaults are based on
%     column position rather than variable name.
%
% EXAMPLES
%   plotbd(branches)
%   plotbd(branches, 'x', 4, 'y', 5)
%   plotbd(branches, 'x', 4, 'y', 5, 'z', 6)
%   plotbd(branches, 'x', 'PAR(1)', 'y', 'L2-NORM')
%   plotbd(branches, 'branches', [1 2], 'Stability', 'dashed')

    narginchk(1, inf);

    if ~isstruct(branches) || isempty(branches)
        error('plotbd:InvalidInput', ...
            'Input must be a non-empty structure array of branches.');
    end

    opts = parse_plotbd_options(varargin{:});
    opts = resolve_xy_defaults(branches, opts);

    is3D = ~isempty(opts.z);
    selected = select_branches(branches, opts.branches);

    if isempty(selected)
        error('plotbd:NoSelectedBranches', ...
            'No branches were selected for plotting.');
    end

    ty_map = special_point_type_map();

    if isempty(opts.Axes) || ~isgraphics(opts.Axes, 'axes')
        fig = figure;
        ax = axes(fig);
    else
        ax = opts.Axes;
    end
    hold(ax, 'on');

    all_branch_nums = unique([branches.branch_number]);
    colors = lines(numel(all_branch_nums));

    line_handles = gobjects(0);
    plotted_branch_numbers = [];

    x_label_name = '';
    y_label_name = '';
    z_label_name = '';
    plotted_anything = false;

    for k = 1:numel(selected)
        i = selected(k);
        tbl = branches(i).data;

        if ~istable(tbl)
            warning('plotbd:InvalidBranchData', ...
                'branches(%d).data is not a table. Skipping this branch.', i);
            continue
        end

        vars = tbl.Properties.VariableNames;

        [xname, okx] = resolve_variable_spec(tbl, opts.x);
        [yname, oky] = resolve_variable_spec(tbl, opts.y);

        if is3D
            [zname, okz] = resolve_variable_spec(tbl, opts.z);
        else
            zname = '';
            okz = true;
        end

        if ~(okx && oky && okz)
            warning('plotbd:MissingVariables', ...
                ['Branch %d does not contain the requested x/y/z specification.\n' ...
                 'Available variables:\n  %s\n' ...
                 'Skipping this branch.'], ...
                branches(i).branch_number, strjoin(vars, ', '));
            continue
        end

        x = tbl.(xname);
        y = tbl.(yname);
        if is3D
            z = tbl.(zname);
        else
            z = [];
        end

        validate_numeric_vector(x, xname, branches(i).branch_number);
        validate_numeric_vector(y, yname, branches(i).branch_number);
        if is3D
            validate_numeric_vector(z, zname, branches(i).branch_number);
        end

        if ismember('PT', vars)
            pt = tbl.PT;
            [~, order] = sort(abs(pt));
            x = x(order);
            y = y(order);
            pt = pt(order);
            if is3D
                z = z(order);
            end
        else
            pt = [];
            order = 1:numel(x);
            if ~strcmpi(opts.Stability, 'off')
                warning('plotbd:MissingPT', ...
                    'Branch %d has no PT column. Stability display disabled for this branch.', ...
                    branches(i).branch_number);
            end
        end

        bn = branches(i).branch_number;
        color_idx = find(all_branch_nums == bn, 1, 'first');
        branch_color = colors(color_idx, :);

        if is3D
            [x_plot, y_plot, z_plot] = maybe_interpolate_3d(x, y, z, opts);
        else
            [x_plot, y_plot] = maybe_interpolate_2d(x, y, opts);
            z_plot = [];
        end

        if ~isempty(pt) && ~strcmpi(opts.Stability, 'off')
            h_this = plot_stability_segments( ...
                ax, x, y, z, pt, x_plot, y_plot, z_plot, ...
                branch_color, bn, opts.Stability, opts.LineWidth, is3D);
        else
            h_this = plot_branch_curve(ax, x_plot, y_plot, z_plot, ...
                branch_color, bn, opts.LineWidth, is3D);
        end

        if ~ismember(bn, plotted_branch_numbers)
            line_handles(end+1,1) = h_this(1); %#ok<AGROW>
            plotted_branch_numbers(end+1) = bn; %#ok<AGROW>
        end

        if opts.SpecialPoints && ismember('TY', vars)
            ty = tbl.TY;
            ty = ty(order);
            plot_special_points(ax, x, y, z, ty, ty_map, opts, is3D);
        end

        if isempty(x_label_name), x_label_name = xname; end
        if isempty(y_label_name), y_label_name = yname; end
        if is3D && isempty(z_label_name), z_label_name = zname; end

        plotted_anything = true;
    end

    if ~plotted_anything
        error('plotbd:NothingPlotted', ...
            'No branches could be plotted with the current x/y/z specification.');
    end

    xlabel(ax, x_label_name, 'Interpreter', 'none');
    ylabel(ax, y_label_name, 'Interpreter', 'none');

    if is3D
        zlabel(ax, z_label_name, 'Interpreter', 'none');
        view(ax, 3);
    end

    if isempty(opts.Title)
        if is3D
            title(ax, sprintf('%s vs %s vs %s', z_label_name, y_label_name, x_label_name), ...
                'Interpreter', 'none');
        else
            title(ax, sprintf('%s vs %s', y_label_name, x_label_name), ...
                'Interpreter', 'none');
        end
    else
        title(ax, opts.Title, 'Interpreter', 'none');
    end

    if opts.Legend && ~isempty(line_handles)
        legend(ax, line_handles, 'Location', 'best');
    end

    if opts.Grid
        grid(ax, 'on');
    else
        grid(ax, 'off');
    end

    h = struct();
    h.axes = ax;
    h.lines = line_handles;
    h.options = opts;
    h.selected_indices = selected;
    h.x_name = x_label_name;
    h.y_name = y_label_name;
    h.z_name = z_label_name;
    h.is3D = is3D;
end


function opts = parse_plotbd_options(varargin)
    parser = inputParser;
    parser.FunctionName = 'plotbd';

    addParameter(parser, 'x', [], @(v) ...
        isempty(v) || ischar(v) || isstring(v) || ...
        (isnumeric(v) && isscalar(v) && v >= 1));

    addParameter(parser, 'y', [], @(v) ...
        isempty(v) || ischar(v) || isstring(v) || ...
        (isnumeric(v) && isscalar(v) && v >= 1));

    addParameter(parser, 'z', [], @(v) ...
        isempty(v) || ischar(v) || isstring(v) || ...
        (isnumeric(v) && isscalar(v) && v >= 1));

    addParameter(parser, 'branches', 'all', @(x) ...
        (ischar(x) || isstring(x)) || (isnumeric(x) && isvector(x)));

    addParameter(parser, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));

    addParameter(parser, 'SpecialPoints', true, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'SpecialPointLabels', true, @(x) islogical(x) && isscalar(x));

    addParameter(parser, 'Stability', 'off', @(s) ...
        any(strcmpi(string(s), ["off","dashed","pale"])));

    addParameter(parser, 'Interpolate', false, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'InterpMethod', 'spline', @(s) ischar(s) || isstring(s));
    addParameter(parser, 'InterpFactor', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);

    addParameter(parser, 'LineWidth', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, 'MarkerSize', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);

    addParameter(parser, 'Title', [], @(x) ...
        isempty(x) || ischar(x) || isstring(x));

    addParameter(parser, 'Legend', true, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'Grid', true, @(x) islogical(x) && isscalar(x));

    parse(parser, varargin{:});
    opts = parser.Results;

    if ischar(opts.x) || isstring(opts.x), opts.x = char(string(opts.x)); end
    if ischar(opts.y) || isstring(opts.y), opts.y = char(string(opts.y)); end
    if ischar(opts.z) || isstring(opts.z), opts.z = char(string(opts.z)); end
    opts.Stability = char(string(opts.Stability));
    opts.InterpMethod = char(string(opts.InterpMethod));
    if ~isempty(opts.Title), opts.Title = char(string(opts.Title)); end
end


function opts = resolve_xy_defaults(branches, opts)
    tbl = branches(1).data;

    if ~istable(tbl)
        error('plotbd:InvalidBranchData', ...
            'branches(1).data must be a table.');
    end

    vars = tbl.Properties.VariableNames;
    nvars = width(tbl);

    if isempty(opts.x)
        if nvars >= 4
            opts.x = 4;
        else
            error('plotbd:NeedX', ...
                ['Could not determine default x variable because the table has fewer than 4 columns.\n' ...
                 'Available variables in branch %d:\n  %s\n' ...
                 'Please specify ''x'' explicitly.'], ...
                branches(1).branch_number, strjoin(vars, ', '));
        end
    end

    if isempty(opts.y)
        if nvars >= 5
            opts.y = 5;
        else
            error('plotbd:NeedY', ...
                ['Could not determine default y variable because the table has fewer than 5 columns.\n' ...
                 'Available variables in branch %d:\n  %s\n' ...
                 'Please specify ''y'' explicitly.'], ...
                branches(1).branch_number, strjoin(vars, ', '));
        end
    end
end


function selected = select_branches(branches, branch_spec)
    if ischar(branch_spec) || isstring(branch_spec)
        if strcmpi(string(branch_spec), "all")
            selected = 1:numel(branches);
            return
        else
            error('plotbd:InvalidBranches', ...
                'Option ''branches'' must be ''all'' or a numeric vector of branch numbers.');
        end
    end

    requested = unique(branch_spec(:).');
    selected = find(ismember([branches.branch_number], requested));

    if isempty(selected)
        warning('plotbd:NoMatchingBranches', ...
            'No requested branch numbers were found.');
    end
end


function [varname, ok] = resolve_variable_spec(tbl, spec)
    vars = tbl.Properties.VariableNames;
    ok = true;

    if ischar(spec) || isstring(spec)
        varname = char(string(spec));
        if ~ismember(varname, vars)
            ok = false;
        end
        return
    end

    if isnumeric(spec) && isscalar(spec) && spec >= 1 && spec <= width(tbl)
        varname = vars{spec};
        return
    end

    varname = '';
    ok = false;
end


function [x_plot, y_plot] = maybe_interpolate_2d(x, y, opts)
    if ~opts.Interpolate || numel(x) < 2 || opts.InterpFactor == 1
        x_plot = x;
        y_plot = y;
        return
    end

    dx = diff(x);
    dy = diff(y);
    s = [0; cumsum(sqrt(dx.^2 + dy.^2))];

    if numel(unique(s)) < 2
        x_plot = x;
        y_plot = y;
        return
    end

    s_fine = sort(unique([linspace(0, s(end), opts.InterpFactor * numel(x)), s']));
    x_plot = interp1(s, x, s_fine, opts.InterpMethod);
    y_plot = interp1(s, y, s_fine, opts.InterpMethod);
end


function [x_plot, y_plot, z_plot] = maybe_interpolate_3d(x, y, z, opts)
    if ~opts.Interpolate || numel(x) < 2 || opts.InterpFactor == 1
        x_plot = x;
        y_plot = y;
        z_plot = z;
        return
    end

    dx = diff(x);
    dy = diff(y);
    dz = diff(z);
    s = [0; cumsum(sqrt(dx.^2 + dy.^2 + dz.^2))];

    if numel(unique(s)) < 2
        x_plot = x;
        y_plot = y;
        z_plot = z;
        return
    end

    s_fine = sort(unique([linspace(0, s(end), opts.InterpFactor * numel(x)), s']));
    x_plot = interp1(s, x, s_fine, opts.InterpMethod);
    y_plot = interp1(s, y, s_fine, opts.InterpMethod);
    z_plot = interp1(s, z, s_fine, opts.InterpMethod);
end


function h = plot_branch_curve(ax, x, y, z, branch_color, branch_num, line_width, is3D)
    if is3D
        h = plot3(ax, x, y, z, '-', ...
            'LineWidth', line_width, ...
            'Color', branch_color, ...
            'DisplayName', sprintf('Branch %d', branch_num));
    else
        h = plot(ax, x, y, '-', ...
            'LineWidth', line_width, ...
            'Color', branch_color, ...
            'DisplayName', sprintf('Branch %d', branch_num));
    end
end


function h = plot_stability_segments(ax, x, y, z, pt, x_plot, y_plot, z_plot, ...
                                     branch_color, branch_num, mode, line_width, is3D)
    pale_color = lighten(branch_color, 0.6);
    h = gobjects(0);

    branch_plotted = false;
    seg_start = 1;

    for j = 2:numel(pt)
        stab_prev = pt(j-1) < 0;
        stab_curr = pt(j) < 0;
        is_transition = stab_prev ~= stab_curr;

        if is_transition || j == numel(pt)
            x_match = x(j-1);
            y_match = y(j-1);

            if is3D
                z_match = z(j-1);
                dists = hypot3(x_plot - x_match, y_plot - y_match, z_plot - z_match);
            else
                dists = hypot(x_plot - x_match, y_plot - y_match);
            end

            [~, idx_interp] = min(dists);
            seg_end = max(idx_interp, seg_start);

            seg_x = x_plot(seg_start:seg_end);
            seg_y = y_plot(seg_start:seg_end);
            if is3D
                seg_z = z_plot(seg_start:seg_end);
            else
                seg_z = [];
            end

            [style, col] = stability_style(stab_prev, branch_color, pale_color, mode);

            if is3D
                hseg = plot3(ax, seg_x, seg_y, seg_z, style, ...
                    'Color', col, ...
                    'LineWidth', line_width, ...
                    'HandleVisibility', ternary(branch_plotted, 'off', 'on'), ...
                    'DisplayName', sprintf('Branch %d', branch_num));
            else
                hseg = plot(ax, seg_x, seg_y, style, ...
                    'Color', col, ...
                    'LineWidth', line_width, ...
                    'HandleVisibility', ternary(branch_plotted, 'off', 'on'), ...
                    'DisplayName', sprintf('Branch %d', branch_num));
            end

            if ~branch_plotted
                h(end+1,1) = hseg; %#ok<AGROW>
                branch_plotted = true;
            end

            seg_start = seg_end;
        end
    end

    if seg_start <= numel(x_plot)
        seg_x = x_plot(seg_start:end);
        seg_y = y_plot(seg_start:end);
        if is3D
            seg_z = z_plot(seg_start:end);
        else
            seg_z = [];
        end

        [style, col] = stability_style(pt(end) < 0, branch_color, pale_color, mode);

        if is3D
            plot3(ax, seg_x, seg_y, seg_z, style, ...
                'Color', col, ...
                'LineWidth', line_width, ...
                'HandleVisibility', 'off');
        else
            plot(ax, seg_x, seg_y, style, ...
                'Color', col, ...
                'LineWidth', line_width, ...
                'HandleVisibility', 'off');
        end
    end
end


function [style, col] = stability_style(is_stable, branch_color, pale_color, mode)
    switch lower(mode)
        case 'dashed'
            style = ternary(is_stable, '-', '--');
            col = branch_color;
        case 'pale'
            style = '-';
            col = ternary(is_stable, branch_color, pale_color);
        otherwise
            style = '-';
            col = branch_color;
    end
end


function plot_special_points(ax, x, y, z, ty, ty_map, opts, is3D)
    sp_idx = find(ty ~= 0);

    for j = sp_idx(:).'
        label = string(ty(j));
        if isKey(ty_map, label)
            if is3D
                plot3(ax, x(j), y(j), z(j), 'ko', ...
                    'MarkerSize', opts.MarkerSize, ...
                    'MarkerFaceColor', 'k', ...
                    'HandleVisibility', 'off');

                if opts.SpecialPointLabels
                    text(ax, x(j), y(j), z(j), ['  ', ty_map(label)], ...
                        'FontSize', 8, ...
                        'Color', 'red', ...
                        'VerticalAlignment', 'bottom', ...
                        'HorizontalAlignment', 'left', ...
                        'Interpreter', 'none');
                end
            else
                plot(ax, x(j), y(j), 'ko', ...
                    'MarkerSize', opts.MarkerSize, ...
                    'MarkerFaceColor', 'k', ...
                    'HandleVisibility', 'off');

                if opts.SpecialPointLabels
                    text(ax, x(j), y(j), ['  ', ty_map(label)], ...
                        'FontSize', 8, ...
                        'Color', 'red', ...
                        'VerticalAlignment', 'bottom', ...
                        'HorizontalAlignment', 'left', ...
                        'Interpreter', 'none');
                end
            end
        end
    end
end


function ty_map = special_point_type_map()
    ty_map = containers.Map( ...
        {'1','2','3','4','-4','5','6','7','8','9','-9', ...
         '-21','-22','-31','-32','-13','-23','-33','-25','-55','-85', ...
         '-76','-86','-87','-88','28','78','23','83','77','87','88'}, ...
        {'BP','LP','HB','RG','UZ','LP','BP','PD','TR','EP','MX', ...
         'BT','CP','BT','GH','ZH','ZH','ZH','R1','R1','R1', ...
         'R2','R2','R3','R4','LPD','LPD','LTR','LTR','PTR','PTR','TTR'});
end


function validate_numeric_vector(v, name, branch_number)
    if ~isnumeric(v) || ~isvector(v)
        error('plotbd:InvalidVariable', ...
            'Variable "%s" in branch %d must be a numeric vector.', ...
            name, branch_number);
    end
end


function d = hypot3(x, y, z)
    d = sqrt(x.^2 + y.^2 + z.^2);
end


function new_col = lighten(col, factor)
    new_col = col + (1 - col) * factor;
end


function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end