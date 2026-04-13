function d_summary(diagnostics, varargin)
% D_SUMMARY   Print a compact ASCII table of eigenvalues / multipliers.
%
%   d_summary(diagnostics)
%   d_summary(diagnostics, 'branch', BR)
%   d_summary(diagnostics, 'maxrows', N)
%
%   Prints one row per continuation sub-block showing:
%     Pt | Stable | Unstable | spectral magnitudes | test functions | Type | Notes
%
%   Conventions
%   -----------
%   - For multipliers, the spectral columns show |mu_j|.
%   - For eigenvalues, the spectral columns show |Re(lambda_j)|.
%   - Type column uses:
%         r = real
%         c = complex
%         - = missing entry
%   - Stability markers:
%         ! = lost stability
%         + = gained stability

    % --- parse options ---
    p = inputParser;
    addParameter(p, 'branch',  [], @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'maxrows', 50, @(x) isnumeric(x) && isscalar(x));
    parse(p, varargin{:});
    filter_branch = p.Results.branch;
    maxrows       = p.Results.maxrows;
    if maxrows == 0
        maxrows = Inf;
    end

    if isempty(diagnostics)
        fprintf('  (no data)\n');
        return;
    end

    % --- group diagnostics by branch, preserving original order ---
    branches = [diagnostics.branch];
    branches = branches(~isnan(branches));
    if isempty(branches)
        fprintf('  (no data)\n');
        return;
    end
    branch_list = unique(branches, 'stable');

    for bi = 1:numel(branch_list)
        br = branch_list(bi);

        if ~isempty(filter_branch) && br ~= filter_branch
            continue;
        end

        D = diagnostics([diagnostics.branch] == br);
        rows = build_rows_from_branch(D);

        n_total = numel(rows);
        if n_total == 0
            fprintf('\n  Branch %d  (0 points)\n', br);
            fprintf('  (no spectral data)\n');
            continue;
        end

        spec_type = rows(1).spec_type;
        is_eig = strcmpi(spec_type, 'eigenvalue');

        % --- determine number of spectral entries shown ---
        n_eig = 0;
        for k = 1:n_total
            n_eig = max(n_eig, numel(rows(k).spec_vals));
        end

        if n_eig == 0
            fprintf('\n  Branch %d  (%d points)\n', br, n_total);
            fprintf('  (no spectral data)\n');
            continue;
        end

        % --- widths and spacing ---
        sep = '   ';
        pt_w     = max(6, numel('Pt'));
        stab_w   = max(7, numel('Stable'));
        unstab_w = max(9, numel('Unstable'));

        eig_label = 'mu';
        if is_eig
            eig_label = 'lambda';
        end

        eig_headers = cell(1, n_eig);
        eig_w = zeros(1, n_eig);
        for e = 1:n_eig
            eig_headers{e} = ['|' eig_label '_' num2str(e) '|'];
            eig_w(e) = numel(eig_headers{e});
        end

        fn_cols = {'BP','SPB','Hopf','Fold'};
        fn_present = false(size(fn_cols));
        for j = 1:numel(fn_cols)
            vals = [rows.(fn_cols{j})];
            fn_present(j) = any(~isnan(vals));
        end
        fn_cols = fn_cols(fn_present);

        fn_w = zeros(1, numel(fn_cols));
        for j = 1:numel(fn_cols)
            fn_w(j) = numel(fn_cols{j});
        end

        type_w = numel('Type');
        note_w = numel('Notes');

        % --- first pass: compute widths from actual formatted strings ---
        for k = 1:n_total
            for e = 1:n_eig
                if e <= numel(rows(k).spec_vals) && ~isnan(rows(k).spec_vals(e))
                    s = sprintf('%.5f', rows(k).spec_vals(e));
                else
                    s = '---';
                end
                eig_w(e) = max(eig_w(e), numel(s));
            end

            for j = 1:numel(fn_cols)
                v = rows(k).(fn_cols{j});
                if isnan(v)
                    s = '';
                else
                    s = sprintf('%s=%+8.2e', fn_cols{j}, v);
                end
                fn_w(j) = max(fn_w(j), numel(s));
            end

            type_w = max(type_w, numel(rows(k).type_str));
            note_w = max(note_w, numel(rows(k).note_str));
        end

        % --- branch title ---
        fprintf('\n  Branch %d  (%d points)  [%s]\n', br, n_total, spec_type);

        % --- header ---
        fprintf('  %-*s%s', pt_w, 'Pt', sep);
        fprintf('%-*s%s', stab_w, 'Stable', sep);
        fprintf('%-*s', unstab_w, 'Unstable');

        for e = 1:n_eig
            fprintf('%s%-*s', sep, eig_w(e), eig_headers{e});
        end
        for j = 1:numel(fn_cols)
            fprintf('%s%-*s', sep, fn_w(j), fn_cols{j});
        end
        fprintf('%s%-*s%s%-*s\n', sep, type_w, 'Type', sep, note_w, 'Notes');

        total_width = 2 + pt_w + numel(sep) + stab_w + numel(sep) + unstab_w;
        total_width = total_width + sum(numel(sep) + eig_w);
        total_width = total_width + sum(numel(sep) + fn_w);
        total_width = total_width + numel(sep) + type_w + numel(sep) + note_w;
        fprintf('  %s\n', repmat('-', 1, total_width - 2));

        % --- choose displayed rows ---
        if maxrows < n_total
            show_first = floor(maxrows / 2);
            show_last  = maxrows - show_first;
            show_idx   = [1:show_first, (n_total-show_last+1):n_total];
        else
            show_idx = 1:n_total;
        end

        % --- print rows ---
        prev_stable = NaN;
        n_shown = 0;

        for ii = 1:numel(show_idx)
            r = show_idx(ii);

            if ii > 1 && show_idx(ii) ~= show_idx(ii-1) + 1
                fprintf('  ...\n');
            end

            row = rows(r);

            marker = ' ';
            if ~isnan(row.stable) && ~isnan(prev_stable) && row.stable ~= prev_stable
                if row.stable < prev_stable
                    marker = '!';
                else
                    marker = '+';
                end
            end
            prev_stable = row.stable;

            if isnan(row.stable)
                stable_str = '---';
                unstable_str = '---';
            else
                stable_str = sprintf('%d', row.stable);
                unstable_str = sprintf('%d', row.unstable);
            end

            fprintf('%s %-*d%s', marker, pt_w, row.point, sep);
            fprintf('%-*s%s', stab_w, stable_str, sep);
            fprintf('%-*s', unstab_w, unstable_str);

            for e = 1:n_eig
                if e <= numel(row.spec_vals) && ~isnan(row.spec_vals(e))
                    s = sprintf('%.5f', row.spec_vals(e));
                else
                    s = '---';
                end
                fprintf('%s%-*s', sep, eig_w(e), s);
            end

            for j = 1:numel(fn_cols)
                v = row.(fn_cols{j});
                if isnan(v)
                    s = '';
                else
                    s = sprintf('%s=%+8.2e', fn_cols{j}, v);
                end
                fprintf('%s%-*s', sep, fn_w(j), s);
            end

            fprintf('%s%-*s%s%-*s\n', ...
                sep, type_w, row.type_str, ...
                sep, note_w, row.note_str);

            n_shown = n_shown + 1;
        end

        fprintf('  %s\n', repmat('-', 1, total_width - 2));
        fprintf('  Legend:  ! = lost stability,  + = gained stability,  r = real,  c = complex\n');
        if n_shown < n_total
            fprintf('  (showing %d of %d rows — use ''maxrows'',0 to see all)\n', ...
                n_shown, n_total);
        end
    end

    fprintf('\n');
