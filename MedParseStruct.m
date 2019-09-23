% MedParseStruct
% Parses MedPC files to return a struct by flags (character fields before colons)
%
% Usage:
% data_struct = MedParseStruct(filename)

function data_struct = MedParseStruct(filename)

%% check file
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
file_char = file_char(:)'; % As row for regexp below

%% Look for letter: (colon space) as intiatior of flag
% [a, b, c, d] = regexp(file_char', '([A-Za-z ]+: )([\d: \s]+)')
[str_match, idx_start, idx_end] = regexp(file_char, '([A-Za-z ]+:\s)', 'match');
temp_start = [idx_start, numel(file_char)+1];
for i_match = 1:numel(str_match)
    temp_field = str_match{i_match}(1:end-2);
    temp_field = temp_field(temp_field ~= ' ');
    temp_data = file_char((idx_end(i_match)+1):(temp_start(i_match+1)-1));
    
    if ~isempty(regexp(temp_data, '[A-Za-z]', 'once'))
        % Then clearly char/string text
        temp_data = temp_data(temp_data ~= 10 & temp_data ~= 13);
    elseif ~isempty(regexp(temp_data, '\d{1,2}[/:]\d{1,2}[/:]\d{1,2}', 'once'))
        % Then date or time: keep as string for now
        temp_data = temp_data(temp_data ~= 10 & temp_data ~= 13);
    elseif sum(temp_data == ':')
        % Numerical arrays (previously excluded dates/times)
        % Finds all the colons, and deletes them and the number before them
        colons = find(temp_data == double(':'));
        num_colons = length(colons);
        for i_colon = 1:num_colons
            temp_data((colons(i_colon)-6):colons(i_colon)) = double(' ');
        end
        
        temp_data = sscanf(char(temp_data), '%f');
    else
        % Single number
        temp_data = str2double(temp_data);
    end
    
    data_struct.(temp_field) = temp_data;
end

