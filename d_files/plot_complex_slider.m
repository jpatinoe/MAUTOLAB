function plot_complex_slider(diagnostics, varargin)
% PLOT_COMPLEX_SLIDER   Interactive complex-plane viewer for spectra.
%
%   plot_complex_slider(diagnostics)
%   plot_complex_slider(diagnostics, 'branch', 2)
%   plot_complex_slider(diagnostics, 'branch', 2, 'segment', 1)
%   plot_complex_slider(diagnostics, 'branch', 2, 'subpointmode', 'max')
%
%   This tool shows the eigenvalues / multipliers at one location at a time
%   in the complex plane, with a slider to move along the branch segment.
%
%   Inputs
%   ------
%   diagnostics   struct array returned by read_d_auto
%
%   Options
%   -------
%   'branch'        Branch number to inspect. Default: first available branch.
%   'segment'       Local segment number within the branch. Default: 1.
%                   A new segment starts whenever Point does not increase.
%   'subpointmode'  'max' (default) or 'all'
%                   'max' keeps only the largest subpoint for each point.
%   'xlim'          Two-element vector for fixed X limits. Default [-1.5 1.5]
%   'ylim'          Two-element vector for fixed Y limits. Default [-1.5 1.5]
%   'tol'           Tolerance for warnings. Default 1e-3
%
%   Notes
%   -----
%   - All dots are plotted in the same colour.
%   - The unit circle is always shown.
%   - If points lie outside the displayed window, arrows indicate the
%     direction to those hidden points.
%   - For multiplier data, a warning is shown when no multiplier is close
%     to (1,0), because theory expects one Floquet multiplier near 1.

    p = inputParser;
    addParameter(p, 'branch', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    addParameter(p, 'segment', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'subpointmode', 'max', @(x) ismember(lower(x), {'max','all'}));
    addParameter(p, 'xlim', [-1.5 1.5], @(x) isnumeric(x) && numel(x) == 2);
    addParameter(p, 'ylim', [-1.5 1.5], @(x) isnumeric(x) && numel(x) == 2);
    addParameter(p, 'tol', 1e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, varargin{:});

    branch_sel   = p.Results.branch;
    segment_sel  = p.Results.segment;
    subpointmode = lower(p.Results.subpointmode);
    xlim_fixed   = p.Results.xlim(:).';
    ylim_fixed   = p.Results.ylim(:).';
    tol          = p.Results.tol;

    BT = read_d_table(diagnostics);
    if isempty(fieldnames(BT))
        error('plot_complex_slider:noData', 'No diagnostic data available.');
    end

    branch_names = fieldnames(BT);
    branch_ids = zeros(numel(branch_names),1);
    for k = 1:numel(branch_names)
        Ttmp = BT.(branch_names{k});
        branch_ids(k) = Ttmp.Branch(1);
    end

    if isempty(branch_sel)
        branch_sel = branch_ids(1);
    end

    branch_field = sprintf('B%d', branch_sel);
    if ~isfield(BT, branch_field)
        error('plot_complex_slider:branchNotFound', ...
            'Branch %d was not found.', branch_sel);
    end

    T = BT.(branch_field);
    T = local_reduce_subpoints(T, subpointmode);
    segments = local_split_segments(T);

    if segment_sel > numel(segments)
        error('plot_complex_slider:segmentNotFound', ...
            'Branch %d has %d segment(s); requested segment %d.', ...
            branch_sel, numel(segments), segment_sel);
    end

    Ts = segments{segment_sel};
    if isempty(Ts) || height(Ts) == 0
        error('plot_complex_slider:emptySegment', 'Selected segment is empty.');
    end

    re_cols = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Re_'));
    im_cols = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Im_'));
    n_spec  = min(numel(re_cols), numel(im_cols));
    if n_spec == 0
        error('plot_complex_slider:noSpectrum', ...
            'Selected segment has no spectrum columns.');
    end

    if ismember('SpectrumType', Ts.Properties.VariableNames)
        spec_name = char(Ts.SpectrumType(1));
    else
        spec_name = 'Multiplier';
    end
    is_multiplier = strcmpi(spec_name, 'Multiplier');

    pts = Ts.Point;
    if ismember('Subpoint', Ts.Properties.VariableNames)
        sub = Ts.Subpoint;
    else
        sub = ones(height(Ts),1);
    end

    % Prepare spectrum matrix as cell array for convenience
    Z = cell(height(Ts),1);
    for i = 1:height(Ts)
        z = NaN(1, n_spec);
        for j = 1:n_spec
            re = Ts.(re_cols{j})(i);
            im = Ts.(im_cols{j})(i);
            if ~(isnan(re) || isnan(im))
                z(j) = complex(re, im);
            end
        end
        Z{i} = z(~isnan(z));
    end

    % --- UI figure and axes ---
    f = uifigure('Name', sprintf('Branch %d, segment %d — %s slider', ...
        branch_sel, segment_sel, spec_name), ...
        'Position', [100 100 760 650]);

    ax = uiaxes(f, 'Position', [60 150 640 450]);
    hold(ax, 'on');
    axis(ax, 'equal');
    ax.XLim = xlim_fixed;
    ax.YLim = ylim_fixed;
    grid(ax, 'on');
    xlabel(ax, 'Re');
    ylabel(ax, 'Im');

    % Always show unit circle
    th = linspace(0, 2*pi, 500);
    plot(ax, cos(th), sin(th), 'k--', 'LineWidth', 1.0, ...
        'DisplayName', 'Unit circle');

    % Axes cross
    xline(ax, 0, ':', 'Color', [0.7 0.7 0.7], 'HandleVisibility', 'off');
    yline(ax, 0, ':', 'Color', [0.7 0.7 0.7], 'HandleVisibility', 'off');

    % Same colour for all dots
    dot_color = [0 0.4470 0.7410];
    sc = scatter(ax, NaN, NaN, 70, ...
        'MarkerFaceColor', dot_color, ...
        'MarkerEdgeColor', dot_color);

    % Text areas
    info_lbl = uilabel(f, ...
        'Position', [60 615 640 22], ...
        'HorizontalAlignment', 'left', ...
        'Text', '');

    warn_lbl = uilabel(f, ...
        'Position', [60 120 640 22], ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.75 0 0], ...
        'FontWeight', 'bold', ...
        'Text', '');

    hint_lbl = uilabel(f, ...
        'Position', [60 95 640 20], ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.35 0.35 0.35], ...
        'Text', 'Arrows indicate spectral points outside the displayed window.');

    % Slider
    nrows = height(Ts);
    sld = uislider(f, ...
        'Limits', [1 nrows], ...
        'Value', 1, ...
        'MajorTicks', local_ticks(nrows), ...
        'MinorTicks', [], ...
        'Position', [80 60 600 3]);

    sld.ValueChangingFcn = @(src,evt) redraw(max(1, min(nrows, round(evt.Value))));
    sld.ValueChangedFcn  = @(src,evt) redraw(max(1, min(nrows, round(evt.Value))));

    % Initial draw
    redraw(1);

    function redraw(idx)
        z_vals = Z{idx};

        sc.XData = real(z_vals);
        sc.YData = imag(z_vals);

        % Delete previous helper graphics
        delete(findall(ax, 'Tag', 'OutArrow'));
        delete(findall(ax, 'Tag', 'OverlayText'));

        % Title/info
        title(ax, sprintf('%s at point %d, subpoint %d', spec_name, pts(idx), sub(idx)));
        info_lbl.Text = sprintf('Branch %d | Segment %d | Local index %d/%d | AUTO point %d | Subpoint %d', ...
            branch_sel, segment_sel, idx, nrows, pts(idx), sub(idx));

        % Mark outside-window points with arrows
        n_out = 0;
        for j = 1:numel(z_vals)
            z = z_vals(j);
            xr = real(z);
            yi = imag(z);
            if xr < xlim_fixed(1) || xr > xlim_fixed(2) || yi < ylim_fixed(1) || yi > ylim_fixed(2)
                n_out = n_out + 1;
                local_draw_out_arrow(ax, z, xlim_fixed, ylim_fixed);
            end
        end

        % Stability warnings
        msg = "";
        
        if is_multiplier
            % --- Numerical consistency check ---
            dist_to_one = abs(z_vals - 1);
            if isempty(z_vals) || all(dist_to_one > tol)
                msg = "Warning: no multiplier detected near (1,0) (possible accuracy issue).";
            end
        
        end
        
        if n_out > 0
            if strlength(msg) > 0
                msg = msg + "  ";
            end
            msg = msg + sprintf('%d point(s) lie outside the displayed window.', n_out);
        end

        warn_lbl.Text = char(msg);
    end