end


function rows = build_rows_from_branch(D)
% Build one printable row per continuation sub-block.

    rows = struct( ...
        'point', {}, ...
        'stable', {}, ...
        'unstable', {}, ...
        'spec_vals', {}, ...
        'type_str', {}, ...
        'BP', {}, ...
        'SPB', {}, ...
        'Hopf', {}, ...
        'Fold', {}, ...
        'note_str', {}, ...
        'spec_type', {});

    tol = 1e-10;

    for k = 1:numel(D)
        d = D(k);

        % spectrum type
        if isfield(d, 'spectrum_type') && ~isempty(d.spectrum_type)
            spec_type = lower(char(d.spectrum_type));
        else
            spec_type = 'multiplier';
            if isfield(d, 'Hopf_function') && any(~cellfun(@isempty, d.Hopf_function))
                spec_type = 'eigenvalue';
            end
        end

        % generic spectrum field
        if isfield(d, 'spectrum')
            S = d.spectrum;
        else
            S = d.multipliers;
        end

        nsub = numel(S);

        for j = 1:nsub
            block = S{j};

            row.point = d.point;

            if isfield(d, 'stability') && j <= numel(d.stability) && ~isempty(d.stability{j})
                row.stable = d.stability{j};
            else
                row.stable = NaN;
            end

            ne = numel(block);
            if isnan(row.stable)
                row.unstable = NaN;
            else
                row.unstable = ne - row.stable;
            end

            row.spec_vals = NaN(1, ne);
            type_chars = repmat('-', 1, ne);

            for e = 1:ne
                re = block(e).real;
                im = block(e).imag;

                if strcmp(spec_type, 'eigenvalue')
                    row.spec_vals(e) = abs(re);
                else
                    row.spec_vals(e) = block(e).abs;
                end

                if abs(im) < tol
                    type_chars(e) = 'r';
                else
                    type_chars(e) = 'c';
                end
            end
            row.type_str = type_chars;

            row.BP   = get_cell_scalar(d, 'BP_function',   j);
            row.SPB  = get_cell_scalar(d, 'SPB_function',  j);
            row.Hopf = get_cell_scalar(d, 'Hopf_function', j);
            row.Fold = get_cell_scalar(d, 'Fold_function', j);

            if isfield(d, 'notes') && j <= numel(d.notes) && ~isempty(d.notes{j})
                row.note_str = ['[' strjoin(d.notes{j}, '; ') ']'];
            else
                row.note_str = '';
            end

            row.spec_type = spec_type;

            rows(end+1) = row; %#ok<AGROW>
        end
    end
end


function v = get_cell_scalar(d, fname, j)
    v = NaN;
    if isfield(d, fname)
        C = d.(fname);
        if j <= numel(C) && ~isempty(C{j})
            v = C{j};
        end
    end
end
