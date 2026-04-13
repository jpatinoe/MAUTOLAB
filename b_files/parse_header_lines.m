function header = parse_header_lines(header_lines)
%PARSE_HEADER_LINES Parse metadata lines from an AUTO b-file header block.
%
%   HEADER = PARSE_HEADER_LINES(HEADER_LINES) parses the non-numerical lines
%   that appear before the column-label line in an AUTO bifurcation diagram
%   file (b.*). The function returns a struct with as much information as can
%   be reliably extracted from the header.
%
%   Supported cases include:
%   * numeric AUTO constants, e.g. NDIM = 3
%   * lowercase string assignments, e.g. e = 'lor'
%   * user-specified parameters written numerically or by name
%   * active continuation parameters written numerically or by name
%   * indexed name maps such as
%         parnames = {1: 'rho', 2: 'beta', 3: 'sigma'}
%         unames   = {1: 'x',   2: 'y',    3: 'z'}
%   * raw bracketed entries as a fallback when a more specific parser is not
%     available
%
%   This parser was developed for AUTO-07p headers and tested in MATLAB R2025a.

    arguments
        header_lines cell
    end

    header = struct();
    overwrite = false;

    known_keys = { ...
        'e','s','dat','sv','unames','parnames','U','PAR','NDIM','IPS','IRS', ...
        'ILP','ICP','NTST','NCOL','IAD','ISP','ISW','IPLT','NBC','NINT', ...
        'NMX','NPR','MXBF','IID','ITMX','ITNW','NWTN','JAC','EPSL','EPSU', ...
        'EPSS','DS','DSMIN','DSMAX','IADS','NPAR','THL','THU','RL0','RL1', ...
        'A0','A1','UZR','UZSTOP','SP','STOP','IIS','IBR','LAB','TY', ...
        'NUNSTAB','NSTAB','IEQUIB','ITWIST','ISTART','IREV','IFIXED', ...
        'IPSI','NUZR' ...
    };

    for i = 1:numel(header_lines)
        line = strtrim(header_lines{i});
        if isempty(line)
            continue;
        end

        if contains(line, 'User-specified constants, where different from above')
            overwrite = true;
            continue;
        end

        if startsWith(line, 'User-specified parameters:')
            header = parse_parameter_line(header, line, ...
                'User-specified parameters:', 'ICP', 'ICP_names');
            continue;
        end

        if startsWith(line, 'Active continuation parameters:')
            header = parse_parameter_line(header, line, ...
                'Active continuation parameters:', 'active_ICP', 'active_ICP_names');
            continue;
        end

        [parsed, header] = parse_indexed_name_map(line, header, overwrite);
        if parsed
            continue;
        end

        header = parse_numeric_assignments(line, header, known_keys, overwrite);
        header = parse_string_assignments(line, header, known_keys, overwrite);
        header = parse_bracketed_fallback(line, header, known_keys, overwrite);
    end
end

function header = parse_parameter_line(header, line, prefix, numeric_field, name_field)
% Parse parameter lists that may be numeric or symbolic.

    payload = strtrim(strrep(line, prefix, ''));
    if isempty(payload)
        return;
    end

    nums = sscanf(payload, '%d')';
    if ~isempty(nums)
        header.(numeric_field) = nums;
        return;
    end

    names = regexp(payload, '''([^'']+)''', 'tokens');
    if ~isempty(names)
        header.(name_field) = cellfun(@(c) c{1}, names, 'UniformOutput', false);
        return;
    end

    raw = strsplit(payload);
    raw = raw(~cellfun('isempty', raw));
    if ~isempty(raw)
        header.(name_field) = raw;
    end
end

function [parsed, header] = parse_indexed_name_map(line, header, overwrite)
% Parse entries such as
%   parnames = {1: 'rho', 2: 'beta'}
%   unames   = {1: 'x',   2: 'y'}

    parsed = false;
    tokens = regexp(line, '([a-z]+)\s*=\s*\{([^}]*)\}', 'tokens', 'once');
    if isempty(tokens)
        return;
    end

    key = strtrim(tokens{1});
    payload = tokens{2};

    if ~ismember(key, {'parnames', 'unames'})
        return;
    end

    pairs = regexp(payload, '(\d+)\s*:\s*''([^'']+)''', 'tokens');
    if isempty(pairs)
        return;
    end

    idx = cellfun(@(c) str2double(c{1}), pairs);
    vals = cellfun(@(c) c{2}, pairs, 'UniformOutput', false);

    out = cell(1, max(idx));
    for k = 1:numel(idx)
        out{idx(k)} = vals{k};
    end

    if overwrite || ~isfield(header, key)
        header.(key) = out;
    end
    header.([key '_raw']) = ['{' payload '}'];
    parsed = true;
end

function header = parse_numeric_assignments(line, header, known_keys, overwrite)
% Parse uppercase numeric assignments such as NDIM = 3 or DS = -1e-2.

    tokens = regexp(line, '([A-Z]+)\s*=\s*(-?\d+\.?\d*(?:[Ee][+-]?\d+)?|)', 'tokens');
    for k = 1:numel(tokens)
        key = tokens{k}{1};
        val_str = strtrim(tokens{k}{2});

        if ~ismember(key, known_keys)
            continue;
        end

        if isempty(val_str)
            value = 0;
        else
            value = str2double(val_str);
        end

        if overwrite || ~isfield(header, key)
            header.(key) = value;
        end
    end
end

function header = parse_string_assignments(line, header, known_keys, overwrite)
% Parse lowercase string assignments such as e = 'lor'.

    tokens = regexp(line, '([a-z]+)\s*=\s*''?([^'']+)''?', 'tokens');
    for k = 1:numel(tokens)
        key = tokens{k}{1};
        value = strtrim(tokens{k}{2});

        if ~ismember(key, known_keys)
            continue;
        end

        if overwrite || ~isfield(header, key)
            header.(key) = value;
        end
    end
end

function header = parse_bracketed_fallback(line, header, known_keys, overwrite)
% Store bracketed entries as raw strings when no more specific parser applies.

    matches = regexp(line, '([A-Za-z]+)\s*=\s*(\{[^\}]*\})', 'tokens');
    for k = 1:numel(matches)
        key = matches{k}{1};
        value = matches{k}{2};

        if ~ismember(key, known_keys)
            continue;
        end

        % Avoid overwriting structured parnames/unames data with raw text.
        if ismember(key, {'parnames', 'unames'}) && isfield(header, key)
            continue;
        end

        if overwrite || ~isfield(header, key)
            header.(key) = value;
        end
    end
end
