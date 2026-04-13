function blocks = read_d_blocks(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    lines = textscan(fid, '%s', 'Delimiter', '\n'); fclose(fid);
    lines = lines{1};

    sep_line = '===============================================';

    % ----------------------------------------------------------------
    % Pass 1: split on separators into raw blocks.
    %
    % Each run in the file may start with a header block (e.g. "Total
    % Time ...", "Starting direction ...", or a point-1 EP block) that
    % is NOT preceded by a separator.  We handle this by treating the
    % content before the very first separator as the first raw block,
    % exactly the same way we treat any other inter-separator chunk.
    % ----------------------------------------------------------------
    raw_blocks = {};
    current = {};

    for i = 1:length(lines)
        if strcmp(strtrim(lines{i}), sep_line)
            raw_blocks{end+1, 1} = current; %#ok<AGROW>
            current = {};
        else
            current{end+1, 1} = lines{i}; %#ok<AGROW>
        end
    end
    % Flush the last chunk (after the final separator, or the whole
    % file if there were no separators at all).
    if ~isempty(current)
        raw_blocks{end+1, 1} = current;
    end

    % ----------------------------------------------------------------
    % Pass 2: merge consecutive raw blocks that belong to the same
    % continuation point.
    %
    % Blocks that contain only iteration convergence steps for a
    % special-point search ("==> Location of special point") share the
    % same branch/point label as the following block that holds the
    % converged result and function values.  We detect this by
    % comparing the (branch, point) pair extracted from adjacent blocks
    % and merging them when they match.
    %
    % A block with no numeric branch/point pair at all (e.g. a pure
    % "Total Time" footer or a blank trailing chunk) is silently
    % discarded.
    % ----------------------------------------------------------------
    blocks = {};
    if isempty(raw_blocks)
        return;
    end

    accumulated = raw_blocks{1};

    for k = 2:length(raw_blocks)
        next = raw_blocks{k};

        [b_acc, p_acc] = extract_pair(accumulated);
        [b_nxt, p_nxt] = extract_pair(next);

        if isnan(b_acc)
            % Current accumulated block has no data; discard it and
            % start fresh with the next block.
            accumulated = next;
        elseif isnan(b_nxt)
            % Next block has no data (e.g. trailing footer); flush the
            % accumulated block and discard the empty one.
            blocks{end+1, 1} = accumulated; %#ok<AGROW>
            accumulated = {};
        elseif b_acc == b_nxt && p_acc == p_nxt
            % Same point — merge with a separator divider so the
            % downstream parser can still see the sub-block boundaries
            % if it needs to.
            accumulated = [accumulated; {sep_line}; next];
        else
            % Different point — flush and start a new accumulation.
            blocks{end+1, 1} = accumulated; %#ok<AGROW>
            accumulated = next;
        end
    end

    % Flush the final accumulated block.
    if ~isempty(accumulated)
        [b_acc, ~] = extract_pair(accumulated);
        if ~isnan(b_acc)
            blocks{end+1, 1} = accumulated;
        end
    end
end

% ----------------------------------------------------------------
% Helper: return the first (|branch|, |point|) pair found in a block.
% Lines that match the pattern "  BR  PT  IT ..." header are skipped
% because the tokens there are column-header words, not numbers.
% ----------------------------------------------------------------
function [br, pt] = extract_pair(block)
    br = NaN; pt = NaN;
    for k = 1:length(block)
        line = block{k};
        % Skip the printed table header line
        if ~isempty(regexp(line, 'BR\s+PT', 'once'))
            continue;
        end
        tokens = regexp(line, '^\s*(-?\d+)\s+(-?\d+)', 'tokens', 'once');
        if ~isempty(tokens)
            br = abs(str2double(tokens{1}));
            pt = abs(str2double(tokens{2}));
            return;
        end
    end
end
