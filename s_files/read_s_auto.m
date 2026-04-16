function sols = read_s_auto(filename)
%READ_S_AUTO Read all solution entries from an AUTO s.XXX file
%   Reads the file line-by-line to properly handle AUTO formatting rules.

fid = fopen(filename, 'r');
if fid == -1
    error('Could not open file %s', filename);
end

sols = cell(0,1);

read_next_block = true;
while ~feof(fid)
    % Read header line (16 integers)
    line = fgetl(fid);
    if ~ischar(line), break; end
    header = sscanf(line, '%d');
    if numel(header) < 16, break; end

    sol.IBR    = header(1);
    sol.PT     = header(2);
    sol.ITP    = header(3);
    sol.LAB    = header(4);
    sol.NFPR   = header(5);
    sol.ISW    = header(6);
    sol.NTPL   = header(7);
    sol.NAR    = header(8);
    sol.NROWPR = header(9);
    sol.NTST   = header(10);
    sol.NCOL   = header(11);
    sol.NPAR   = header(12);
    sol.NPARI  = header(13);
    sol.NDIM   = header(14);
    sol.IPS    = header(15);
    sol.IPRIV  = header(16);

    % Compute sizes
    nU_lines = floor(sol.NDIM/7 + 1) * sol.NTPL;
    nU_cols  = sol.NAR;
    nICP_rows = floor((sol.NFPR + 19)/20);
    nRLDOT_rows = floor((sol.NFPR + 6)/7);
    nUDOT_lines = floor(sol.NDIM/7 + 1) * sol.NTPL;
    nUDOT_cols = sol.NDIM;
    nPAR_rows = floor((sol.NPAR + 6)/7);

    % Read U block
    sol.t = [];
    sol.U = [];
    for i = 1:nU_lines
        if feof(fid), break; end
        line = fgetl(fid);
        line = strrep(line, 'D', 'E');
        nums = sscanf(line, '%f')';
        sol.t(end+1,1) = nums(1); %#ok<AGROW>
        sol.U(end+1,:) = nums(2:end); %#ok<AGROW>
    end

    % ICP indices
    sol.ICP = [];
    for i = 1:nICP_rows
        if feof(fid), break; end
        line = fgetl(fid);
        line = strrep(line, 'D', 'E');
        nums = sscanf(line, '%f')';
        sol.ICP = [sol.ICP, nums]; %#ok<AGROW>
    end
    sol.ICP = sol.ICP(:);

    % RLDOT
    sol.RLDOT = [];
    for i = 1:nRLDOT_rows
        if feof(fid), break; end
        line = fgetl(fid);
        line = strrep(line, 'D', 'E');
        nums = sscanf(line, '%f')';
        sol.RLDOT = [sol.RLDOT, nums]; %#ok<AGROW>
    end
    sol.RLDOT = sol.RLDOT(:);

    % UDOT block
    sol.UDOT = [];
    for i = 1:nUDOT_lines
        if feof(fid), break; end
        line = fgetl(fid);
        line = strrep(line, 'D', 'E');
        nums = sscanf(line, '%f')';
        sol.UDOT(end+1,:) = nums; %#ok<AGROW>
    end

    % Parameters (read line-by-line and accumulate)
    sol.PAR = [];
    for i = 1:nPAR_rows
        if feof(fid), break; end
        line = fgetl(fid);
        if ~ischar(line), break; end
        line = strrep(line, 'D', 'E');
        nums = sscanf(line, '%f')';
        sol.PAR = [sol.PAR, nums]; %#ok<AGROW>
    end
    sol.PAR = sol.PAR(:);

    sols{end+1,1} = sol;
end

fclose(fid);
end