end


function T = local_reduce_subpoints(Tin, mode)
% Keep either all rows or only the largest subpoint for each point.

    T = Tin;

    if ~ismember('Subpoint', T.Properties.VariableNames)
        return;
    end

    if strcmp(mode, 'all')
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
% Split branch table into local monotone point sequences.
% New segment when point number does not increase.

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
% Reasonable major ticks for the slider.
    if n <= 10
        ticks = 1:n;
    else
        step = ceil(n / 8);
        ticks = unique([1:step:n, n]);
    end
end


function local_draw_out_arrow(ax, z, xlim_fixed, ylim_fixed)
% Draw an arrow from the nearest boundary in the direction of z.

    xr = real(z);
    yi = imag(z);

    cx = mean(xlim_fixed);
    cy = mean(ylim_fixed);

    dx = xr - cx;
    dy = yi - cy;

    if abs(dx) < eps && abs(dy) < eps
        return;
    end

    % Find intersection of ray from centre to point with plot box
    tx = inf;
    ty = inf;
    if abs(dx) > eps
        if dx > 0
            tx = (xlim_fixed(2) - cx) / dx;
        else
            tx = (xlim_fixed(1) - cx) / dx;
        end
    end
    if abs(dy) > eps
        if dy > 0
            ty = (ylim_fixed(2) - cy) / dy;
        else
            ty = (ylim_fixed(1) - cy) / dy;
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
