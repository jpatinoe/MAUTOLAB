function diagnostics = read_d_auto(filename)
% READ_D_AUTO   Parse an AUTO diagnostic (d.*) file.
%
%   diagnostics = read_d_auto(filename)
%
%   Returns a struct array with one element per continuation point.
%   Works with both periodic-orbit files (Floquet multipliers, SPB /
%   BP / Fold functions) and steady-state files (eigenvalues, Hopf /
%   BP / Fold functions).
%
%   Fields
%   ------
%   branch         - branch number
%   point          - point number
%   num_points     - number of sub-blocks merged into this entry
%   stability      - cell array of stable-count values (one per sub-block)
%   spectrum_type  - 'multiplier' or 'eigenvalue'
%   spectrum       - cell array of multiplier/eigenvalue structs
%                    Each struct has fields: index, real, imag, abs
%                    For eigenvalue files, abs = sqrt(real^2 + imag^2)
%   multipliers    - same as spectrum, retained for backwards compatibility
%   BP_function    - cell array of BP function values
%   SPB_function   - cell array of SPB function values  (periodic orbit)
%   Hopf_function  - cell array of Hopf function values (steady state)
%   Fold_function  - cell array of Fold function values
%   notes          - cell array of warning/note strings per sub-block
%   text           - raw lines of the block
%
%   The explicit field spectrum_type is important because the stability
%   interpretation differs between the two cases:
%       multipliers : crossings are with respect to the unit circle
%       eigenvalues : crossings are with respect to the imaginary axis

    blocks      = read_d_blocks(filename);
    diagnostics = struct([]);

    for k = 1:length(blocks)
        lines = blocks{k};

        % ============================================================
        % Determine whether this block uses Floquet MULTIPLIERS or
        % steady-state EIGENVALUES.
        % ============================================================
        use_eigenvalues = false;
        for j = 1:length(lines)
            if ~isempty(regexp(lines{j}, 'Eigenvalue', 'once'))
                use_eigenvalues = true;
                break;
            end
        end

        if use_eigenvalues
            spectrum_type = 'eigenvalue';
            entry_blocks  = parse_eigenvalue_blocks(lines);
        else
            spectrum_type = 'multiplier';
            entry_blocks  = parse_multiplier_blocks(lines);
        end

        % ============================================================
        % Stability count  -  "Stable: N"
        %   Multiplier files: "Multipliers:     Stable:   N"
        %   Eigenvalue files: "Eigenvalues  :   Stable:   N"
        % ============================================================
        stab      = cell(1, numel(entry_blocks));
        stab_idx  = 1;
        for j = 1:length(lines)
            if stab_idx > numel(entry_blocks), break; end
            m = regexp(lines{j}, ...
                '(?:Multipliers|Eigenvalues)\s*:\s*Stable\s*:\s*(\d+)', ...
                'tokens', 'once');
            if ~isempty(m)
                stab{stab_idx} = str2double(m{1});
                stab_idx = stab_idx + 1;
            end
        end

        % ============================================================
        % Scalar functions.
        % ============================================================
        bp_val    = cell(1, numel(entry_blocks));
        spb_val   = cell(1, numel(entry_blocks));
        hopf_val  = cell(1, numel(entry_blocks));
        fold_val  = cell(1, numel(entry_blocks));

        bp_idx    = 1;
        spb_idx   = 1;
        hopf_idx  = 1;
        fold_idx  = 1;

        num_fn_pattern = '([-+]?[0-9]+\.?[0-9]*(?:[eEdD][+-]?\d+)?)';

        for j = 1:length(lines)
            line = lines{j};

            if bp_idx <= numel(entry_blocks)
                m = regexp(line, ...
                    ['^\s*\d+\s+\d+\s+BP\s+Function[:\s]\s*' num_fn_pattern], ...
                    'tokens', 'once');
                if ~isempty(m)
                    bp_val{bp_idx} = str2double(m{1});
                    bp_idx = bp_idx + 1;
                end
            end

            if spb_idx <= numel(entry_blocks)
                m = regexp(line, ...
                    ['^\s*\d+\s+\d+\s+SPB\s+Function[:\s]\s*' num_fn_pattern], ...
                    'tokens', 'once');
                if ~isempty(m)
                    spb_val{spb_idx} = str2double(m{1});
                    spb_idx = spb_idx + 1;
                end
            end

            if hopf_idx <= numel(entry_blocks)
                m = regexp(line, ...
                    ['^\s*\d+\s+\d+\s+Hopf\s+Function[:\s]\s*' num_fn_pattern], ...
                    'tokens', 'once');
                if ~isempty(m)
                    hopf_val{hopf_idx} = str2double(m{1});
                    hopf_idx = hopf_idx + 1;
                end
            end

            if fold_idx <= numel(entry_blocks)
                m = regexp(line, ...
                    ['^\s*\d+\s+\d+\s+Fold\s+Function[:\s]\s*' num_fn_pattern], ...
                    'tokens', 'once');
                if ~isempty(m)
                    fold_val{fold_idx} = str2double(m{1});
                    fold_idx = fold_idx + 1;
                end
            end
        end

        % ============================================================
        % Notes collected per sub-block.
        % ============================================================
        notes    = cell(1, numel(entry_blocks));
        note_sb  = 1;

        for j = 1:length(lines)
            line = lines{j};

            m = regexp(line, ...
                '(?:Multipliers|Eigenvalues)\s*:\s*Stable\s*:\s*(\d+)', ...
                'tokens', 'once');
            if ~isempty(m) && note_sb < numel(entry_blocks)
                note_sb = note_sb + 1;
            end

            if isempty(strfind(line, 'NOTE')) %#ok<STREMP>
                continue;
            end
            m = regexp(line, 'NOTE\s*:?\s*(.*)', 'tokens', 'once');
            if isempty(m)
                continue;
            end

            note_text = strtrim(m{1});
            msg = '';
            if contains(note_text, 'Possible special point')
                msg = 'Possible special point';
            elseif contains(note_text, 'Retrying step')
                msg = 'Retrying step';
            elseif contains(note_text, 'No convergence using minimum step size')
                msg = 'No convergence using minimum step size';
            elseif contains(note_text, 'Multiplier inaccurate')
                msg = 'Multiplier inaccurate';
            elseif contains(note_text, 'Warning from subroutine FLOWKM :')
                msg = 'Warning from subroutine FLOWKM :';
            else
                msg = note_text;
            end

            if note_sb <= numel(entry_blocks)
                if isempty(notes{note_sb})
                    notes{note_sb} = {msg};
                else
                    notes{note_sb}{end+1} = msg;
                end
            end
        end

        % ============================================================
        % Extract branch and point from the first numeric pair found.
        % ============================================================
        br = NaN; pt = NaN;
        for j = 1:length(lines)
            if ~isempty(regexp(lines{j}, 'BR\s+PT', 'once'))
                continue;
            end
            tokens = regexp(lines{j}, '^\s*(-?\d+)\s+(-?\d+)', 'tokens', 'once');
            if ~isempty(tokens)
                br = abs(str2double(tokens{1}));
                pt = abs(str2double(tokens{2}));
                break;
            end
        end

        % ============================================================
        % Store
        % ============================================================
        diagnostics(k).text          = lines;
        diagnostics(k).branch        = br;
        diagnostics(k).point         = pt;
        diagnostics(k).spectrum_type = spectrum_type;
        diagnostics(k).spectrum      = entry_blocks;
        diagnostics(k).multipliers   = entry_blocks; % backwards compatibility
        diagnostics(k).num_points    = numel(entry_blocks);
        diagnostics(k).stability     = stab;
        diagnostics(k).BP_function   = bp_val;
        diagnostics(k).SPB_function  = spb_val;
        diagnostics(k).Hopf_function = hopf_val;
        diagnostics(k).Fold_function = fold_val;
        diagnostics(k).notes         = notes;
    end
