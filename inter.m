function inter(myCommand)

% Clean the input by removing possible comments and then separate the
% command (cmd) from possible parameters (vari).
[com, vari] = strtok(lower(strtok([' ' myCommand], '#')), ' ');

% Clean the commands for possible white space before and after the contents
vari = strtrim(vari);
com = strtrim(com);

%evalin('base', 'disp(PC)');

% Pre-set the command to be blank
cmd = '';

% Before doing anything, raise the zero (z) flag (within FLG) to be 1 if
% the contents of the accumulator is zero.
evalin('base', 'if all(ACC == 0), FLG(3) = 1; else, FLG(3) = 0; end');
% Next do the same for the negative flag - determined by the msb within
% the accumulator.
evalin('base', 'if ACC(1), FLG(4) = 1; else, FLG(4) = 0; end');

if isempty(vari)
    % must be a single command to affect accumulator
    switch com
        case 'asr'
            % Shift to the right
            cmd = 'ACC = [ACC(1) ACC(1:end-1)]; FLG(4) = ACC(1)';
        case 'asl'
            % Shift to the left
            cmd = 'FLG(2) = ACC(1); FLG(1) = xor(ACC(1), ACC(2)); ACC = [ACC(2:end) 0]; FLG(4) = ACC(1);';
        case 'cmc'
            % Complement the carry
            cmd = 'FLG(2) = ~FLG(2)';
        case 'cma'
            % The Complement
            cmd = 'ACC = ~ACC & [1 1 1 1 1 1 1 0]';
        case 'cla'
            % Clear the accumulator
            cmd = 'ACC = [0 0 0 0 0 0 0 0];';
        case ''
            % No command
            cmd = '';
        otherwise
            disp(['Unrecognised command: ' com]);            
    end
