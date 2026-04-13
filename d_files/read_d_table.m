function branch_tables = read_d_table(diagnostics)
% READ_D_TABLE   Convert read_d_auto output into per-branch MATLAB tables.
%
%   branch_tables = read_d_table(diagnostics)
%
%   Input
%   -----
%   diagnostics  – struct array returned by read_d_auto.
%
%   Output
%   ------
%   branch_tables – struct with one field per branch (named "B<n>").
%                   Each field is a MATLAB table with one row per
%                   continuation sub-block.
%
%   Table columns
%   -------------
%   Branch          – branch number
%   Point           – point number
%   Subpoint        – local sub-block index within the diagnostic entry
%   SpectrumType    – "Eigenvalue" or "Multiplier"
%   Stable          – number of stable eigenvalues / multipliers
%   Measure_1..N    – stability-relevant measure:
%                       eigenvalues  -> |Re(lambda_j)|
%                       multipliers  -> |mu_j|
%   Abs_1..N        – full complex modulus
%   Re_1..Re_N      – real part
%   Im_1..Im_N      – imaginary part
%   Type_1..Type_N  – "real" or "complex"
%   BP              – BP function value   (NaN if absent)
%   SPB             – SPB function value  (NaN if absent)
%   Hopf            – Hopf function value (NaN if absent)
%   Fold            – Fold function value (NaN if absent)
%   Notes           – comma-separated note strings ('' if none)
%
%   Notes
%   -----
%   This version uses diagnostics(k).spectrum_type when available.
%   If that field is absent, it falls back to inferring the type from
%   the presence of Hopf/SPB function data.

    if isempty(diagnostics)
        branch_tables = struct();
        return;
    end

    % ---------------------------------------------------------------
    % Find global maximum number of spectrum entries over all sub-blocks
    % ---------------------------------------------------------------
    n_entries_max = 0;
    for k = 1:numel(diagnostics)
        d = diagnostics(k);
        S = get_spectrum_blocks(d);
        for s = 1:numel(S)
            if ~isempty(S{s})
                n_entries_max = max(n_entries_max, numel(S{s}));
            end
        end
    end

    if n_entries_max == 0
        warning('read_d_table:noSpectrum', ...
            'No eigenvalue/multiplier data found.');
        branch_tables = struct();
        return;
    end

    % ---------------------------------------------------------------
    % First pass: count rows exactly
    % ---------------------------------------------------------------
    n_rows = 0;
    for k = 1:numel(diagnostics)
        d = diagnostics(k);
        if isnan(d.branch) || isnan(d.point)
            continue;
        end

        S = get_spectrum_blocks(d);
        n_sub = max(numel(S), 1);
        n_rows = n_rows + n_sub;
    end

    % ---------------------------------------------------------------
    % Allocate columns
    % ---------------------------------------------------------------
    col_branch   = zeros(n_rows, 1);
    col_point    = zeros(n_rows, 1);
    col_subpoint = zeros(n_rows, 1);
    col_specname = strings(n_rows, 1);
    col_stable   = NaN(n_rows, 1);

    col_measure  = NaN(n_rows, n_entries_max);
    col_abs      = NaN(n_rows, n_entries_max);
    col_re       = NaN(n_rows, n_entries_max);
    col_im       = NaN(n_rows, n_entries_max);
    col_type     = strings(n_rows, n_entries_max);

    col_bp       = NaN(n_rows, 1);
    col_spb      = NaN(n_rows, 1);
    col_hopf     = NaN(n_rows, 1);
    col_fold     = NaN(n_rows, 1);
    col_notes    = strings(n_rows, 1);

    % ---------------------------------------------------------------
    % Fill columns
    % ---------------------------------------------------------------
    row = 0;
    tol = 1e-10;

    for k = 1:numel(diagnostics)
        d = diagnostics(k);
        if isnan(d.branch) || isnan(d.point)
            continue;
        end

        spec_type = get_spectrum_type(d);
        S = get_spectrum_blocks(d);
        n_sub = max(numel(S), 1);

        for s = 1:n_sub
            row = row + 1;

            col_branch(row)   = d.branch;
            col_point(row)    = d.point;
            col_subpoint(row) = s;
            col_specname(row) = string(spec_type);

            if isfield(d, 'stability') && s <= numel(d.stability) && ~isempty(d.stability{s})
                col_stable(row) = d.stability{s};
            end

            if s <= numel(S) && ~isempty(S{s})
                entries = S{s};
                for e = 1:numel(entries)
                    if e > n_entries_max
                        break;
                    end

                    re = entries(e).real;
                    im = entries(e).imag;
                    ab = entries(e).abs;

                    col_re(row, e)  = re;
                    col_im(row, e)  = im;
                    col_abs(row, e) = ab;

                    if strcmpi(spec_type, 'Eigenvalue')
                        col_measure(row, e) = abs(re);
                    else
                        col_measure(row, e) = ab;
                    end

                    if abs(im) < tol
                        col_type(row, e) = "real";
                    else
                        col_type(row, e) = "complex";
                    end
                end
            end

            col_bp(row)   = get_cell_scalar(d, 'BP_function',   s);
            col_spb(row)  = get_cell_scalar(d, 'SPB_function',  s);
            col_hopf(row) = get_cell_scalar(d, 'Hopf_function', s);
            col_fold(row) = get_cell_scalar(d, 'Fold_function', s);

            if isfield(d, 'notes') && s <= numel(d.notes) && ~isempty(d.notes{s})
                col_notes(row) = strjoin(d.notes{s}, ', ');
            else
                col_notes(row) = "";
            end
        end
    end

    % ---------------------------------------------------------------
    % Split by branch and build output tables
    % ---------------------------------------------------------------
    branch_ids = unique(col_branch, 'stable');
    branch_tables = struct();

    measure_names = arrayfun(@(n) sprintf('Measure_%d', n), 1:n_entries_max, 'UniformOutput', false);
    abs_names     = arrayfun(@(n) sprintf('Abs_%d', n),     1:n_entries_max, 'UniformOutput', false);
    re_names      = arrayfun(@(n) sprintf('Re_%d', n),      1:n_entries_max, 'UniformOutput', false);
    im_names      = arrayfun(@(n) sprintf('Im_%d', n),      1:n_entries_max, 'UniformOutput', false);
    type_names    = arrayfun(@(n) sprintf('Type_%d', n),    1:n_entries_max, 'UniformOutput', false);

    for bi = 1:numel(branch_ids)
        br = branch_ids(bi);
        sel = (col_branch == br);

        T = table( ...
            col_branch(sel), ...
            col_point(sel), ...
            col_subpoint(sel), ...
            col_specname(sel), ...
            col_stable(sel), ...
            'VariableNames', {'Branch', 'Point', 'Subpoint', 'SpectrumType', 'Stable'});

        % Keep only spectral columns that contain at least one value
        keep = any(~isnan(col_abs(sel, :)), 1);
        if ~any(keep)
            keep(1) = true;
        end

        idx_keep = find(keep);
        for jj = 1:numel(idx_keep)
            c = idx_keep(jj);
            T.(measure_names{jj}) = col_measure(sel, c);
            T.(abs_names{jj})     = col_abs(sel, c);
            T.(re_names{jj})      = col_re(sel, c);
            T.(im_names{jj})      = col_im(sel, c);
            T.(type_names{jj})    = col_type(sel, c);
        end

        if any(~isnan(col_bp(sel)))
            T.BP = col_bp(sel);
        end
        if any(~isnan(col_spb(sel)))
            T.SPB = col_spb(sel);
        end
        if any(~isnan(col_hopf(sel)))
            T.Hopf = col_hopf(sel);
        end
        if any(~isnan(col_fold(sel)))
            T.Fold = col_fold(sel);
        end

        T.Notes = col_notes(sel);

        branch_tables.(sprintf('B%d', br)) = T;
    end
end


function S = get_spectrum_blocks(d)
% Return generic spectrum cell array.
    if isfield(d, 'spectrum')
        S = d.spectrum;
    elseif isfield(d, 'multipliers')
        S = d.multipliers;
    else
        S = {};
    end
end


function spec_type = get_spectrum_type(d)
% Return "Eigenvalue" or "Multiplier".
    if isfield(d, 'spectrum_type') && ~isempty(d.spectrum_type)
        spec_type = char(d.spectrum_type);
        spec_type(1) = upper(spec_type(1));
        return;
    end

    % Fallback for older read_d_auto outputs
    has_hopf = isfield(d, 'Hopf_function') && any(~cellfun(@isempty, d.Hopf_function));
    has_spb  = isfield(d, 'SPB_function')  && any(~cellfun(@isempty, d.SPB_function));

    if has_hopf && ~has_spb
        spec_type = 'Eigenvalue';
    else
        spec_type = 'Multiplier';
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