end

% ====================================================================
%  Local helpers
% ====================================================================

function entry_blocks = parse_multiplier_blocks(lines)
% Parse Floquet multiplier lines into sub-blocks.
%
% Format:
%   BR  PT   Multiplier  N   re   im   Abs. Val.   abs

    entry_blocks  = {};
    current_block = [];

    num = '([-+]?[0-9]+\.?[0-9]*(?:[eEdD][+-]?\d+)?)';
    pat = ['Multiplier\s+(\d+)\s+' num '\s+' num '\s+Abs\.?\s*Val\.?\s*' num];

    for j = 1:length(lines)
        m = regexp(lines{j}, pat, 'tokens', 'once');
        if isempty(m)
            continue;
        end
        entry = struct( ...
            'index', str2double(m{1}), ...
            'real',  str2double(m{2}), ...
            'imag',  str2double(m{3}), ...
            'abs',   str2double(m{4}));

        if entry.index == 1 && ~isempty(current_block)
            entry_blocks{end+1} = current_block; %#ok<AGROW>
            current_block = entry;
        else
            if isempty(current_block)
                current_block = entry;
            else
                current_block(end+1) = entry; %#ok<AGROW>
            end
        end
    end

    if ~isempty(current_block)
        entry_blocks{end+1} = current_block;
    end
end

function entry_blocks = parse_eigenvalue_blocks(lines)
% Parse steady-state eigenvalue lines into sub-blocks.
%
% Format:
%   BR  PT   Eigenvalue  N:  re   im

    entry_blocks  = {};
    current_block = [];

    num = '([-+]?[0-9]+\.?[0-9]*(?:[eEdD][+-]?\d+)?)';
    pat = ['Eigenvalue\s+(\d+)\s*:\s*' num '\s+' num];

    for j = 1:length(lines)
        m = regexp(lines{j}, pat, 'tokens', 'once');
        if isempty(m)
            continue;
        end
        re  = str2double(m{2});
        im  = str2double(m{3});
        entry = struct( ...
            'index', str2double(m{1}), ...
            'real',  re, ...
            'imag',  im, ...
            'abs',   hypot(re, im));

        if entry.index == 1 && ~isempty(current_block)
            entry_blocks{end+1} = current_block; %#ok<AGROW>
            current_block = entry;
        else
            if isempty(current_block)
                current_block = entry;
            else
                current_block(end+1) = entry; %#ok<AGROW>
            end
        end
    end

    if ~isempty(current_block)
        entry_blocks{end+1} = current_block;
    end
end
