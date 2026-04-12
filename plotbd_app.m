function app = plotbd_app(branches)
%PLOTBD_APP Interactive GUI for exploring AUTO bifurcation diagrams.
%
%   app = plotbd_app(branches)
%
% DESCRIPTION
%   Launches a simple interactive app for plotting the contents of a b-file
%   reader output. This app is a GUI wrapper around PLOTBD, which remains
%   the core plotting engine.
%
%   The app:
%       - plots sensible defaults on launch
%       - lets the user choose x, y, and optionally z
%       - switches between 2D and 3D depending on whether z is selected
%       - allows branch selection
%       - controls interpolation, stability style, special points, labels,
%         legend, grid, and export options
%
% REQUIREMENTS
%   This app expects PLOTBD.M to be on the MATLAB path.
%
% INPUT
%   branches : structure array returned by a b-file reader. Each element is
%              expected to contain:
%                 - branches(i).branch_number
%                 - branches(i).data   (table)
%
% OUTPUT
%   app : structure containing handles to the main UI components
%
% EXAMPLE
%   branches = read_b_auto('b.lor');
%   plotbd_app(branches);

    narginchk(1,1);

    if ~isstruct(branches) || isempty(branches)
        error('plotbd_app:InvalidInput', ...
            'Input must be a non-empty structure array of branches.');
    end

    for i = 1:numel(branches)
        if ~isfield(branches(i), 'data') || ~istable(branches(i).data)
            error('plotbd_app:InvalidBranchData', ...
                'branches(%d).data must be a table.', i);
        end
        if ~isfield(branches(i), 'branch_number')
            error('plotbd_app:MissingBranchNumber', ...
                'branches(%d) must contain a field named branch_number.', i);
        end
    end

    % ---------------------------------------------------------------------
    % Build variable list from union of all variables across branches
    % ---------------------------------------------------------------------
    var_names = get_all_variable_names(branches);

    if isempty(var_names)
        error('plotbd_app:NoVariables', ...
            'No variables were found in the branch data tables.');
    end

    branch_numbers = unique([branches.branch_number]);
    branch_items = ["All branches"; "Branch " + string(branch_numbers(:))];

    % Defaults consistent with plotbd:
    default_x = get_default_var_from_first_branch(branches, 4);
    default_y = get_default_var_from_first_branch(branches, 5);

    if isempty(default_x) || isempty(default_y)
        error('plotbd_app:MissingDefaultColumns', ...
            ['The first branch does not have enough columns to determine ' ...
             'default x/y variables (columns 4 and 5).']);
    end

    % ---------------------------------------------------------------------
    % Main figure
    % ---------------------------------------------------------------------
    fig = uifigure( ...
        'Name', 'plotbd app', ...
        'Position', [100 100 1250 760]);

    main_grid = uigridlayout(fig, [1 2]);
    main_grid.ColumnWidth = {320, '1x'};
    main_grid.RowHeight = {'1x'};

    % ---------------------------------------------------------------------
    % Control panel
    % ---------------------------------------------------------------------
    ctrl_panel = uipanel(main_grid, 'Title', 'Controls');
    ctrl_panel.Layout.Row = 1;
    ctrl_panel.Layout.Column = 1;

    ctrl_grid = uigridlayout(ctrl_panel, [26 2]);
    ctrl_grid.RowHeight = repmat({22}, 1, 26);
    ctrl_grid.RowHeight{25} = 70;
    ctrl_grid.RowHeight{26} = '1x';
    ctrl_grid.ColumnWidth = {120, '1x'};
    ctrl_grid.Padding = [10 10 10 10];
    ctrl_grid.RowSpacing = 6;
    ctrl_grid.ColumnSpacing = 8;

    % X
    uilabel(ctrl_grid, 'Text', 'X variable');
    dd_x = uidropdown(ctrl_grid, 'Items', var_names, 'Value', default_x);

    % Y
    uilabel(ctrl_grid, 'Text', 'Y variable');
    dd_y = uidropdown(ctrl_grid, 'Items', var_names, 'Value', default_y);

    % Z
    uilabel(ctrl_grid, 'Text', 'Z variable');
    dd_z = uidropdown(ctrl_grid, ...
        'Items', ['(none)'; string(var_names(:))], ...
        'Value', '(none)');

    % Branch selection
    uilabel(ctrl_grid, 'Text', 'Branches');
    lb_branches = uilistbox(ctrl_grid, ...
        'Items', cellstr(branch_items), ...
        'Multiselect', 'on', ...
        'Value', {'All branches'});

    % Stability
    uilabel(ctrl_grid, 'Text', 'Stability');
    dd_stability = uidropdown(ctrl_grid, ...
        'Items', {'off','dashed','pale'}, ...
        'Value', 'off');

    % Interpolate
    uilabel(ctrl_grid, 'Text', 'Interpolate');
    cb_interp = uicheckbox(ctrl_grid, 'Value', false);

    % Interp method
    uilabel(ctrl_grid, 'Text', 'Interp method');
    dd_interp_method = uidropdown(ctrl_grid, ...
        'Items', {'linear','nearest','next','previous','spline','pchip','makima','cubic'}, ...
        'Value', 'spline');

    % Interp factor
    uilabel(ctrl_grid, 'Text', 'Interp factor');
    ef_interp_factor = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 1, ...
        'Limits', [1 Inf], ...
        'RoundFractionalValues', 'on');

    % Special points
    uilabel(ctrl_grid, 'Text', 'Special points');
    cb_special = uicheckbox(ctrl_grid, 'Value', true);

    % Special point labels
    uilabel(ctrl_grid, 'Text', 'SP labels');
    cb_special_labels = uicheckbox(ctrl_grid, 'Value', true);

    % Legend
    uilabel(ctrl_grid, 'Text', 'Legend');
    cb_legend = uicheckbox(ctrl_grid, 'Value', true);

    % Grid
    uilabel(ctrl_grid, 'Text', 'Grid');
    cb_grid = uicheckbox(ctrl_grid, 'Value', true);

    % Line width
    uilabel(ctrl_grid, 'Text', 'Line width');
    ef_linewidth = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 2.0, ...
        'Limits', [0.1 Inf]);

    % Marker size
    uilabel(ctrl_grid, 'Text', 'Marker size');
    ef_markersize = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 5, ...
        'Limits', [0.1 Inf]);

    % Title
    uilabel(ctrl_grid, 'Text', 'Title');
    ef_title = uieditfield(ctrl_grid, 'text', 'Value', '');

    % Auto update
    uilabel(ctrl_grid, 'Text', 'Auto update');
    cb_autoupdate = uicheckbox(ctrl_grid, 'Value', true);

    % Export format
    uilabel(ctrl_grid, 'Text', 'Export format');
    dd_export_format = uidropdown(ctrl_grid, ...
        'Items', {'png','jpg','pdf','fig'}, ...
        'Value', 'png');

    % Export DPI
    uilabel(ctrl_grid, 'Text', 'Export dpi');
    ef_export_dpi = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 300, ...
        'Limits', [72 1200], ...
        'RoundFractionalValues', 'on');

    % Spacer
    uilabel(ctrl_grid, 'Text', '');
    uilabel(ctrl_grid, 'Text', '');

    % Buttons
    btn_update = uibutton(ctrl_grid, ...
        'Text', 'Update plot', ...
        'ButtonPushedFcn', @(~,~) update_plot());

    btn_reset = uibutton(ctrl_grid, ...
        'Text', 'Reset', ...
        'ButtonPushedFcn', @(~,~) reset_controls());

    uilabel(ctrl_grid, 'Text', '');
    btn_export = uibutton(ctrl_grid, ...
        'Text', 'Export plot', ...
        'ButtonPushedFcn', @(~,~) export_plot());

    % Status area
    status_area = uitextarea(ctrl_grid, ...
        'Editable', 'off', ...
        'Value', {'Ready.'});
    status_area.Layout.Row = [25 26];
    status_area.Layout.Column = [1 2];

    % ---------------------------------------------------------------------
    % Axes panel
    % ---------------------------------------------------------------------
    ax_panel = uipanel(main_grid, 'Title', 'Plot');
    ax_panel.Layout.Row = 1;
    ax_panel.Layout.Column = 2;

    ax_grid = uigridlayout(ax_panel, [1 1]);
    ax = uiaxes(ax_grid);
    ax.Layout.Row = 1;
    ax.Layout.Column = 1;

    % ---------------------------------------------------------------------
    % Collect app handles
    % ---------------------------------------------------------------------
    app = struct();
    app.figure = fig;
    app.axes = ax;
    app.controls = struct( ...
        'x', dd_x, ...
        'y', dd_y, ...
        'z', dd_z, ...
        'branches', lb_branches, ...
        'stability', dd_stability, ...
        'interpolate', cb_interp, ...
        'interp_method', dd_interp_method, ...
        'interp_factor', ef_interp_factor, ...
        'special_points', cb_special, ...
        'special_labels', cb_special_labels, ...
        'legend', cb_legend, ...
        'grid', cb_grid, ...
        'linewidth', ef_linewidth, ...
        'markersize', ef_markersize, ...
        'title', ef_title, ...
        'autoupdate', cb_autoupdate, ...
        'export_format', dd_export_format, ...
        'export_dpi', ef_export_dpi, ...
        'btn_update', btn_update, ...
        'btn_reset', btn_reset, ...
        'btn_export', btn_export, ...
        'status', status_area);
    app.branches = branches;

    % ---------------------------------------------------------------------
    % Callbacks for live updates
    % ---------------------------------------------------------------------
    wire_auto_update(dd_x);
    wire_auto_update(dd_y);
    wire_auto_update(dd_z);
    wire_auto_update(lb_branches);
    wire_auto_update(dd_stability);
    wire_auto_update(cb_interp);
    wire_auto_update(dd_interp_method);
    wire_auto_update(ef_interp_factor);
    wire_auto_update(cb_special);
    wire_auto_update(cb_special_labels);
    wire_auto_update(cb_legend);
    wire_auto_update(cb_grid);
    wire_auto_update(ef_linewidth);
    wire_auto_update(ef_markersize);
    wire_auto_update(ef_title);
    wire_auto_update(cb_autoupdate);

    % ---------------------------------------------------------------------
    % Initial plot
    % ---------------------------------------------------------------------
    update_plot();

    % =====================================================================
    % Nested functions
    % =====================================================================

    function wire_auto_update(uiobj)
        if isprop(uiobj, 'ValueChangedFcn')
            uiobj.ValueChangedFcn = @(~,~) maybe_update_plot();
        end
    end

    function maybe_update_plot()
        if cb_autoupdate.Value
            update_plot();
        end
    end

    function reset_controls()
        dd_x.Value = default_x;
        dd_y.Value = default_y;
        dd_z.Value = '(none)';
        lb_branches.Value = {'All branches'};
        dd_stability.Value = 'off';
        cb_interp.Value = false;
        dd_interp_method.Value = 'spline';
        ef_interp_factor.Value = 1;
        cb_special.Value = true;
        cb_special_labels.Value = true;
        cb_legend.Value = true;
        cb_grid.Value = true;
        ef_linewidth.Value = 2.0;
        ef_markersize.Value = 5;
        ef_title.Value = '';
        dd_export_format.Value = 'png';
        ef_export_dpi.Value = 300;

        update_plot();
    end

    function update_plot()
        try
            prepare_axes_for_new_plot(ax, fig);

            xvar = dd_x.Value;
            yvar = dd_y.Value;

            if strcmp(dd_z.Value, '(none)')
                zvar = [];
            else
                zvar = dd_z.Value;
            end

            branch_spec = get_selected_branches();

            title_text = strtrim(ef_title.Value);
            if isempty(title_text)
                title_opt = [];
            else
                title_opt = title_text;
            end

            status_area.Value = {'Updating plot...'};

            if isempty(zvar)
                plotbd(branches, ...
                    'x', xvar, ...
                    'y', yvar, ...
                    'branches', branch_spec, ...
                    'Axes', ax, ...
                    'SpecialPoints', cb_special.Value, ...
                    'SpecialPointLabels', cb_special_labels.Value, ...
                    'Stability', dd_stability.Value, ...
                    'Interpolate', cb_interp.Value, ...
                    'InterpMethod', dd_interp_method.Value, ...
                    'InterpFactor', ef_interp_factor.Value, ...
                    'LineWidth', ef_linewidth.Value, ...
                    'MarkerSize', ef_markersize.Value, ...
                    'Title', title_opt, ...
                    'Legend', cb_legend.Value, ...
                    'Grid', cb_grid.Value);
            else
                plotbd(branches, ...
                    'x', xvar, ...
                    'y', yvar, ...
                    'z', zvar, ...
                    'branches', branch_spec, ...
                    'Axes', ax, ...
                    'SpecialPoints', cb_special.Value, ...
                    'SpecialPointLabels', cb_special_labels.Value, ...
                    'Stability', dd_stability.Value, ...
                    'Interpolate', cb_interp.Value, ...
                    'InterpMethod', dd_interp_method.Value, ...
                    'InterpFactor', ef_interp_factor.Value, ...
                    'LineWidth', ef_linewidth.Value, ...
                    'MarkerSize', ef_markersize.Value, ...
                    'Title', title_opt, ...
                    'Legend', cb_legend.Value, ...
                    'Grid', cb_grid.Value);
            end

            status_area.Value = {build_status_message(xvar, yvar, zvar, branch_spec)};

        catch ME
            prepare_axes_for_new_plot(ax, fig);
            status_area.Value = {sprintf('Error: %s', ME.message)};
        end
    end

    function branch_spec = get_selected_branches()
        selected = lb_branches.Value;

        if isempty(selected) || any(strcmp(selected, 'All branches'))
            branch_spec = 'all';
            return
        end

        selected = string(selected);
        nums = zeros(size(selected));

        for ii = 1:numel(selected)
            tok = regexp(selected(ii), '\d+', 'match', 'once');
            if isempty(tok)
                error('plotbd_app:BranchParseFailed', ...
                    'Could not parse selected branch number.');
            end
            nums(ii) = str2double(tok);
        end

        branch_spec = nums;
    end

    function msg = build_status_message(xvar, yvar, zvar, branch_spec)
        if ischar(branch_spec) || isstring(branch_spec)
            branch_text = 'all branches';
        else
            branch_text = sprintf('branches [%s]', num2str(branch_spec));
        end

        if isempty(zvar)
            msg = sprintf('2D plot: x = %s, y = %s, %s.', ...
                xvar, yvar, branch_text);
        else
            msg = sprintf('3D plot: x = %s, y = %s, z = %s, %s.', ...
                xvar, yvar, zvar, branch_text);
        end
    end

    function export_plot()
        try
            fmt = lower(dd_export_format.Value);
            dpi = ef_export_dpi.Value;

            [file, path] = uiputfile( ...
                {['*.' fmt]}, ...
                'Export plot', ...
                ['plotbd_export.' fmt]);

            if isequal(file,0) || isequal(path,0)
                return
            end

            full_name = fullfile(path, file);

            switch fmt
                case {'png','jpg','pdf'}
                    exportgraphics(ax, full_name, 'Resolution', dpi);

                case 'fig'
                    ftmp = figure('Visible', 'off');
                    axtmp = axes(ftmp);
                    copyobj(allchild(ax), axtmp);

                    axtmp.XLim = ax.XLim;
                    axtmp.YLim = ax.YLim;
                    if isprop(ax, 'ZLim')
                        try
                            axtmp.ZLim = ax.ZLim;
                            view(axtmp, ax.View);
                        catch
                        end
                    end

                    axtmp.XLabel.String = ax.XLabel.String;
                    axtmp.YLabel.String = ax.YLabel.String;
                    try
                        axtmp.ZLabel.String = ax.ZLabel.String;
                    catch
                    end
                    axtmp.Title.String = ax.Title.String;

                    grid(axtmp, ax.XGrid);

                    lgd = findall(fig, 'Type', 'Legend');
                    if ~isempty(lgd)
                        legend(axtmp, 'show');
                    end

                    savefig(ftmp, full_name);
                    close(ftmp);

                otherwise
                    error('plotbd_app:UnsupportedFormat', ...
                        'Unsupported export format: %s', fmt);
            end

            status_area.Value = {sprintf('Plot exported to: %s', full_name)};

        catch ME
            status_area.Value = {sprintf('Export failed: %s', ME.message)};
        end
    end
