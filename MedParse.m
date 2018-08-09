% MedParse : Eyal's Revision of Kumar's function file_parser.m, Laubach Lab 2003
% Parses MedPC files to return arrays of called flags
% Inifitally modified in 2003 to speed up by doing all operation in ram
% Modified in Feb 2006 to speed up by fread'ing instead of fscan'ing
% Also, feature changes:
%      can find and return multiple parameters
%      (significantly faster since fewer reads from disk)
%      can now return script names/header info
% 
% Usage:
% function varargout = MedParse(filename, flags); 
% eg: [protocol, foreperiods, time_np_in, time_np_out] = MedParse(filename, 'MSN', 'B', 'E', 'I');

function [varargout] = MedParse(filename, varargin)

num_flags = length(varargin);
% check in's and out's
if nargout ~= num_flags
    fprintf ('Passed in %d flags, but only ready to collect %d vars.\n', num_flags, nargout);
	% return empty arrays
	for i_var=1:nargout
        varargout(i_var) = {[]};
	end
    return;
end

% check file
fid = fopen(filename, 'r');
if fid == -1
    fprintf ('Incorrect file: %s\n', filename)
	% return empty arrays
	for i_var=1:nargout
        varargout(i_var) = {[]};
	end
    return;
end

% Scans the entire file in as a string, with spaces (to preserve number info)
file_char = fread(fid, inf, 'uchar=>char'); % faster than fscanf. textread fails on string data
fclose(fid); 

% if isempty(varargin) % If no arguments passed in, return whole thing as struct?

% make sure temp is not looking at first or last char of file_double
% will cause error below. first char is an F for Filename, so this will happen
file_char([1, end]) = 0;
% file_letter_mask = isletter(file_char);
file_letter_pos = find(isletter(file_char));

for i_flag = 1:num_flags
    flag = varargin{i_flag};
    start_parse = [];
    
	if length(flag) > 1
    	% scan for a string (such as protocol or date)
        % translate numbers into chars for protocol search
        file_char = file_char(:)'; % need transpose for strfind
        idx_start = strfind(file_char, flag); % strfind faster than findstr per http://blogs.mathworks.com/loren/?cat=2
        % advance past flag
        idx_start = idx_start + length(flag) + 2;
        % find end of line. should be just a few steps, so search stepwise in a for loop
        idx_end = idx_start + 1;
        while file_char(idx_end) ~= char(13)
            idx_end = idx_end+1;
        end
		varargout(i_flag) = {file_char(idx_start:idx_end-1)};
        % Regexp style? % https://www.mathworks.com/help/matlab/ref/regexp.html
    else
    	% scan for a letter of a variable
        % do this as numbers to speed up
        flag = double(flag);
		% Finds all the values equal to the _parse Flags, and then only keeps the ones with a colon. 
		possible_starts = find(file_char == flag);
		num_possible_starts = length(possible_starts);
		for i_start = 1:num_possible_starts
            % letter should be preceded by a new line (ascii code 10 or 13, not sure why MedPC uses both) and followed by a colon
            if (file_char(possible_starts(i_start) - 1) == 13 || ...
                file_char(possible_starts(i_start) - 1) == 10 )  && ...
                file_char(possible_starts(i_start) + 1) == double(':')
                start_parse = possible_starts(i_start) + 3; % +3 to bypass char itself and : after and newline
                break
            end
		end
		
		% Now search from start_parse for next letter. that will be the stop_parse
        if ~isempty(start_parse)
            possible_stops = file_letter_pos(file_letter_pos > start_parse);
            % or, may get to end of file, in which case stop should be eof
            if isempty(possible_stops)
                stop_parse = length(file_char);
            else
                % -2 to remove last offending letter picked up and newline prior
                stop_parse = possible_stops(1) - 2;
            end

            % if start is greater than stop, or if they are not initialized
            if start_parse > stop_parse
                fprintf ('\n Check your variables'); 
                return;
            end

            % Clips out the string from the file, does not include flags
            parsed_str = file_char(start_parse:stop_parse); 

            % Finds all the colons, and deletes them and the number before them
            colons = find(parsed_str == double(':'));
            num_colons = length(colons);
            for i_colon = 1:num_colons
                parsed_str((colons(i_colon)-6):colons(i_colon)) = double(' ');
            end

            varargout(i_flag) = {sscanf(char(parsed_str), '%f')};
        else
            fprintf('Flag %s not found.', flag); 
            varargout(i_flag) = NaN;
        end
	end
end

