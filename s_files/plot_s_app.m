function fig = plot_s_app(sols, varnames)
%PLOT_S_APP Interactive app for plotting solutions from read_s_auto output.
%
%   fig = plot_s_app(sols)
%   fig = plot_s_app(sols, varnames)
%
% INPUTS
%   sols     : cell array returned by read_s_auto
%   varnames : optional cell array of names for the state variables,
%              e.g. {'x','y','z'}.
%
% FEATURES
%   - 2D and 3D plotting
%   - single or multiple solution selection
%   - overlay mode for plotting several solutions together
%
% EXAMPLE
%   sols = read_s_auto('s.lor');
%   plot_s_app(sols, {'x','y','z'});

    if ~iscell(sols) || isempty(sols)
        error('sols must be a non-empty cell array returned by read_s_auto.');
    end

    ndim0 = sols{1}.NDIM;
    if nargin < 2 || isempty(varnames)
        varnames = arrayfun(@(k) sprintf('U%d', k), 1:ndim0, 'UniformOutput', false);
    else
        validate_varnames(varnames, ndim0);
    end

    % -----------------------------
    % Create figure and layout
    % -----------------------------
    fig = uifigure('Name', 'plot_s_app', 'Position', [100 100 1120 650]);

    gl = uigridlayout(fig, [1 2]);
    gl.ColumnWidth = {290, '1x'};

    left = uigridlayout(gl, [14 1]);
    left.Layout.Row = 1;
    left.Layout.Column = 1;
    left.RowHeight = {22, 140, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, '1x', 22};
    left.Padding = [10 10 10 10];
    left.RowSpacing = 8;

    ax = uiaxes(gl);
    ax.Layout.Row = 1;
    ax.Layout.Column = 2;
    title(ax, 'Solution plot');
    grid(ax, 'on');
    box(ax, 'on');

    % -----------------------------
    % Widgets
    % -----------------------------
    uilabel(left, 'Text', 'Solutions');

    items = makeSolutionItems(sols);
    lst = uilistbox(left, ...
        'Items', items, ...
        'Multiselect', 'on', ...
        'Value', {items{1}});

    uilabel(left, 'Text', 'Plot type');
    ddDim = uidropdown(left, ...
        'Items', {'2D', '3D'}, ...
        'Value', '2D');

    cbOverlay = uicheckbox(left, ...
        'Text', 'Overlay selected solutions', ...
        'Value', false);

    uilabel(left, 'Text', 'X');
    vars0 = getVars(sols{1}, varnames);
    ddX = uidropdown(left, 'Items', vars0, 'Value', 't');

    uilabel(left, 'Text', 'Y');
    ddY = uidropdown(left, 'Items', vars0, 'Value', vars0{min(2, numel(vars0))});

    uilabel(left, 'Text', 'Z');
    ddZ = uidropdown(left, ...
        'Items', vars0, ...
        'Value', vars0{min(3, numel(vars0))}, ...
        'Enable', 'off');

    btnPlot = uibutton(left, 'Text', 'Plot', 'ButtonPushedFcn', @(~,~) updatePlot());
    btnInfo = uibutton(left, 'Text', 'Show info in Command Window', ...
        'ButtonPushedFcn', @(~,~) showCurrentInfo());
    btnExport = uibutton(left, 'Text', 'Export current axes', ...
        'ButtonPushedFcn', @(~,~) exportAxes());

    txt = uitextarea(left, ...
        'Editable', 'off', ...
        'Value', {'Select one or more solutions.'});

    uilabel(left, 'Text', '');

    % -----------------------------
    % Callbacks
    % -----------------------------
    lst.ValueChangedFcn       = @(~,~) updateSelectionControls();
    ddDim.ValueChangedFcn     = @(~,~) updateDimControls();
    cbOverlay.ValueChangedFcn = @(~,~) updatePlot();
    ddX.ValueChangedFcn       = @(~,~) updatePlot();
    ddY.ValueChangedFcn       = @(~,~) updatePlot();
    ddZ.ValueChangedFcn       = @(~,~) updatePlot();

    updateSelectionControls();
    updatePlot();

    % =============================
    % Nested functions
    % =============================
    function updateSelectionControls()
        updateDimControls();
        updateInfoBox();
        updatePlot();
    end

    function updateDimControls()
        if strcmp(ddDim.Value, '2D')
            ddZ.Enable = 'off';
        else
            ddZ.Enable = 'on';
        end
        updatePlot();
    end

    function updatePlot()
        idxs = getSelectedSolutionIndices();
        cla(ax);
        hold(ax, 'on');

        try
            if isempty(idxs)
                title(ax, 'No solution selected');
                return;
            end

            if ~cbOverlay.Value && numel(idxs) > 1
                idxs = idxs(1);
            end

            for j = 1:numel(idxs)
                idx = idxs(j);
                sol = sols{idx};

                x = getData(sol, ddX.Value, varnames);
                y = getData(sol, ddY.Value, varnames);

                if strcmp(ddDim.Value, '2D')
                    plot(ax, x, y, 'LineWidth', 1.5, ...
                        'DisplayName', makeLegendLabel(sol, idx));
                    xlabel(ax, makeAxisLabel(ddX.Value), 'Interpreter', 'none');
                    ylabel(ax, makeAxisLabel(ddY.Value), 'Interpreter', 'none');
                    view(ax, 2);
                else
                    z = getData(sol, ddZ.Value, varnames);
                    plot3(ax, x, y, z, 'LineWidth', 1.5, ...
                        'DisplayName', makeLegendLabel(sol, idx));
                    xlabel(ax, makeAxisLabel(ddX.Value), 'Interpreter', 'none');
                    ylabel(ax, makeAxisLabel(ddY.Value), 'Interpreter', 'none');
                    zlabel(ax, makeAxisLabel(ddZ.Value), 'Interpreter', 'none');
                    view(ax, 3);
                end
            end

            grid(ax, 'on');
            box(ax, 'on');

            if numel(idxs) == 1
                sol = sols{idxs(1)};
                title(ax, sprintf('Solution %d  |  LAB = %d  |  BR = %d  |  PT = %d', ...
                    idxs(1), sol.LAB, sol.IBR, sol.PT), 'Interpreter', 'none');
            else
                title(ax, sprintf('%d overlaid solutions', numel(idxs)), 'Interpreter', 'none');
                legend(ax, 'show', 'Location', 'best');
            end

        catch ME
            title(ax, 'Plot error');
            txt.Value = {ME.message};
        end
    end

    function showCurrentInfo()
        idxs = getSelectedSolutionIndices();
        for k = 1:numel(idxs)
            show_s_vars(sols, idxs(k), varnames);
        end
    end

    function exportAxes()
        assignin('base', 's_app_axes', ax);
        assignin('base', 's_app_figure', fig);
        uialert(fig, ...
            'Axes exported to workspace as s_app_axes. Figure exported as s_app_figure.', ...
            'Export complete');
    end

    function updateInfoBox()
        idxs = getSelectedSolutionIndices();

        if isempty(idxs)
            txt.Value = {'No solution selected.'};
            return;
        end

        if numel(idxs) == 1
            idx = idxs(1);
            sol = sols{idx};
            txt.Value = {
                sprintf('Solution index: %d', idx)
                sprintf('LAB:  %d', sol.LAB)
                sprintf('BR:   %d', sol.IBR)
                sprintf('PT:   %d', sol.PT)
                sprintf('NDIM: %d', sol.NDIM)
                sprintf('NTPL: %d', sol.NTPL)
                sprintf('IPS:  %d', sol.IPS)
                sprintf('Available vars: %s', strjoin(getVars(sol, varnames), ', '))
                };
        else
            txt.Value = {
                sprintf('Selected solutions: %d', numel(idxs))
                sprintf('Indices: %s', num2str(idxs))
                sprintf('Overlay mode: %s', string(cbOverlay.Value))
                sprintf('Available vars: %s', strjoin(getVars(sols{1}, varnames), ', '))
                };
        end
    end

    function idxs = getSelectedSolutionIndices()
        selected = lst.Value;
        if isempty(selected)
            idxs = [];
            return;
        end
        if ischar(selected) || isstring(selected)
            selected = cellstr(selected);
        end

        idxs = zeros(1, numel(selected));
        for ii = 1:numel(selected)
            idxs(ii) = find(strcmp(selected{ii}, items), 1, 'first');
        end
        idxs = idxs(~isnan(idxs) & idxs >= 1);
    end
