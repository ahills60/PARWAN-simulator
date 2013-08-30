function commander(filename)

fin = fopen(filename, 'r'); % Open the file with the provided filename
% Clear the workspace
evalin('base', 'clear');
% Create a cellular object to store the code line by line
evalin('base', 'CODEBASE = {};');

% Set the current line number to 1
lineNo = 1;

% Set a place to keep track of 'at' statements -- used to determine which
% page to use
evalin('base', 'atPoints = [];');
evalin('base', 'atPointsVal = [];');

% Set a place to keep track of the number of variables on a particular
% page. Used for memory offsetting memory
evalin('base', 'varsOnPage = zeros(1, 16);');

% Set the Accumulator to 8 zeros
evalin('base', 'ACC = zeros(1, 8);');
% Set the vczn Flags to 4 zeros
evalin('base', 'FLG = zeros(1, 4);');
% Set the memory to be 4096 long and 8 wide (for bits)
evalin('base', 'mem = zeros(4096, 8);');
% Set the current Page to 0
evalin('base', 'PGE = 0;');

disp('Loading file...');
% Load variables and label lines. Loop forever or until a break
while 1
    scriptline = fgetl(fin);
    % Check to see if the end of the file has been reached
    if ~ischar(scriptline)
        % End of file. Exit this while loop
        break;
    end
    
    scriptline = strtrim(scriptline); % Remove whitespace after and before statement
    scriptline = strrep(scriptline, '''', ''''''); % sanitise input by changing ' into ''
    
    if length(scriptline) > 4
        if strcmpi(scriptline(end-2:end), ' if')
            % line has word 'if'. Append 'stat' to avoid confusion
            disp('   Warning: Detected ''if'' label or object. Renaming to ''ifstat''');
            scriptline = [scriptline 'stat'];
        elseif strcmpi(scriptline, 'label end') || strcmpi(scriptline, 'jmp end')
            % if it's a looping end, remove it otherwise MATLAB will also
            % loop forever
            scriptline = '';
        end
    end
    % Save this line of code into the CODEBASE variable
    evalin('base', ['CODEBASE{' int2str(lineNo) '} = ''' scriptline ''';']);
    
    % Parse this line of code by removing comments, then separate command
    % from parameters (if any)
    [com, vari] = strtok(lower(strtok([' ' scriptline], '#')), ' ');
    % Clean up command and parameters by removing possible white space
    % before and after the strings
    vari = strtrim(vari);
    com = strtrim(com);
    % Determine which command this could be. At this point in the program,
    % we only wish to find 'at' statements, labels and the values of bits.
    switch com
        case 'label'
            % Store the label as a variable whose value is the line number
            evalin('base', [vari ' = ' int2str(lineNo) ';']);
        case 'int'
            % Integer syntax: int variable_name 123
            % vari at this point contains "variable_name 123".
            % the vari parameter should be broken up further to give the
            % variable name and its value.
            [vari, val] = strtok(lower(vari), ' ');
            
            vari = strtrim(vari); % Clean up the variable name by removing possible white space before and after its contents
            val = mat2str(dec2bin(str2double(strtrim(val)), 8) == '1'); % Convert the value into a 8-bit array.
            evalin('base', [vari ' = ' val ';']); % Save this variable within the workspace
            
            % Now Determine if the page for this variable exists
            res = evalin('base', ['exist(''' vari '_PGE'', ''var'')']);
            if res == 0
                % No variable exists with this name (so no page information).
                
                % Check to see if we've reached an 'at' point.
                if evalin('base', 'length(atPointsVal) > 0')
                    % We have at points. Determine the page number
                    atPointsVal = evalin('base', 'atPointsVal');
                    byteNo = atPointsVal(end) + 1; % Take the last one and add 1 to get the byte number
                    pageno = sum(1:256:4096 <= byteNo) - 1; % determine the page number by counting the number of 'trues'
                    evalin('base', [vari '_PGE = ' int2str(pageno) ';']); % Store variable's page number
                    % Now store the result into the memory space of that
                    % page.
                    evalin('base', ['mem(1 + varsOnPage(' int2str(pageno + 1) ') + (' int2str(pageno) ' * 256), :) = ' val ';']);
                    % And update the statistic of how many variables we
                    % have on this page.
                    evalin('base', ['varsOnPage(' int2str(pageno + 1) ') = varsOnPage(' int2str(pageno + 1) ') + 1;']);
                else
                    % Probably on page 0
                    evalin('base', [vari '_PGE = 0;']); % Store variable's page number
                    % Now store the result into the memory space of page 0
                    evalin('base', ['mem(1 + varsOnPage(1), :) = ' val ';']);
                    % And say that we have on more variable on page 0
                    evalin('base', 'varsOnPage(1) = varsOnPage(1) + 1;');
                end
            end
        case 'at'
            % at line should be stored (as atPoints) and its parameter
            % should also be stored (vari).
            evalin('base', ['atPoints = [atPoints ' int2str(lineNo) '];']);
            evalin('base', ['atPointsVal = [atPointsVal ' vari '];']);
    end
    % Increment the line number
    lineNo = lineNo + 1;
end
fclose(fin);
disp('File loaded.');

% Set the program counter to 1
evalin('base', 'PC = 1;');

disp('Running program...')
while evalin('base', 'PC') < lineNo % Whilst the program counter hasn't reached the last line of code, do the following...
    % Run line by line by sending a line of code stored within CODEBASE to
    % the inter() function
    evalin('base', 'inter(CODEBASE{PC});');
end
disp('Program Complete.');