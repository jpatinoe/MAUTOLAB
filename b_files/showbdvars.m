function info = showbdvars(branches, branch_spec)
%SHOWBDVARS Show variables available in selected branches.
%
%   info = showbdvars(branches)
%   info = showbdvars(branches, 'all')
%   info = showbdvars(branches, [1 3 5])
%
% INPUT
%   branches    : structure array with fields .branch_number and .data
%   branch_spec : 'all' (default) or numeric array of branch numbers
%
% OUTPUT
%   info : structure array with fields
%            - branch_number
%            - variables
%
% EXAMPLES
%   showbdvars(branches)
%   showbdvars(branches, [1 2])

    narginchk(1, 2);

    if nargin < 2 || isempty(branch_spec)
        branch_spec = 'all';
    end

    if ~isstruct(branches) || isempty(branches)
        error('showbdvars:InvalidInput', ...
            'Input must be a non-empty structure array of branches.');
    end

    if ischar(branch_spec) || isstring(branch_spec)
        if strcmpi(branch_spec, 'all')
            idx = 1:numel(branches);
        else
            error('showbdvars:InvalidBranchSpec', ...
                'branch_spec must be ''all'' or a numeric vector of branch numbers.');
        end
    elseif isnumeric(branch_spec)
        idx = find(ismember([branches.branch_number], branch_spec));
        if isempty(idx)
            error('showbdvars:NoMatchingBranches', ...
                'No requested branch numbers were found.');
        end
    else
        error('showbdvars:InvalidBranchSpec', ...
            'branch_spec must be ''all'' or a numeric vector of branch numbers.');
    end

    info = struct('branch_number', {}, 'variables', {});

    fprintf('\nVariables available in selected branches:\n\n');

    for k = 1:numel(idx)
        i = idx(k);

        if ~isfield(branches(i), 'data') || ~istable(branches(i).data)
            error('showbdvars:InvalidBranchData', ...
                'branches(%d).data must be a table.', i);
        end

        vars = branches(i).data.Properties.VariableNames;

        info(end+1).branch_number = branches(i).branch_number; %#ok<AGROW>
        info(end).variables = vars;

        fprintf('Branch %d:\n', branches(i).branch_number);
        for j = 1:numel(vars)
            fprintf('  %s\n', vars{j});
        end
        fprintf('\n');
    end
end