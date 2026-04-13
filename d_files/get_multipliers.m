function data = get_multipliers(diagnostics, varargin)
% GET_MULTIPLIERS   Extract spectrum data for one branch/segment.
%
%   data = get_multipliers(diagnostics)
%   data = get_multipliers(diagnostics, 'branch', 2)
%   data = get_multipliers(diagnostics, 'branch', 2, 'segment', 1)
%
%   Output
%   ------
%   data is a struct with fields:
%       branch
%       segment
%       spectrum_type
%       point
%       subpoint
%       Z          cell array, one row per slider position
%
%   Notes
%   -----
%   This is kept as a lightweight helper for plot_complex_slider.

    p = inputParser;
    addParameter(p, 'branch', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    addParameter(p, 'segment', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'subpointmode', 'max', @(x) ismember(lower(x), {'max','all'}));
    parse(p, varargin{:});

    BT = read_d_table(diagnostics);
    if isempty(fieldnames(BT))
        error('get_multipliers:noData', 'No diagnostic data available.');
    end

    branch_names = fieldnames(BT);
    branch_ids = zeros(numel(branch_names),1);
    for k = 1:numel(branch_names)
        Ttmp = BT.(branch_names{k});
        branch_ids(k) = Ttmp.Branch(1);
    end

    if isempty(p.Results.branch)
        br = branch_ids(1);
    else
        br = p.Results.branch;
    end

    field = sprintf('B%d', br);
    if ~isfield(BT, field)
        error('get_multipliers:branchNotFound', 'Branch %d not found.', br);
    end

    T = BT.(field);
    if ismember('Subpoint', T.Properties.VariableNames) && strcmpi(p.Results.subpointmode, 'max')
        pts = T.Point;
        keep = false(height(T),1);
        [~,~,ic] = unique(pts,'stable');
        for k = 1:max(ic)
            idx = find(ic==k);
            [~,j] = max(T.Subpoint(idx));
            keep(idx(j)) = true;
        end
        T = T(keep,:);
    end

    % Split segments
    if height(T) == 1
        segments = {T};
    else
        pts = T.Point;
        cut = [1; find(diff(pts) <= 0) + 1; height(T)+1];
        segments = cell(numel(cut)-1,1);
        for k = 1:numel(cut)-1
            segments{k} = T(cut(k):cut(k+1)-1,:);
        end
    end

    seg = p.Results.segment;
    if seg > numel(segments)
        error('get_multipliers:segmentNotFound', ...
            'Branch %d has %d segment(s); requested %d.', br, numel(segments), seg);
    end

    Ts = segments{seg};
    re_cols = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Re_'));
    im_cols = Ts.Properties.VariableNames(startsWith(Ts.Properties.VariableNames, 'Im_'));
    n_spec = min(numel(re_cols), numel(im_cols));

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

    data.branch = br;
    data.segment = seg;
    if ismember('SpectrumType', Ts.Properties.VariableNames)
        data.spectrum_type = char(Ts.SpectrumType(1));
    else
        data.spectrum_type = 'Multiplier';
    end
    data.point = Ts.Point;
    if ismember('Subpoint', Ts.Properties.VariableNames)
        data.subpoint = Ts.Subpoint;
    else
        data.subpoint = ones(height(Ts),1);
    end
    data.Z = Z;
end
