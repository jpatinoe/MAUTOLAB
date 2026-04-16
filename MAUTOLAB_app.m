function MAUTOLAB_app()
% MAUTOLAB_APP  Master launcher app for MAUTOLAB.
%
% This app loads AUTO output associated with a base name, e.g.
%
%   lor  ->  b.lor, d.lor, s.lor
%
% using MAUTOLAB.m, and then provides buttons to launch the
% specialised apps for:
%   - bifurcation diagrams
%   - solutions
%   - diagnostics / multipliers
%
% The specialised apps are assumed to accept already-loaded data:
%   plotbd_app(data.bif_diagram)
%   plot_s_app(data.solutions)
%   d_plot_app(data.diagnostics)
%
% If your current app names or interfaces differ, modify the three
% launcher callbacks near the end of this file.

    % ------------------------------------------------------------
    % Ensure MAUTOLAB folders are on path
    % ------------------------------------------------------------
    rootDir = fileparts(mfilename('fullpath'));
    addpath(rootDir);
    addpath(fullfile(rootDir, 'b_files'));
    addpath(fullfile(rootDir, 'd_files'));
    addpath(fullfile(rootDir, 's_files'));

    % ------------------------------------------------------------
    % App state
    % ------------------------------------------------------------
    app = struct();
    app.data = [];
    app.baseName = '';
    app.rootDir = rootDir;

    % ------------------------------------------------------------
    % Main figure
    % ------------------------------------------------------------
    fig = uifigure( ...
        'Name', 'MAUTOLAB', ...
        'Position', [100 100 560 420]);

    fig.UserData = app;

    % ------------------------------------------------------------
    % Title
    % ------------------------------------------------------------
    lblTitle = uilabel(fig, ...
        'Text', 'MAUTOLAB', ...
        'FontSize', 20, ...
        'FontWeight', 'bold', ...
        'Position', [25 380 200 30]);

    lblSubtitle = uilabel(fig, ...
        'Text', 'Unified launcher for AUTO-07p readers and plotting apps', ...
        'FontSize', 11, ...
        'Position', [25 360 350 22]);

    % ------------------------------------------------------------
    % Input row
    % ------------------------------------------------------------
    lblBase = uilabel(fig, ...
        'Text', 'Base filename:', ...
        'Position', [25 320 100 22]);

    edtBase = uieditfield(fig, 'text', ...
        'Position', [125 320 180 22], ...
        'Value', 'lor');

    btnLoad = uibutton(fig, 'push', ...
        'Text', 'Load', ...
        'Position', [320 320 90 24], ...
        'ButtonPushedFcn', @onLoad);

    btnClear = uibutton(fig, 'push', ...
        'Text', 'Clear', ...
        'Position', [420 320 90 24], ...
        'ButtonPushedFcn', @onClear);

    % ------------------------------------------------------------
    % Status panel
    % ------------------------------------------------------------
    pnlStatus = uipanel(fig, ...
        'Title', 'Status', ...
        'Position', [25 175 485 125]);

    txtStatus = uitextarea(pnlStatus, ...
        'Position', [10 10 465 85], ...
        'Editable', 'off', ...
        'Value', {'No data loaded.'});

    % ------------------------------------------------------------
    % Action panel
    % ------------------------------------------------------------
    pnlActions = uipanel(fig, ...
        'Title', 'Open plotting apps', ...
        'Position', [25 35 485 120]);

    btnBif = uibutton(pnlActions, 'push', ...
        'Text', 'Bifurcation diagrams', ...
        'Position', [20 55 135 35], ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onOpenBif);

    btnSol = uibutton(pnlActions, 'push', ...
        'Text', 'Solutions', ...
        'Position', [175 55 135 35], ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onOpenSol);

    btnDiag = uibutton(pnlActions, 'push', ...
        'Text', 'Diagnostics / multipliers', ...
        'Position', [330 55 135 35], ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onOpenDiag);

    btnOpenAll = uibutton(pnlActions, 'push', ...
        'Text', 'Open all available', ...
        'Position', [160 12 165 28], ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onOpenAll);

    % ------------------------------------------------------------
    % Nested callbacks
    % ------------------------------------------------------------
    function onLoad(~, ~)
        baseName = strtrim(edtBase.Value);

        if isempty(baseName)
            uialert(fig, 'Please enter a base filename, e.g. lor', 'Missing input');
            return;
        end

        try
            data = MAUTOLAB(baseName);
        catch ME
            uialert(fig, sprintf('Failed to load data:\n\n%s', ME.message), ...
                'Load error');
            return;
        end

        app = fig.UserData;
        app.data = data;
        app.baseName = baseName;
        fig.UserData = app;

        updateStatus();
        updateButtons();
    end

    function onClear(~, ~)
        app = fig.UserData;
        app.data = [];
        app.baseName = '';
        fig.UserData = app;

        txtStatus.Value = {'No data loaded.'};
        btnBif.Enable = 'off';
        btnSol.Enable = 'off';
        btnDiag.Enable = 'off';
        btnOpenAll.Enable = 'off';
    end

    function onOpenBif(~, ~)
        app = fig.UserData;
        if isempty(app.data) || ~isfield(app.data, 'bif_diagram')
            return;
        end

        try
            plotbd_app(app.data.bif_diagram);
        catch ME
            uialert(fig, sprintf(['Could not open bifurcation app.\n\n' ...
                'Expected call:\nplotbd_app(data.bif_diagram)\n\nError:\n%s'], ...
                ME.message), 'Bifurcation app error');
        end
    end

    function onOpenSol(~, ~)
        app = fig.UserData;
        if isempty(app.data) || ~isfield(app.data, 'solutions')
            return;
        end

        try
            plot_s_app(app.data.solutions);
        catch ME
            uialert(fig, sprintf(['Could not open solutions app.\n\n' ...
                'Expected call:\nplot_s_app(data.solutions)\n\nError:\n%s'], ...
                ME.message), 'Solutions app error');
        end
    end

    function onOpenDiag(~, ~)
        app = fig.UserData;
        if isempty(app.data) || ~isfield(app.data, 'diagnostics')
            return;
        end

        try
            d_plot_app(app.data.diagnostics);
        catch ME
            uialert(fig, sprintf(['Could not open diagnostics app.\n\n' ...
                'Expected call:\nd_plot_app(data.diagnostics)\n\nError:\n%s'], ...
                ME.message), 'Diagnostics app error');
        end
    end

    function onOpenAll(~, ~)
        if strcmp(btnBif.Enable, 'on')
            onOpenBif();
        end
        if strcmp(btnSol.Enable, 'on')
            onOpenSol();
        end
        if strcmp(btnDiag.Enable, 'on')
            onOpenDiag();
        end
    end

    % ------------------------------------------------------------
    % Helpers
    % ------------------------------------------------------------
    function updateButtons()
        app = fig.UserData;

        hasData = ~isempty(app.data);
        hasB = hasData && isfield(app.data, 'bif_diagram');
        hasS = hasData && isfield(app.data, 'solutions');
        hasD = hasData && isfield(app.data, 'diagnostics');

        btnBif.Enable = onOff(hasB);
        btnSol.Enable = onOff(hasS);
        btnDiag.Enable = onOff(hasD);
        btnOpenAll.Enable = onOff(hasB || hasS || hasD);
    end

    function updateStatus()
        app = fig.UserData;

        if isempty(app.data)
            txtStatus.Value = {'No data loaded.'};
            return;
        end

        lines = {};
        lines{end+1} = sprintf('Base name: %s', app.baseName);
        lines{end+1} = ' ';
        lines{end+1} = statusLine(app.data, 'bif_diagram', 'Bifurcation diagram');
        lines{end+1} = statusLine(app.data, 'solutions', 'Solutions');
        lines{end+1} = statusLine(app.data, 'diagnostics', 'Diagnostics');
        lines{end+1} = ' ';

        % Optional quick summary
        if isfield(app.data, 'bif_diagram')
            try
                nBranches = numel(app.data.bif_diagram);
                lines{end+1} = sprintf('Bifurcation branches: %d', nBranches);
            catch
            end
        end

        if isfield(app.data, 'diagnostics')
            try
                nDiag = numel(app.data.diagnostics);
                lines{end+1} = sprintf('Diagnostic entries: %d', nDiag);
            catch
            end
        end

        txtStatus.Value = lines;
    end

    function s = statusLine(data, fieldName, label)
        if isfield(data, fieldName)
            s = sprintf('%s: loaded', label);
        else
            s = sprintf('%s: not available', label);
        end
    end

    function val = onOff(tf)
        if tf
            val = 'on';
        else
            val = 'off';
        end
    end
end