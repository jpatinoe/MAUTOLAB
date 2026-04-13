function d_plot_app(diagnostics)
% D_PLOT_APP   App-like viewer for d-file spectral diagnostics.
%
%   d_plot_app(diagnostics)

    BT = read_d_table(diagnostics);
    if isempty(fieldnames(BT))
        error('d_plot_app:noData', 'No diagnostic data available.');
    end

    fig = uifigure( ...
        'Name', 'd-file spectrum viewer', ...
        'Position', [100 100 1250 760]);

    left = uipanel(fig, ...
        'Title', 'Options', ...
        'Position', [10 10 300 740]);

    right = uipanel(fig, ...
        'Title', 'Plot', ...
        'Position', [320 10 920 740]);

    ax = uiaxes(right, 'Position', [35 120 850 585]);
    grid(ax, 'on');
    hold(ax, 'on');

    infoLbl = uilabel(right, ...
        'Position', [35 100 850 22], ...
        'HorizontalAlignment', 'left', ...
        'Text', '');
    
    sliderLbl = uilabel(right, ...
        'Position', [35 75 850 18], ...
        'Text', '', ...
        'Visible', 'off');
    
    slider = uislider(right, ...
        'Position', [60 60 800 3], ...
        'Visible', 'off');
    
    warnLbl = uilabel(right, ...
        'Position', [35 10 850 22], ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.75 0 0], ...
        'FontWeight', 'bold', ...
        'Text', '');

    y = 675; dy = 34; w1 = 110; w2 = 150; x1 = 15; x2 = 135;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Plot type');
    plotTypeDD = uidropdown(left, ...
        'Position', [x2 y w2 22], ...
        'Items', {'Spectrum curves','Complex slider'}, ...
        'Value', 'Spectrum curves');
    y = y - dy;

    branch_fields = fieldnames(BT);
    branch_vals = strings(numel(branch_fields),1);
    for k = 1:numel(branch_fields)
        Ttmp = BT.(branch_fields{k});
        branch_vals(k) = sprintf('%d', Ttmp.Branch(1));
    end

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Branch');
    branchDD = uidropdown(left, ...
        'Position', [x2 y w2 22], ...
        'Items', cellstr(branch_vals), ...
        'Value', char(branch_vals(1)));
    y = y - dy;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Segment');
    segmentDD = uidropdown(left, ...
        'Position', [x2 y w2 22], ...
        'Items', {'1'}, ...
        'Value', '1');
    y = y - dy;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Subpoints');
    subpointDD = uidropdown(left, ...
        'Position', [x2 y w2 22], ...
        'Items', {'max','all'}, ...
        'Value', 'max');
    y = y - dy - 8;

    curveHdr = uilabel(left, ...
        'Position', [x1 y 250 22], ...
        'Text', 'Spectrum curves options', ...
        'FontWeight', 'bold'); %#ok<NASGU>
    y = y - dy;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Quantity');
    quantityDD = uidropdown(left, ...
        'Position', [x2 y w2 22], ...
        'Items', {'measure','abs','real','imag'}, ...
        'Value', 'measure');
    y = y - dy;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Index');
    indexEF = uieditfield(left, 'text', ...
        'Position', [x2 y w2 22], ...
        'Value', '');
    y = y - dy;

    logCB = uicheckbox(left, ...
        'Position', [x1 y 220 22], ...
        'Text', 'Log y-scale', ...
        'Value', false);
    y = y - dy - 8;

    complexHdr = uilabel(left, ...
        'Position', [x1 y 250 22], ...
        'Text', 'Complex slider options', ...
        'FontWeight', 'bold'); %#ok<NASGU>
    y = y - dy;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'X limits');
    xlimMinEF = uieditfield(left, 'numeric', ...
        'Position', [x2 y 70 22], 'Value', -1.5);
    xlimMaxEF = uieditfield(left, 'numeric', ...
        'Position', [x2+80 y 70 22], 'Value', 1.5);
    y = y - dy;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Y limits');
    ylimMinEF = uieditfield(left, 'numeric', ...
        'Position', [x2 y 70 22], 'Value', -1.5);
    ylimMaxEF = uieditfield(left, 'numeric', ...
        'Position', [x2+80 y 70 22], 'Value', 1.5);
    y = y - dy;

    uilabel(left, 'Position', [x1 y w1 22], 'Text', 'Tolerance');
    tolEF = uieditfield(left, 'numeric', ...
        'Position', [x2 y w2 22], ...
        'Value', 1e-3);
    y = y - dy - 10;

    refreshBtn = uibutton(left, ...
        'Position', [x1 y 120 28], ...
        'Text', 'Refresh plot', ...
        'ButtonPushedFcn', @(~,~) refreshPlot()); %#ok<NASGU>

    plotTypeDD.ValueChangedFcn = @(~,~) refreshPlot();
    branchDD.ValueChangedFcn   = @(~,~) onBranchOrSubpointChange();
    subpointDD.ValueChangedFcn = @(~,~) onBranchOrSubpointChange();
    segmentDD.ValueChangedFcn  = @(~,~) refreshPlot();
    quantityDD.ValueChangedFcn = @(~,~) refreshPlot();
    logCB.ValueChangedFcn      = @(~,~) refreshPlot();
    indexEF.ValueChangedFcn    = @(~,~) refreshPlot();
    xlimMinEF.ValueChangedFcn  = @(~,~) refreshPlot();
    xlimMaxEF.ValueChangedFcn  = @(~,~) refreshPlot();
    ylimMinEF.ValueChangedFcn  = @(~,~) refreshPlot();
    ylimMaxEF.ValueChangedFcn  = @(~,~) refreshPlot();
    tolEF.ValueChangedFcn      = @(~,~) refreshPlot();

    slider.ValueChangingFcn = @(~,evt) redrawComplex(max(1, round(evt.Value)));
    slider.ValueChangedFcn  = @(~,evt) redrawComplex(max(1, round(evt.Value)));

    updateSegmentItems();
    refreshPlot();

    function onBranchOrSubpointChange()
        updateSegmentItems();
        refreshPlot();
    end

    function updateSegmentItems()
        [~, segments] = getSelectedSegments();
        nseg = numel(segments);
        items = arrayfun(@num2str, 1:max(1,nseg), 'UniformOutput', false);
        segmentDD.Items = items;
        if ~ismember(segmentDD.Value, items)
            segmentDD.Value = items{1};
        end
    end

    function [Tbranch, segments] = getSelectedSegments()
        br = str2double(branchDD.Value);
        field = sprintf('B%d', br);
        Tbranch = BT.(field);
        Tbranch = local_reduce_subpoints(Tbranch, subpointDD.Value);
        segments = local_split_segments(Tbranch);
    end

    function idxRequested = parseIndexField()
        txt = strtrim(indexEF.Value);
        if isempty(txt)
            idxRequested = NaN;
            return;
        end
        idxRequested = str2double(txt);
        if isnan(idxRequested) || ~isfinite(idxRequested) || idxRequested < 1
            idxRequested = NaN;
        else
            idxRequested = round(idxRequested);
        end
    end

    function resetAxes()
        cla(ax, 'reset');
        hold(ax, 'on');
        grid(ax, 'on');
        warnLbl.Text = '';
        infoLbl.Text = '';
    end

    function refreshPlot()
        resetAxes();
        delete(findall(ax, 'Tag', 'OutArrow'));

        [~, segments] = getSelectedSegments();
        segIdx = str2double(segmentDD.Value);
        if isempty(segments) || segIdx > numel(segments)
            slider.Visible = 'off';
            sliderLbl.Visible = 'off';
            title(ax, 'No data');
            return;
        end
        Ts = segments{segIdx};

        if ismember('SpectrumType', Ts.Properties.VariableNames)
            specName = char(Ts.SpectrumType(1));
        else
            specName = 'Multiplier';
        end

        switch plotTypeDD.Value
            case 'Spectrum curves'
                slider.Visible = 'off';
                sliderLbl.Visible = 'off';
                drawSpectrumCurves(Ts, specName, segIdx);
            case 'Complex slider'
                slider.Visible = 'on';
                sliderLbl.Visible = 'on';
                setupComplexSlider(Ts, specName, segIdx);
                redrawComplex(round(slider.Value));
        end
    end

    function drawSpectrumCurves(Ts, specName, segIdx)
        isEig = strcmpi(specName, 'Eigenvalue');

        measureCols = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Measure_'));
        absCols     = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Abs_'));
        reCols      = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Re_'));
        imCols      = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Im_'));

        switch quantityDD.Value
            case 'measure'
                yCols = measureCols;
                ylab = ternary(isEig, '|Re(\lambda)|', '|\mu|');
            case 'abs'
                yCols = absCols;
                ylab = ternary(isEig, '|\lambda|', '|\mu|');
            case 'real'
                yCols = reCols;
                ylab = 'Real part';
            case 'imag'
                yCols = imCols;
                ylab = 'Imaginary part';
        end

        nSpec = numel(yCols);
        if nSpec == 0
            title(ax, 'No spectral columns available');
            return;
        end

        idxRequested = parseIndexField();
        if isnan(idxRequested)
            idxList = 1:nSpec;
        else
            if idxRequested < 1 || idxRequested > nSpec
                title(ax, sprintf('Requested index %d is out of range', idxRequested));
                return;
            end
            idxList = idxRequested;
        end

        xLocal = (1:height(Ts)).';
        xPoint = Ts.Point;
        C = lines(max(12, nSpec));

        ymin = inf; ymax = -inf;
        for kk = 1:numel(idxList)
            e = idxList(kk);
            ydat = Ts.(yCols{e});
            plot(ax, xLocal, ydat, '-o', ...
                'Color', C(e,:), ...
                'MarkerFaceColor', C(e,:), ...
                'MarkerSize', 3.5, ...
                'LineWidth', 1.2, ...
                'DisplayName', local_curve_label(quantityDD.Value, specName, e));
            good = isfinite(ydat);
            if any(good)
                ymin = min(ymin, min(ydat(good)));
                ymax = max(ymax, max(ydat(good)));
            end
        end

        if strcmp(quantityDD.Value, 'abs') && ~isEig
            yline(ax, 1, '--', 'Color', [0.70 0.20 0.20], 'HandleVisibility', 'off');
            ymin = min(ymin, 1);
            ymax = max(ymax, 1);
        elseif strcmp(quantityDD.Value, 'measure') && ~isEig
            yline(ax, 1, '--', 'Color', [0.70 0.20 0.20], 'HandleVisibility', 'off');
            ymin = min(ymin, 1);
            ymax = max(ymax, 1);
        elseif strcmp(quantityDD.Value, 'real') || (strcmp(quantityDD.Value, 'measure') && isEig)
            yline(ax, 0, '--', 'Color', [0.70 0.20 0.20], 'HandleVisibility', 'off');
            ymin = min(ymin, 0);
            ymax = max(ymax, 0);
        end

        if ismember('Stable', Ts.Properties.VariableNames)
            stable = Ts.Stable;
            idxchg = find(diff(stable) ~= 0 & ~isnan(diff(stable)));
            for ii = idxchg(:)'
                xline(ax, xLocal(ii+1), ':', ...
                    'Color', [0.45 0.45 0.45], ...
                    'LineWidth', 0.8, ...
                    'HandleVisibility', 'off');
            end
        end

        set(ax, 'XTick', xLocal, 'XTickLabel', string(xPoint));
        set(ax, 'YScale', ternary(logCB.Value, 'log', 'linear'));
        xlim(ax, [0.5, height(Ts)+0.5]);

        if isfinite(ymin) && isfinite(ymax)
            if strcmp(ax.YScale, 'log')
                goodmin = max(ymin, eps);
                goodmax = max(ymax, goodmin*10);
                ax.YLim = [0.9*goodmin, 1.1*goodmax];
            else
                if abs(ymax - ymin) < 1e-12
                    pad = max(1, abs(ymax))*0.1;
                else
                    pad = 0.08*(ymax - ymin);
                end
                ax.YLim = [ymin - pad, ymax + pad];
            end
        end

        xlabel(ax, 'Local continuation index (tick labels = AUTO point)');
        ylabel(ax, ylab, 'Interpreter', 'tex');
        title(ax, sprintf('Branch %s, segment %d — %s', branchDD.Value, segIdx, specName), ...
            'Interpreter', 'none');
        legend(ax, 'Location', 'best');
        infoLbl.Text = sprintf('Branch %s | Segment %d | %d row(s)', ...
            branchDD.Value, segIdx, height(Ts));
    end

    function setupComplexSlider(Ts, specName, segIdx)
        reCols = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Re_'));
        imCols = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Im_'));
        nSpec  = min(numel(reCols), numel(imCols));

        idxRequested = parseIndexField();
        if isnan(idxRequested)
            idxList = 1:nSpec;
        else
            if idxRequested < 1 || idxRequested > nSpec
                idxList = [];
            else
                idxList = idxRequested;
            end
        end

        S.Ts = Ts;
        S.specName = specName;
        S.segIdx = segIdx;
        S.reCols = reCols;
        S.imCols = imCols;
        S.idxList = idxList;
        setappdata(fig, 'ComplexState', S);

        slider.Limits = [1 height(Ts)];
        slider.Value = 1;
        slider.MajorTicks = local_ticks(height(Ts));
        sliderLbl.Text = 'Slider: local continuation index';
    end

    function redrawComplex(idx)
        if ~strcmp(plotTypeDD.Value, 'Complex slider')
            return;
        end

        S = getappdata(fig, 'ComplexState');
        if isempty(S) || isempty(S.idxList)
            resetAxes();
            title(ax, 'Requested index is out of range');
            return;
        end

        Ts = S.Ts;
        specName = S.specName;
        segIdx = S.segIdx;
        reCols = S.reCols;
        imCols = S.imCols;
        idxList = S.idxList;
        isMultiplier = strcmpi(specName, 'Multiplier');

        resetAxes();
        axis(ax, 'equal');

        ax.XLim = sort([xlimMinEF.Value, xlimMaxEF.Value]);
        ax.YLim = sort([ylimMinEF.Value, ylimMaxEF.Value]);
        xline(ax, 0, ':', 'Color', [0.7 0.7 0.7], 'HandleVisibility', 'off');
        yline(ax, 0, ':', 'Color', [0.7 0.7 0.7], 'HandleVisibility', 'off');

        th = linspace(0, 2*pi, 500);
        plot(ax, cos(th), sin(th), 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');

        zVals = [];
        for kk = 1:numel(idxList)
            e = idxList(kk);
            re = Ts.(reCols{e})(idx);
            im = Ts.(imCols{e})(idx);
            if ~(isnan(re) || isnan(im))
                zVals(end+1) = complex(re, im); %#ok<AGROW>
            end
        end

        scatter(ax, real(zVals), imag(zVals), 70, ...
            'MarkerFaceColor', [0 0.4470 0.7410], ...
            'MarkerEdgeColor', [0 0.4470 0.7410]);

        xlimFixed = ax.XLim;
        ylimFixed = ax.YLim;
        nOut = 0;
        for j = 1:numel(zVals)
            z = zVals(j);
            if real(z) < xlimFixed(1) || real(z) > xlimFixed(2) || ...
               imag(z) < ylimFixed(1) || imag(z) > ylimFixed(2)
                nOut = nOut + 1;
                local_draw_out_arrow(ax, z, xlimFixed, ylimFixed);
            end
        end

        msg = "";
        if isMultiplier
            distToOne = abs(zVals - 1);
            if isempty(zVals) || all(distToOne > tolEF.Value)
                msg = "Warning: no multiplier detected near (1,0) (possible accuracy issue).";
            end
        end
        if nOut > 0
            if strlength(msg) > 0
                msg = msg + "  ";
            end
            msg = msg + sprintf('%d point(s) lie outside the displayed window.', nOut);
        end

        warnLbl.Text = char(msg);
        title(ax, sprintf('%s at point %d, subpoint %d', ...
            specName, Ts.Point(idx), local_get_subpoint(Ts, idx)));
        xlabel(ax, 'Re');
        ylabel(ax, 'Im');
        infoLbl.Text = sprintf('Branch %s | Segment %d | Local index %d/%d | AUTO point %d | Subpoint %d', ...
            branchDD.Value, segIdx, idx, height(Ts), Ts.Point(idx), local_get_subpoint(Ts, idx));
    end
end

function T = local_reduce_subpoints(Tin, mode)
    T = Tin;
    if ~ismember('Subpoint', T.Properties.VariableNames)
        return;
    end
    if strcmpi(mode, 'all')
        return;
    end
    pts = T.Point;
    keep = false(height(T), 1);
    [~, ~, ic] = unique(pts, 'stable');
    for k = 1:max(ic)
        idx = find(ic == k);
        [~, j] = max(T.Subpoint(idx));
        keep(idx(j)) = true;
    end
    T = T(keep, :);
end

function segments = local_split_segments(T)
    if isempty(T)
        segments = {};
        return;
    end
    if height(T) == 1
        segments = {T};
        return;
    end
    pts = T.Point;
    cut = [1; find(diff(pts) <= 0) + 1; height(T) + 1];
    segments = cell(numel(cut)-1, 1);
    for k = 1:numel(cut)-1
        segments{k} = T(cut(k):cut(k+1)-1, :);
    end
end

function ticks = local_ticks(n)
    if n <= 10
        ticks = 1:n;
    else
        step = ceil(n / 8);
        ticks = unique([1:step:n, n]);
    end
end

function s = local_curve_label(quantity, specName, idx)
    isEig = strcmpi(specName, 'Eigenvalue');
    switch quantity
        case 'measure'
            s = ternary(isEig, sprintf('|Re(\\lambda_%d)|', idx), sprintf('|\\mu_%d|', idx));
        case 'abs'
            s = ternary(isEig, sprintf('|\\lambda_%d|', idx), sprintf('|\\mu_%d|', idx));
        case 'real'
            s = ternary(isEig, sprintf('Re(\\lambda_%d)', idx), sprintf('Re(\\mu_%d)', idx));
        case 'imag'
            s = ternary(isEig, sprintf('Im(\\lambda_%d)', idx), sprintf('Im(\\mu_%d)', idx));
    end
end

function sp = local_get_subpoint(T, idx)
    if ismember('Subpoint', T.Properties.VariableNames)
        sp = T.Subpoint(idx);
    else
        sp = 1;
    end
end

function local_draw_out_arrow(ax, z, xlimFixed, ylimFixed)
    xr = real(z);
    yi = imag(z);
    cx = mean(xlimFixed);
    cy = mean(ylimFixed);
    dx = xr - cx;
    dy = yi - cy;
    if abs(dx) < eps && abs(dy) < eps
        return;
    end

    tx = inf; ty = inf;
    if abs(dx) > eps
        if dx > 0
            tx = (xlimFixed(2) - cx) / dx;
        else
            tx = (xlimFixed(1) - cx) / dx;
        end
    end
    if abs(dy) > eps
        if dy > 0
            ty = (ylimFixed(2) - cy) / dy;
        else
            ty = (ylimFixed(1) - cy) / dy;
        end
    end

    t = min([tx, ty]);
    x0 = cx + 0.90 * t * dx;
    y0 = cy + 0.90 * t * dy;
    x1 = cx + 0.98 * t * dx;
    y1 = cy + 0.98 * t * dy;

    quiver(ax, x0, y0, x1-x0, y1-y0, 0, ...
        'Color', [0.35 0.35 0.35], ...
        'LineWidth', 1.5, ...
        'MaxHeadSize', 0.9, ...
        'AutoScale', 'off', ...
        'Tag', 'OutArrow', ...
        'HandleVisibility', 'off');
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