end


function vars = get_all_variable_names(branches)
    vars_str = string.empty;

    for i = 1:numel(branches)
        these = string(branches(i).data.Properties.VariableNames);
        vars_str = union(vars_str, these, 'stable');
    end

    vars = cellstr(vars_str(:));
end


function varname = get_default_var_from_first_branch(branches, col_idx)
    tbl = branches(1).data;
    if width(tbl) >= col_idx
        vars = tbl.Properties.VariableNames;
        varname = vars{col_idx};
    else
        varname = '';
    end
end


function prepare_axes_for_new_plot(ax, fig)
    % Remove legends attached to the figure
    lgd = findall(fig, 'Type', 'Legend');
    if ~isempty(lgd)
        delete(lgd);
    end

    % Fully reset axes
    cla(ax, 'reset');

    % Restore automatic modes safely
    if isprop(ax, 'XLimMode'), ax.XLimMode = 'auto'; end
    if isprop(ax, 'YLimMode'), ax.YLimMode = 'auto'; end
    if isprop(ax, 'ZLimMode'), ax.ZLimMode = 'auto'; end

    if isprop(ax, 'XTickMode'), ax.XTickMode = 'auto'; end
    if isprop(ax, 'YTickMode'), ax.YTickMode = 'auto'; end
    if isprop(ax, 'ZTickMode'), ax.ZTickMode = 'auto'; end

    if isprop(ax, 'CameraPositionMode'), ax.CameraPositionMode = 'auto'; end
    if isprop(ax, 'CameraTargetMode'), ax.CameraTargetMode = 'auto'; end
    if isprop(ax, 'CameraUpVectorMode'), ax.CameraUpVectorMode = 'auto'; end
    if isprop(ax, 'CameraViewAngleMode'), ax.CameraViewAngleMode = 'auto'; end

    hold(ax, 'off');
    view(ax, 2);
end