end


% ==========================================
% Local helper functions
% ==========================================
function items = makeSolutionItems(sols)
    n = numel(sols);
    items = cell(n,1);
    for i = 1:n
        s = sols{i};
        items{i} = sprintf('%d | LAB=%d | BR=%d | PT=%d', i, s.LAB, s.IBR, s.PT);
    end
end

function vars = getVars(sol, varnames)
    validate_varnames(varnames, sol.NDIM);
    vars = [{'t'}, varnames(:)'];
end

function data = getData(sol, varname, varnames)
    varname = char(string(varname));

    if strcmpi(varname, 't')
        data = sol.t(:);
        return;
    end

    idx = find(strcmp(varname, varnames), 1, 'first');
    if isempty(idx)
        error('Unknown variable "%s".', varname);
    end

    if idx < 1 || idx > size(sol.U, 2)
        error('Variable %s is out of range for this solution.', varname);
    end

    data = sol.U(:, idx);
end

function label = makeAxisLabel(varname)
    label = char(string(varname));
end

function txt = makeLegendLabel(sol, idx)
    txt = sprintf('%d | LAB=%d | BR=%d', idx, sol.LAB, sol.IBR);
end

function validate_varnames(varnames, ndim)
    if ~iscell(varnames) || numel(varnames) ~= ndim
        error('varnames must be a cell array with exactly %d entries.', ndim);
    end
    if ~all(cellfun(@(s) ischar(s) || isstring(s), varnames))
        error('All entries in varnames must be text.');
    end
end