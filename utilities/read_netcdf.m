function data = read_netcdf(filename,varargin)
%data=READ_NETCDF(filename[,'flipdim','strip']) Extracts netcdf file to structure
%   This function extracts a netcdf file into a structure which is
%   returned to the command line.  You need only specify a filename of a
%   netCDF file.  This version uses MATLAB's built-in netcdf package to
%   read data directly from the netCDF file.  All '+' are converted to 'p'
%   and '-' to 'n' in attribute, dimension, and variable names.  All '.'
%   are converted to underscores.
%
%   Options:
%   READ_NETCDF(filename,'flipdim') This will automatically permute the
%   arrays read from the file in reverse order.
%
%   READ_NETCDF(filename,'strip') This will strip non-alphanumerica
%   characters from element names to allow them to be used as structure
%   elements.
%
%   Example
%       data=read_netcdf('input.nc');
%
%   Version 1.6
%   Maintained by: Samuel Lazerson (lazerson@pppl.gov)
%   Date  03/05/2025

% Allow the user to pass some variables.
flipdim = 0;
strip = 0;
maxlength = namelengthmax;
if nargin > 1
    for i = 2:nargin
        switch varargin{i-1}
            case 'flipdim'
                flipdim = 1;
            case 'strip'
                strip = 1;
        end
    end
end

% Open the File
try
    ncid = netcdf.open(filename, 'NOWRITE');
catch read_netcdf_error
    data = -1;
    disp(['ERROR: Opening netCDF File: ' filename]);
    disp(['  -identifier: ' read_netcdf_error.identifier]);
    disp(['  -message:    ' read_netcdf_error.message]);
    disp('      For information type:  help read_netcdf');
    return
end

% Get information on number of elements
[ndimen, nvars, ngatts, unlimidimid] = netcdf.inq(ncid);

% Get global attributes
for i = 0:ngatts-1
    attname = netcdf.inqAttName(ncid, netcdf.getConstant('NC_GLOBAL'), i);
    attname = sanitize_name(attname, strip, maxlength);
    try
        attvalue = netcdf.getAtt(ncid, netcdf.getConstant('NC_GLOBAL'), attname);
        data.(attname) = attvalue;
    catch
        disp(['Warning: Attribute ' attname ' not found.']);
    end
end

% Get dimensions
for i = 0:ndimen-1
    [dimname, dimlen] = netcdf.inqDim(ncid, i);
    dimname = sanitize_name(dimname, strip, maxlength);
    data.(dimname) = dimlen;
end

% Get variables
for i = 0:nvars-1
    [varname, xtype, dimids, natts] = netcdf.inqVar(ncid, i);
    varname = sanitize_name(varname, strip, maxlength);
    varvalue = netcdf.getVar(ncid, i);
    if flipdim
        varvalue = permute(varvalue, ndims(varvalue):-1:1);
    end
    data.(varname) = varvalue;
    for j = 0:natts-1
        attname = netcdf.inqAttName(ncid, i, j);
        attname = sanitize_name(attname, strip, maxlength);
        try
            attvalue = netcdf.getAtt(ncid, i, attname);
            data.([varname '_' attname]) = attvalue;
        catch
            disp(['Warning: Attribute ' attname ' for variable ' varname ' not found.']);
        end
    end
end

% Close the file
netcdf.close(ncid);

end

function name = sanitize_name(name, strip, maxlength)
    name(name == '.') = '_';
    name(name == '-') = 'n';
    name(name == '+') = 'p';
    if strip
        name(~isstrprop(name, 'alphanum')) = '';
    end
    if length(name) > maxlength
        name = name(1:maxlength);
    end
    if ~isletter(name(1))
        name = ['x' name];
    end
end