function output = MAUTOLAB(filename)
% MAUTOLAB  Unified reader for AUTO-07p output files.
%
%   data = MAUTOLAB('lor')
%
% Reads b.lor, d.lor, s.lor from the current working directory.
% Reader functions are loaded from the MAUTOLAB subfolders.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(rootDir, 'b_files'));
    addpath(fullfile(rootDir, 'd_files'));
    addpath(fullfile(rootDir, 's_files'));

    output = struct();
    output.filename = filename;

    bfile = ['b.' filename];
    dfile = ['d.' filename];
    sfile = ['s.' filename];

    if isfile(bfile)
        try
            output.bif_diagram = read_b_auto(bfile);
        catch ME
            warning('MAUTOLAB:read_b_failed', ...
                'Failed to read %s: %s', bfile, ME.message);
        end
    else
        warning('MAUTOLAB:missing_b', 'File %s not found.', bfile);
    end

    if isfile(dfile)
        try
            output.diagnostics = read_d_auto(dfile);
        catch ME
            warning('MAUTOLAB:read_d_failed', ...
                'Failed to read %s: %s', dfile, ME.message);
        end
    else
        warning('MAUTOLAB:missing_d', 'File %s not found.', dfile);
    end

    if isfile(sfile)
        try
            output.solutions = read_s_auto(sfile);
        catch ME
            warning('MAUTOLAB:read_s_failed', ...
                'Failed to read %s: %s', sfile, ME.message);
        end
    else
        warning('MAUTOLAB:missing_s', 'File %s not found.', sfile);
    end
end