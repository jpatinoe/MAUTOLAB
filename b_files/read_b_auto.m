function branches = read_b_auto(filename)
%READ_B_AUTO Read AUTO-07p bifurcation diagram files (b.*) into MATLAB.
%
%   BRANCHES = READ_B_AUTO(FILENAME) parses an AUTO bifurcation diagram file
%   and returns a struct array with one entry per branch. Each entry contains:
%
%       branch_number   - branch number reported by AUTO
%       data            - MATLAB table with the numerical columns
%       header          - struct with parsed header metadata
%
%   This reader was developed and tested in MATLAB R2025a.
%
%   Notes
%   -----
%   * The first numerical column in a b-file is the signed branch number.
%     This is stored separately as branch_number and is not duplicated in the
%     output table.
%   * AUTO sometimes prints multi-word column labels such as
%       'MAX x', 'MAX U(1)', 'INTEGRAL U(1)'
%     so the label line cannot be parsed by simple whitespace splitting.
%
%   Example
%   -------
%       branches = read_b_auto('b.lor');
%       branches(1).header
%       branches(1).data(1:5,:)
%
%   See also: PARSE_HEADER_LINES, ARRAY2TABLE

    arguments
        filename (1,1) string
    end

    if ~isfile(filename)
        error('read_b_auto:FileNotFound', 'File not found: %s', filename);
    end

    lines = readlines(filename, 'EmptyLineRule', 'skip');
    lines = cellstr(lines);

    branches = struct( ...
        'branch_number', {}, ...
        'data', {}, ...
        'header', {} ...
    );

    i = 1;
    while i <= numel(lines)
        line = strtrim(lines{i});

        if is_branch_header_start(line)
            [branch, i] = parse_single_branch(lines, i + 1, filename);
            if ~isempty(branch)
                branches(end+1) = branch; %#ok<AGROW>
            end
        else
            i = i + 1;
        end
    end
end

function tf = is_branch_header_start(line)
% Detect the start of a branch header block.

    tf = false;
    if strlength(string(line)) == 0
        return;
    end

    tokens = strsplit(strtrim(line));
    if isempty(tokens)
        return;
    end

    prefix = str2double(tokens{1});
    tf = ~isnan(prefix) && prefix == 0;
end

function [branch, i] = parse_single_branch(lines, i, filename)
% Parse one branch, starting immediately after the initial line containing 0.

    branch = [];
    header_lines = {};
    label_line = '';

    % Collect header metadata and the column-label line.
    while i <= numel(lines)
        line = strtrim(lines{i});

        if is_column_label_line(line)
            label_line = strip_leading_zero(line);
            i = i + 1;
            break;
        elseif is_branch_header_start(line)
            stripped = strip_leading_zero(line);
            if ~isempty(stripped)
                header_lines{end+1} = stripped; %#ok<AGROW>
            end
            i = i + 1;
        else
            break;
        end
    end

    data = zeros(0,0);

    % Collect numerical rows until the next header block.
    while i <= numel(lines)
        line = strtrim(lines{i});

        if is_branch_header_start(line)
            break;
        end

        vals = sscanf(line, '%f')';
        if ~isempty(vals)
            if isempty(data)
                data = vals;
            else
                if numel(vals) ~= size(data, 2)
                    error('read_b_auto:InconsistentRowLength', ...
                        ['Inconsistent number of numerical columns while reading %s. ' ...
                         'Encountered %d columns after previously seeing %d.'], ...
                        filename, numel(vals), size(data, 2));
                end
                data(end+1, :) = vals; %#ok<AGROW>
            end
        end
        i = i + 1;
    end

    if isempty(data)
        warning('read_b_auto:EmptyBranch', ...
            'No numerical data found for a branch in file %s.', filename);
        return;
    end

    expected_ncols = size(data, 2) - 1;
    label_tokens = parse_label_tokens(label_line, expected_ncols);
    matlab_safe_labels = make_matlab_safe_labels(label_tokens);

    branch = struct();
    branch.branch_number = abs(data(1, 1));
    branch.header = parse_header_lines(header_lines);
    branch.data = array2table(data(:, 2:end), 'VariableNames', matlab_safe_labels);
end

function tf = is_column_label_line(line)
% Detect the line containing PT, TY, LAB and the remaining column labels.

    tf = is_branch_header_start(line) && ...
         contains(line, 'PT') && contains(line, 'TY') && contains(line, 'LAB');
end

function out = strip_leading_zero(line)
% Remove the leading header marker '0' and surrounding whitespace.

    out = strtrim(regexprep(line, '^\s*0\s*', ''));
end

function label_tokens = parse_label_tokens(label_line, expected_ncols)
% Parse column labels from the AUTO label line.
%
% AUTO sometimes uses multi-word labels such as:
%   MAX x, MAX U(1), MIN y, INTEGRAL U(1)
% so a simple whitespace split is insufficient.

    if isempty(label_line)
        error('read_b_auto:MissingLabelLine', 'No column label line found.');
    end

    raw = strsplit(strtrim(label_line));
    raw = raw(~cellfun('isempty', raw));

    if numel(raw) == expected_ncols
        label_tokens = raw;
        return;
    end

    merged = {};
    k = 1;
    while k <= numel(raw)
        tok = raw{k};

        if any(strcmp(tok, {'MAX', 'MIN', 'INTEGRAL'})) && k < numel(raw)
            merged{end+1} = [tok ' ' raw{k+1}]; %#ok<AGROW>
            k = k + 2;
        else
            merged{end+1} = tok; %#ok<AGROW>
            k = k + 1;
        end
    end

    if numel(merged) == expected_ncols
        label_tokens = merged;
        return;
    end

    error('read_b_auto:LabelCountMismatch', ...
        ['Unable to reconcile column labels with data columns. ' ...
         'Raw labels: %d, merged labels: %d, expected: %d.'], ...
        numel(raw), numel(merged), expected_ncols);
end

function matlab_safe_labels = make_matlab_safe_labels(label_tokens)
% Convert AUTO labels into valid MATLAB table variable names.

    matlab_safe_labels = regexprep(label_tokens, '[\s\(\)\-]', '_');
    matlab_safe_labels = regexprep(matlab_safe_labels, '_+', '_');
    matlab_safe_labels = regexprep(matlab_safe_labels, '^_+', '');
    matlab_safe_labels = regexprep(matlab_safe_labels, '_+$', '');
    matlab_safe_labels = matlab.lang.makeUniqueStrings(matlab_safe_labels);

    if numel(unique(matlab_safe_labels)) ~= numel(matlab_safe_labels)
        error('read_b_auto:NonUniqueLabels', ...
            'Unable to generate unique MATLAB-safe column labels.');
    end
end