else
    % extra
    switch com
        case 'lda'
            % Load the following variable into the accumulator
            cmd = ['ACC = ' vari];
        case 'sta'
            % Store the contents of the accumulator into the following variable 
            cmd = [vari ' = ACC'];
        case 'stai'
            % Store the contents of the accumulator into the memory address
            % within the following variable
            
            % See if a page number has been assigned to the variable
            % (designated variablename_PGE).
            res = evalin('base', ['exist(''' vari '_PGE'', ''var'')']);
            if res == 0
                % No variable exists with this name.
                evalin('base', [vari '_PGE = PGE;']); % Store variable's page number
            end
            
            % Perform the actual store with the necessary page offset
            cmd = ['mem(bin2dec(int2str(' vari ')) + 1 + (' vari '_PGE * 256), :) = ACC'];
        case 'ldai'
            % Load the contents of what's in the memory address (provided within 
            % the following variable) into the accumulator
            
            % See if a page number has been assigned to the variable
            % (designated variablename_PGE).
            res = evalin('base', ['exist(''' vari '_PGE'', ''var'')']);
            if res == 0
                % No variable exists with this name.
                evalin('base', [vari '_PGE = PGE;']); % Store variable's page number
            end
            % Perform the actual load with the necessary page offset
            cmd = ['ACC = mem(bin2dec(int2str(' vari ')) + 1 + (' vari '_PGE * 256), :)'];
        case 'jmp'
            % Check to see if there's a page jump inbetween
            PC = evalin('base', 'PC'); % Get program counter
            atPoints = evalin('base', 'atPoints'); % get the line numbers of the 'at' commands
            atPointsVal = evalin('base', 'atPointsVal'); % get the byte values of the 'at' commands
            location = evalin('base', vari); % Get the line number of where we will be jumping to
            % Produce a logical expression that represents the difference
            % between where I am now and where I will be. Any differences
            % indicate a page change.
            atPoints = xor(atPoints <= location, atPoints <= PC);
            if any(atPoints)
                % At least one page change in between here and there
                atPoints = atPointsVal(atPoints); % Get their values
                byteNo = atPoints(end) + 1; % Take the last one and add 1 to get the byte number
                pageno = sum(1:256:4096 <= byteNo) - 1; % determine the page number by counting the number of 'trues'
                disp(['    Page update: ' int2str(pageno)])
                evalin('base', ['PGE = ' int2str(pageno) ';']);
            end
            cmd = ['PC = ' vari];
        case 'brav'
            % Branch if overflowed
            flg = evalin('base', 'FLG');
            if flg(1) == 1
                % Overflow has been set
                cmd = ['PC = ' vari]; % Set program counter to contents of variable
            end
        case 'brac'
            % Branch if carry
            flg = evalin('base', 'FLG');
            if flg(2) == 1
                % Carry flag has been set
                cmd = ['PC = ' vari]; % Set program counter to contents of variable
            end
        case 'braz'
            % Branch if zero
            flg = evalin('base', 'FLG');
            if flg(3) == 1
                % Zero flag has been set
                cmd = ['PC = ' vari];  % Set program counter to contents of variable
            end
        case 'bran'
            % Branch if negative
            flg = evalin('base', 'FLG');
            if flg(4) == 1
                % Negative flag has been set
                cmd = ['PC = ' vari]; % Set program counter to contents of variable
            end
        case 'and'
            % Perform logical and with variable and accumulator
            cmd = ['ACC = ACC & ' vari ';'];
        case 'add'
            % Addition
            flg = evalin('base', 'FLG');
            acc = evalin('base', 'ACC');
            vari = evalin('base', vari);
            
            % Take the signed carry
            res = zeros(1, 8);
            carry = zeros(1, 8);
            res(end) = xor(xor(acc(end), vari(end)), 0); %flg(2));
            carry(end) = xor(acc(end), vari(end)) && 0 || (acc(end) && vari(end)); % flg(2) || (acc(end) && vari(end));
            for i = 7:-1:1
                res(i) = xor(xor(acc(i), vari(i)), carry(i+1));
                carry(i) = xor(acc(i), vari(i)) && carry(i+1) || (acc(i) && vari(i));
            end
            
            % Check to see if the carry flag is raised
            flg(2) = carry(1);
            % Determine if there's an overflow
            if acc(1) == vari(1) && res(1) ~= acc(1)
                flg(1) = 1;
            else
                flg(1) = 0;
            end
            cmd = ['FLG = ' mat2str(flg) '; ACC = ' mat2str(res)];
        case 'addi'
            % Add from memory location...
            flg = evalin('base', 'FLG');
            acc = evalin('base', 'ACC');
            res = evalin('base', ['exist(''' vari '_PGE'', ''var'')']);
            if res == 0
                % Store variable's page number
                evalin('base', [vari '_PGE = PGE;']); 
            end
            % From the mem variable, load mem(vari + 1 + (PAGE_OFFSET))
            vari = evalin('base', ['mem(bin2dec(int2str(' vari ')) + 1 + (' vari '_PGE * 256), :)']);
            res = zeros(1, 8); % An empty space for the result
            carry = 0; % flg(2); % Retrieve the carry flag
            for i = 8:-1:1
                if acc(i) && vari(i)
                    % 1 + 1 --> carry
                    if carry == 1
                        % 1 + 1 + 1 = 1 + carry, so don't remove carry
                        res(i) = 1;
                    end
                    carry = 1;
                elseif acc(i) == 0 && vari(i) == 0
                    % 0 + 0
                    if carry == 1
                        % We have a carry to add
                        res(i) = 1;
                        carry = 0; % Remove carry
                    end
                else
                    % 0 + 1 or 1 + 0
                    if carry == 0
                        % No carry, so it's simply 0 + 1 or 1 + 0
                        % If there was a carry, it'll be 1 + 1 --> carry,
                        % so no change to res(i) nor carry flag.
                        res(i) = 1;
                    end
                end
            end
            % Check to see if the carry flag is raised. If so, set the FLG
            % carry flat to 1
            if carry == 1
                % Carry flag. Set FLG(2) (carry) to 1.
                flg(2) = 1;
            else
                flg(2) = 0;                
            end
            % Determine overflow
            if acc(1) == vari(1) && res(1) ~= acc(1)
                flg(1) = 1;
            else
                flg(1) = 0;
            end
                        
            cmd = ['FLG = ' mat2str(flg) '; ACC = ' mat2str(res)];
        case 'sub'
            % Subtraction.
            flg = evalin('base', 'FLG');
            acc = evalin('base', 'ACC');
            vari = evalin('base', vari);
            
            % Take the signed carry
            cin_signed = 1; % xor(flg(2), 1);
            b_signed = ~vari;
            res = zeros(1, 8);
            carry = zeros(1, 8);
            res(end) = xor(xor(acc(end), b_signed(end)), cin_signed);
            carry(end) = xor(acc(end), b_signed(end)) && cin_signed || (acc(end) && b_signed(end));
            for i = 7:-1:1
                res(i) = xor(xor(acc(i), b_signed(i)), carry(i+1));
                carry(i) = xor(acc(i), b_signed(i)) && carry(i+1) || (acc(i) && b_signed(i));
            end
            
            % Check to see if the carry flag is raised
            flg(2) = carry(1);
            % Determine if there's an overflow
            if acc(1) == b_signed(1) && res(1) ~= acc(1)
                flg(1) = 1;
            else
                flg(1) = 0;
            end
            cmd = ['FLG = ' mat2str(flg) '; ACC = ' mat2str(res)];
        case 'at'
            % An 'at' command has been reached. Determine which page we
            % should be using now.
            
            % Check the memory location we should be at...
            byteNo = str2double(vari) + 1; % + 1 to accomodate for indexing offset
            % Calculate which page file we're in by seeing which of the 256
            % partitions we lie in. We subtract 1 because page numbers start
            % at 0.
            pageno = sum(1:256:4096 <= byteNo) - 1;
            disp(['    Page update: ' int2str(pageno)])
            cmd = ['PGE = ' int2str(pageno)];
        case {'label', 'int'}
            % Commands that are recognised, but should not compute them
            cmd = '';
        otherwise
            disp(['Unrecognised command: ' com ' with variable ' vari ]);
    end
end


try
    % Try to evaluate the create expression within the base workspace
    evalin('base', [cmd ';']);
    % Alter flags again
    evalin('base', 'if all(ACC == 0), FLG(3) = 1; else, FLG(3) = 0; end');
    % Next do the same for the negative flag - determined by the msb within
    % the accumulator.
    evalin('base', 'if ACC(1), FLG(4) = 1; else, FLG(4) = 0; end');
catch
    % For exceptions
    disp('Error evaluating command')
    disp(myCommand)
    disp('Translated:')
    disp(cmd)
    disp(['PC: ' int2str(evalin('base', 'PC'))])
    error('Error occurred when attempting to run code. Halting.');
end
% Increment program counter
evalin('base', 'PC = PC + 1;');