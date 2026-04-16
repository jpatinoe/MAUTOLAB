function app = plotbd_app(branches)
%PLOTBD_APP Interactive GUI for exploring AUTO bifurcation diagrams.
%
%   app = plotbd_app(branches)

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
    % Variable list
    % ---------------------------------------------------------------------
    var_names = get_all_variable_names(branches);
    if isempty(var_names)
        error('plotbd_app:NoVariables', ...
            'No variables were found in the branch data tables.');
    end

    branch_numbers = unique([branches.branch_number], 'stable');
    branch_items = "Branch " + string(branch_numbers(:));

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
        'Position', [100 100 1320 820]);

    main_grid = uigridlayout(fig, [1 2]);
    main_grid.ColumnWidth = {360, '1x'};
    main_grid.RowHeight = {'1x'};

    % ---------------------------------------------------------------------
    % Control panel
    % ---------------------------------------------------------------------
    ctrl_panel = uipanel(main_grid, 'Title', 'Controls');
    ctrl_panel.Layout.Row = 1;
    ctrl_panel.Layout.Column = 1;

    ctrl_grid = uigridlayout(ctrl_panel, [26 2]);
    ctrl_grid.ColumnWidth = {120, '1x'};
    ctrl_grid.RowHeight = { ...
        22, ... 1 x
        90, ... 2 y candidates
        90, ... 3 z candidates
        22, ... 4 all branches
        110, ...5 branch list
        22, ... 6 select all branches
        22, ... 7 select none branches
        22, ... 8 stability
        22, ... 9 interpolate
        22, ...10 interp method
        22, ...11 interp factor
        22, ...12 special points
        22, ...13 special labels
        22, ...14 legend
        22, ...15 grid
        22, ...16 line width
        22, ...17 marker size
        22, ...18 title
        22, ...19 auto update
        22, ...20 export format
        22, ...21 export dpi
        22, ...22 update/reset
        22, ...23 export
        44, ...24 help text
        '1x', ...25 status
        1};    % 26 spare
    ctrl_grid.Padding = [10 10 10 10];
    ctrl_grid.RowSpacing = 6;
    ctrl_grid.ColumnSpacing = 8;

    % X selector
    lbl_x = uilabel(ctrl_grid, 'Text', 'X variable');
    lbl_x.Layout.Row = 1; lbl_x.Layout.Column = 1;
    dd_x = uidropdown(ctrl_grid, 'Items', var_names, 'Value', default_x);
    dd_x.Layout.Row = 1; dd_x.Layout.Column = 2;

    % Y candidates
    lbl_y = uilabel(ctrl_grid, 'Text', 'Y variable(s)');
    lbl_y.Layout.Row = 2; lbl_y.Layout.Column = 1;
    lb_y = uilistbox(ctrl_grid, ...
        'Items', var_names, ...
        'Multiselect', 'on', ...
        'Value', {default_y});
    lb_y.Layout.Row = 2; lb_y.Layout.Column = 2;

    % Z candidates
    lbl_z = uilabel(ctrl_grid, 'Text', 'Z variable(s)');
    lbl_z.Layout.Row = 3; lbl_z.Layout.Column = 1;
    lb_z = uilistbox(ctrl_grid, ...
        'Items', ['(none)'; string(var_names(:))], ...
        'Multiselect', 'on', ...
        'Value', {'(none)'});
    lb_z.Layout.Row = 3; lb_z.Layout.Column = 2;

    % All branches
    lbl_all = uilabel(ctrl_grid, 'Text', 'All branches');
    lbl_all.Layout.Row = 4; lbl_all.Layout.Column = 1;
    cb_all_branches = uicheckbox(ctrl_grid, 'Value', true);
    cb_all_branches.Layout.Row = 4; cb_all_branches.Layout.Column = 2;

    % Branch list
    lbl_branches = uilabel(ctrl_grid, 'Text', 'Branches');
    lbl_branches.Layout.Row = 5; lbl_branches.Layout.Column = 1;
    lb_branches = uilistbox(ctrl_grid, ...
        'Items', cellstr(branch_items), ...
        'Multiselect', 'on', ...
        'Value', cellstr(branch_items), ...
        'Enable', 'off');
    lb_branches.Layout.Row = 5; lb_branches.Layout.Column = 2;

    % Branch buttons
    spacer1 = uilabel(ctrl_grid, 'Text', '');
    spacer1.Layout.Row = 6; spacer1.Layout.Column = 1;
    btn_sel_all_branches = uibutton(ctrl_grid, ...
        'Text', 'Select all', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) on_select_all_branches());
    btn_sel_all_branches.Layout.Row = 6; btn_sel_all_branches.Layout.Column = 2;

    spacer2 = uilabel(ctrl_grid, 'Text', '');
    spacer2.Layout.Row = 7; spacer2.Layout.Column = 1;
    btn_clear_branches = uibutton(ctrl_grid, ...
        'Text', 'Select none', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) on_clear_branches());
    btn_clear_branches.Layout.Row = 7; btn_clear_branches.Layout.Column = 2;

    % Stability
    lbl_stab = uilabel(ctrl_grid, 'Text', 'Stability');
    lbl_stab.Layout.Row = 8; lbl_stab.Layout.Column = 1;
    dd_stability = uidropdown(ctrl_grid, ...
        'Items', {'off','dashed','pale'}, ...
        'Value', 'off');
    dd_stability.Layout.Row = 8; dd_stability.Layout.Column = 2;

    % Interpolate
    lbl_interp = uilabel(ctrl_grid, 'Text', 'Interpolate');
    lbl_interp.Layout.Row = 9; lbl_interp.Layout.Column = 1;
    cb_interp = uicheckbox(ctrl_grid, 'Value', false);
    cb_interp.Layout.Row = 9; cb_interp.Layout.Column = 2;

    % Interp method
    lbl_im = uilabel(ctrl_grid, 'Text', 'Interp method');
    lbl_im.Layout.Row = 10; lbl_im.Layout.Column = 1;
    dd_interp_method = uidropdown(ctrl_grid, ...
        'Items', {'linear','nearest','next','previous','spline','pchip','makima','cubic'}, ...
        'Value', 'spline');
    dd_interp_method.Layout.Row = 10; dd_interp_method.Layout.Column = 2;

    % Interp factor
    lbl_if = uilabel(ctrl_grid, 'Text', 'Interp factor');
    lbl_if.Layout.Row = 11; lbl_if.Layout.Column = 1;
    ef_interp_factor = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 1, ...
        'Limits', [1 Inf], ...
        'RoundFractionalValues', 'on');
    ef_interp_factor.Layout.Row = 11; ef_interp_factor.Layout.Column = 2;

    % Special points
    lbl_sp = uilabel(ctrl_grid, 'Text', 'Special points');
    lbl_sp.Layout.Row = 12; lbl_sp.Layout.Column = 1;
    cb_special = uicheckbox(ctrl_grid, 'Value', true);
    cb_special.Layout.Row = 12; cb_special.Layout.Column = 2;

    % Special labels
    lbl_spl = uilabel(ctrl_grid, 'Text', 'SP labels');
    lbl_spl.Layout.Row = 13; lbl_spl.Layout.Column = 1;
    cb_special_labels = uicheckbox(ctrl_grid, 'Value', true);
    cb_special_labels.Layout.Row = 13; cb_special_labels.Layout.Column = 2;

    % Legend
    lbl_leg = uilabel(ctrl_grid, 'Text', 'Legend');
    lbl_leg.Layout.Row = 14; lbl_leg.Layout.Column = 1;
    cb_legend = uicheckbox(ctrl_grid, 'Value', true);
    cb_legend.Layout.Row = 14; cb_legend.Layout.Column = 2;

    % Grid
    lbl_grid = uilabel(ctrl_grid, 'Text', 'Grid');
    lbl_grid.Layout.Row = 15; lbl_grid.Layout.Column = 1;
    cb_grid = uicheckbox(ctrl_grid, 'Value', true);
    cb_grid.Layout.Row = 15; cb_grid.Layout.Column = 2;

    % Line width
    lbl_lw = uilabel(ctrl_grid, 'Text', 'Line width');
    lbl_lw.Layout.Row = 16; lbl_lw.Layout.Column = 1;
    ef_linewidth = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 2.0, ...
        'Limits', [0.1 Inf]);
    ef_linewidth.Layout.Row = 16; ef_linewidth.Layout.Column = 2;

    % Marker size
    lbl_ms = uilabel(ctrl_grid, 'Text', 'Marker size');
    lbl_ms.Layout.Row = 17; lbl_ms.Layout.Column = 1;
    ef_markersize = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 5, ...
        'Limits', [0.1 Inf]);
    ef_markersize.Layout.Row = 17; ef_markersize.Layout.Column = 2;

    % Title
    lbl_title = uilabel(ctrl_grid, 'Text', 'Title');
    lbl_title.Layout.Row = 18; lbl_title.Layout.Column = 1;
    ef_title = uieditfield(ctrl_grid, 'text', 'Value', '');
    ef_title.Layout.Row = 18; ef_title.Layout.Column = 2;

    % Auto update
    lbl_auto = uilabel(ctrl_grid, 'Text', 'Auto update');
    lbl_auto.Layout.Row = 19; lbl_auto.Layout.Column = 1;
    cb_autoupdate = uicheckbox(ctrl_grid, 'Value', true);
    cb_autoupdate.Layout.Row = 19; cb_autoupdate.Layout.Column = 2;

    % Export format
    lbl_fmt = uilabel(ctrl_grid, 'Text', 'Export format');
    lbl_fmt.Layout.Row = 20; lbl_fmt.Layout.Column = 1;
    dd_export_format = uidropdown(ctrl_grid, ...
        'Items', {'png','jpg','pdf','fig'}, ...
        'Value', 'png');
    dd_export_format.Layout.Row = 20; dd_export_format.Layout.Column = 2;

    % Export DPI
    lbl_dpi = uilabel(ctrl_grid, 'Text', 'Export dpi');
    lbl_dpi.Layout.Row = 21; lbl_dpi.Layout.Column = 1;
    ef_export_dpi = uieditfield(ctrl_grid, 'numeric', ...
        'Value', 300, ...
        'Limits', [72 1200], ...
        'RoundFractionalValues', 'on');
    ef_export_dpi.Layout.Row = 21; ef_export_dpi.Layout.Column = 2;

    % Buttons
    btn_update = uibutton(ctrl_grid, ...
        'Text', 'Update plot', ...
        'ButtonPushedFcn', @(~,~) update_plot());
    btn_update.Layout.Row = 22; btn_update.Layout.Column = 1;

    btn_reset = uibutton(ctrl_grid, ...
        'Text', 'Reset', ...
        'ButtonPushedFcn', @(~,~) reset_controls());
    btn_reset.Layout.Row = 22; btn_reset.Layout.Column = 2;

    spacer3 = uilabel(ctrl_grid, 'Text', '');
    spacer3.Layout.Row = 23; spacer3.Layout.Column = 1;
    btn_export = uibutton(ctrl_grid, ...
        'Text', 'Export plot', ...
        'ButtonPushedFcn', @(~,~) export_plot());
    btn_export.Layout.Row = 23; btn_export.Layout.Column = 2;

    % Help text
    help_text = uitextarea(ctrl_grid, ...
        'Editable', 'off', ...
        'Value', { ...
            'Y/Z can contain multiple candidates.', ...
            'For each branch, the first available variable is used.'});
    help_text.Layout.Row = 24;
    help_text.Layout.Column = [1 2];

    % Status
    status_area = uitextarea(ctrl_grid, ...
        'Editable', 'off', ...
        'Value', {'Ready.'});
    status_area.Layout.Row = 25;
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
    % App struct
    % ---------------------------------------------------------------------
    app = struct();
    app.figure = fig;
    app.axes = ax;
    app.controls = struct( ...
        'x', dd_x, ...
        'y', lb_y, ...
        'z', lb_z, ...
        'all_branches', cb_all_branches, ...
        'branches', lb_branches, ...
        'btn_select_all_branches', btn_sel_all_branches, ...
        'btn_clear_branches', btn_clear_branches, ...
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
    % Callbacks
    % ---------------------------------------------------------------------
    wire_auto_update(dd_x);
    wire_auto_update(lb_y);
    wire_auto_update(lb_z);
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

    cb_all_branches.ValueChangedFcn = @(~,~) on_all_branches_changed();
    lb_branches.ValueChangedFcn = @(~,~) maybe_update_plot();

    % Initial plot
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

    function on_all_branches_changed()
        if cb_all_branches.Value
            lb_branches.Enable = 'off';
            btn_sel_all_branches.Enable = 'off';
            btn_clear_branches.Enable = 'off';
        else
            lb_branches.Enable = 'on';
            btn_sel_all_branches.Enable = 'on';
            btn_clear_branches.Enable = 'on';

            if isempty(lb_branches.Value) && ~isempty(lb_branches.Items)
                lb_branches.Value = lb_branches.Items(1);
            end
        end
        maybe_update_plot();
    end

    function on_select_all_branches()
        lb_branches.Value = lb_branches.Items;
        maybe_update_plot();
    end

    function on_clear_branches()
        lb_branches.Value = {};
        maybe_update_plot();
    end

    function reset_controls()
        dd_x.Value = default_x;
        lb_y.Value = {default_y};
        lb_z.Value = {'(none)'};
        cb_all_branches.Value = true;
        lb_branches.Enable = 'off';
        lb_branches.Value = cellstr(branch_items);
        btn_sel_all_branches.Enable = 'off';
        btn_clear_branches.Enable = 'off';
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
            yvar = string(lb_y.Value);

            if isempty(yvar)
                error('plotbd_app:NoYSelected', ...
                    'Select at least one Y variable.');
            end

            zsel = string(lb_z.Value);
            if isempty(zsel) || any(zsel == "(none)")
                zvar = [];
            else
                zvar = zsel;
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
                    'y', cellstr(yvar), ...
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
                    'y', cellstr(yvar), ...
                    'z', cellstr(zvar), ...
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
        if cb_all_branches.Value
            branch_spec = 'all';
            return
        end

        selected = string(lb_branches.Value);

        if isempty(selected)
            error('plotbd_app:NoBranchSelected', ...
                'Select at least one branch, or enable "All branches".');
        end

        nums = zeros(1, numel(selected));
        for ii = 1:numel(selected)
            tok = regexp(char(selected(ii)), '\d+', 'match', 'once');
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

        ytxt = strjoin(cellstr(yvar), ', ');

        if isempty(zvar)
            msg = sprintf('2D plot: x = %s, y candidates = {%s}, %s.', ...
                xvar, ytxt, branch_text);
        else
            ztxt = strjoin(cellstr(zvar), ', ');
            msg = sprintf('3D plot: x = %s, y candidates = {%s}, z candidates = {%s}, %s.', ...
                xvar, ytxt, ztxt, branch_text);
        end
    end

    function export_plot()
        try
            fmt = lower(dd_export_format.Value);
            dpi = ef_export_dpi.Value;

            [file, path] = uiputfile({['*.' fmt]}, 'Export plot', ['plotbd_export.' fmt]);

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
                    try
                        axtmp.ZLim = ax.ZLim;
                        view(axtmp, ax.View);
                    catch
                    end

                    axtmp.XLabel.String = ax.XLabel.String;
                    axtmp.YLabel.String = ax.YLabel.String;
                    try
                        axtmp.ZLabel.String = ax.ZLabel.String;
                    catch
                    end
                    axtmp.Title.String = ax.Title.String;

                    if strcmpi(ax.XGrid, 'on')
                        grid(axtmp, 'on');
                    else
                        grid(axtmp, 'off');
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
    lgd = findall(fig, 'Type', 'Legend');
    if ~isempty(lgd)
        delete(lgd);
    end

    cla(ax, 'reset');

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