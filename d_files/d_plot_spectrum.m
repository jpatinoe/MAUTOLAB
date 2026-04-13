function d_plot_spectrum(diagnostics, varargin)
% D_PLOT_SPECTRUM   Plot spectral data from read_d_auto diagnostics.
%
%   d_plot_spectrum(diagnostics)
%   d_plot_spectrum(diagnostics, 'branch', BR)
%   d_plot_spectrum(diagnostics, 'type', 'measure')
%   d_plot_spectrum(diagnostics, 'type', 'abs')
%   d_plot_spectrum(diagnostics, 'type', 'complex')
%
%   Main design choices
%   -------------------
%   - Rows are split not only by branch but also by local point sequence
%     within the branch. A new segment starts whenever the point number
%     does not increase.
%   - By default, only the largest subpoint for each point is plotted.
%   - Test-function markers are removed entirely.
%   - For the x-axis of 'measure' and 'abs' plots, a local continuation
%     index is used inside each segment. This avoids confusion when AUTO
%     reuses point numbers.
%
%   Plot types
%   ----------
%   'measure' (default)
%       eigenvalues  -> |Re(lambda_j)|
%       multipliers  -> |mu_j|
%
%   'abs'
%       full complex modulus
%
%   'complex'
%       trajectory in the complex plane
%
%   Options
%   -------
%   'branch'        – only plot this branch (default: all branches)
%   'type'          – 'measure', 'abs', or 'complex' (default: 'measure')
%   'logscale'      – true/false for y-axis in 'measure'/'abs' plots
%   'subpointmode'  – 'max' or 'all' (default: 'max')
%   'splitsegments' – true/false, split repeated point sequences
%                     (default: true)
%   'index'         – plot only one spectral index (default: all)

    p = inputParser;
    addParameter(p, 'branch',       [], @(x) isnumeric(x));
    addParameter(p, 'type',         'measure', @(x) ismember(lower(x), {'measure','abs','complex'}));
    addParameter(p, 'logscale',     false, @islogical);
    addParameter(p, 'subpointmode', 'max', @(x) ismember(lower(x), {'max','all'}));
    addParameter(p, 'splitsegments', true, @islogical);
    addParameter(p, 'index',        [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 1));
    parse(p, varargin{:});

    filter_branch  = p.Results.branch;
    plot_type      = lower(p.Results.type);
    use_log        = p.Results.logscale;
    subpoint_mode  = lower(p.Results.subpointmode);
    split_segments = p.Results.splitsegments;
    single_index   = p.Results.index;

    BT = read_d_table(diagnostics);
    if isempty(fieldnames(BT))
        warning('d_plot_spectrum:noData', 'No data to plot.');
        return;
    end

    branch_names = fieldnames(BT);
    colors = lines(12);

    for bi = 1:numel(branch_names)
        T = BT.(branch_names{bi});
        br = T.Branch(1);

        if ~isempty(filter_branch) && ~any(br == filter_branch)
            continue;
        end

        % Keep only largest subpoint if requested
        T = reduce_subpoints(T, subpoint_mode);

        % Split into local monotone point sequences
        segments = split_table_segments(T, split_segments);
        if isempty(segments)
            continue;
        end

        % Determine spectrum type
        if ismember('SpectrumType', T.Properties.VariableNames)
            spec_name = char(T.SpectrumType(1));
        else
            if ismember('Hopf', T.Properties.VariableNames) && ~ismember('SPB', T.Properties.VariableNames)
                spec_name = 'Eigenvalue';
            else
                spec_name = 'Multiplier';
            end
        end
        is_eig = strcmpi(spec_name, 'Eigenvalue');

        % Spectral columns
        measure_cols = T.Properties.VariableNames(startsWith(T.Properties.VariableNames, 'Measure_'));
        abs_cols     = T.Properties.VariableNames(startsWith(T.Properties.VariableNames, 'Abs_'));
        re_cols      = T.Properties.VariableNames(startsWith(T.Properties.VariableNames, 'Re_'));
        im_cols      = T.Properties.VariableNames(startsWith(T.Properties.VariableNames, 'Im_'));
        n_spec       = numel(abs_cols);

        if n_spec == 0
            continue;
        end

        if ~isempty(single_index)
            if single_index > n_spec
                warning('d_plot_spectrum:indexOutOfRange', ...
                    'Requested spectral index %d, but branch %d only has %d entries.', ...
                    single_index, br, n_spec);
                continue;
            end
            spec_idx_list = single_index;
        else
            spec_idx_list = 1:n_spec;
        end

        fig = figure('Name', sprintf('Branch %d — %s spectrum', br, spec_name));
        tl = tiledlayout(fig, numel(segments), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

        for si = 1:numel(segments)
            Ts = segments{si};
            ax = nexttile(tl);
            hold(ax, 'on');

            switch plot_type
                case {'measure','abs'}
                    x_local = (1:height(Ts)).';
                    x_point = Ts.Point;

                    if strcmp(plot_type, 'measure')
                        y_cols = measure_cols;
                        if is_eig
                            ylab = '|Re(\lambda)|';
                            ttl  = sprintf('Branch %d, segment %d — eigenvalue stability measure', br, si);
                        else
                            ylab = '|\mu|';
                            ttl  = sprintf('Branch %d, segment %d — multiplier magnitudes', br, si);
                        end
                    else
                        y_cols = abs_cols;
                        if is_eig
                            ylab = '|\lambda|';
                            ttl  = sprintf('Branch %d, segment %d — eigenvalue moduli', br, si);
                        else
                            ylab = '|\mu|';
                            ttl  = sprintf('Branch %d, segment %d — multiplier magnitudes', br, si);
                        end
                    end

                    % Stability boundary for multipliers
                    if ~is_eig
                        yline(ax, 1, '--', 'Color', [0.70 0.20 0.20], ...
                            'LineWidth', 1.0, 'HandleVisibility', 'off');
                    end

                    for kk = 1:numel(spec_idx_list)
                        e = spec_idx_list(kk);
                        if e > numel(y_cols), continue; end

                        y = Ts.(y_cols{e});
                        c = colors(mod(e-1, size(colors,1))+1, :);

                        plot(ax, x_local, y, '-o', ...
                            'Color', c, ...
                            'MarkerFaceColor', c, ...
                            'MarkerSize', 3.5, ...
                            'LineWidth', 1.2, ...
                            'DisplayName', curve_label(plot_type, spec_name, e));

                        % Optional light point labels on x-axis by true AUTO point number
                        set(ax, 'XTick', x_local, 'XTickLabel', string(x_point));
                    end

                    % Stability-change lines
                    if ismember('Stable', Ts.Properties.VariableNames)
                        stable = Ts.Stable;
                        idxchg = find(diff(stable) ~= 0 & ~isnan(diff(stable)));
                        for ii = idxchg(:)'
                            xline(ax, x_local(ii+1), ':', ...
                                'Color', [0.45 0.45 0.45], ...
                                'LineWidth', 0.8, ...
                                'HandleVisibility', 'off');
                        end
                    end

                    if use_log
                        set(ax, 'YScale', 'log');
                    end
                    xlabel(ax, 'Local continuation index (tick labels = AUTO point)');
                    ylabel(ax, ylab, 'Interpreter', 'tex');
                    title(ax, ttl, 'Interpreter', 'none');
                    grid(ax, 'on');
                    xlim(ax, [0.5, height(Ts)+0.5]);

                    if si == 1
                        legend(ax, 'Location', 'best');
                    end

                case 'complex'
                    if ~is_eig
                        th = linspace(0, 2*pi, 400);
                        plot(ax, cos(th), sin(th), '--', ...
                            'Color', [0.70 0.20 0.20], ...
                            'LineWidth', 0.9, ...
                            'HandleVisibility', 'off');
                    else
                        xline(ax, 0, '--', 'Color', [0.70 0.20 0.20], ...
                            'LineWidth', 0.9, 'HandleVisibility', 'off');
                        yline(ax, 0, '--', 'Color', [0.70 0.20 0.20], ...
                            'LineWidth', 0.9, 'HandleVisibility', 'off');
                    end

                    for kk = 1:numel(spec_idx_list)
                        e = spec_idx_list(kk);
                        re = Ts.(re_cols{e});
                        im = Ts.(im_cols{e});
                        c  = colors(mod(e-1, size(colors,1))+1, :);

                        good = ~(isnan(re) | isnan(im));
                        re = re(good);
                        im = im(good);

                        if isempty(re)
                            continue;
                        end

                        plot(ax, re, im, '-', ...
                            'Color', c, ...
                            'LineWidth', 1.2, ...
                            'DisplayName', curve_label('complex', spec_name, e));

                        plot(ax, re(1), im(1), 'o', ...
                            'Color', c, ...
                            'MarkerFaceColor', 'w', ...
                            'MarkerSize', 6, ...
                            'LineWidth', 1.2, ...
                            'HandleVisibility', 'off');

                        plot(ax, re(end), im(end), 's', ...
                            'Color', c, ...
                            'MarkerFaceColor', c, ...
                            'MarkerSize', 6, ...
                            'LineWidth', 1.2, ...
                            'HandleVisibility', 'off');
                    end

                    xlabel(ax, 'Re');
                    ylabel(ax, 'Im');
                    if is_eig
                        title(ax, sprintf('Branch %d, segment %d — eigenvalue trajectories', br, si), ...
                            'Interpreter', 'none');
                    else
                        title(ax, sprintf('Branch %d, segment %d — multiplier trajectories', br, si), ...
                            'Interpreter', 'none');
                    end
                    axis(ax, 'equal');
                    grid(ax, 'on');

                    if si == 1
                        legend(ax, 'Location', 'best');
                    end
            end
        end
    end
end


function T = reduce_subpoints(Tin, mode)
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


function segments = split_table_segments(T, do_split)
% Split branch table into local monotone point sequences.
% New segment when point number does not increase.

    if isempty(T)
        segments = {};
        return;
    end

    if ~do_split || height(T) == 1
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


function s = curve_label(plot_type, spec_name, idx)
    is_eig = strcmpi(spec_name, 'Eigenvalue');

    if strcmp(plot_type, 'complex')
        if is_eig
            s = sprintf('Eigenvalue %d', idx);
        else
            s = sprintf('Multiplier %d', idx);
        end
        return;
    end

    if strcmp(plot_type, 'measure')
        if is_eig
            s = sprintf('|Re(\\lambda_%d)|', idx);
        else
            s = sprintf('|\\mu_%d|', idx);
        end
    else
        if is_eig
            s = sprintf('|\\lambda_%d|', idx);
        else
            s = sprintf('|\\mu_%d|', idx);
        end
    end
end
