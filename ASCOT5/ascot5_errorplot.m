function ascot5_errorplot(a5file,runid)
%ASCOT5_ERRORPLOT Plots location of markers with errors
%   The ASCOT5_ERRORPLOT routine plots information about markers which end
%   with an errorstate.  The code takes the name of an ASCOT5 HDF5 file and
%   a runid from that file.
%
%   Example:
%       a5file='ascot5_test.h5';
%       runid=0396210459;
%       ascot5_errorplot(a5file,runid);
%
%   Maintained by: Samuel Lazerson (samuel.lazerson@ipp.mpg.de)
%   Version:       1.0  


% Helpers
amu = 1.66053906660E-27;
ec = 1.60217662E-19;

% Check for file
if ~isfile(a5file)
    disp(['ERROR: ' a5file ' file not found!']);
    return;
end

% from error.h
file_errs={'mccc_wiener.c','mccc_push.c','mccc_coefs.c','mccc.c','step_fo_vpa.c',...
    'step_gc_cashkarp.c','step_gc_rk4.c','N0_3D.c','N0_ST.c','B_3DS.c',...
    'B_2DS.c','B_STS.c','B_GS.c','plasma_1D.c','plasma_1DS.c',...
    'plama.c','E_field.c','neutral.c','E_1DS.c','B_field.c',...
    'particle.c'};

endpath = ['/results/run_' num2str(runid,'%10.10i') '/endstate/'];
inipath = ['/results/run_' num2str(runid,'%10.10i') '/inistate/'];
try
    endcond = h5read(a5file,[endpath '/endcond']);
catch
    disp(['ERROR: Could not find run number or endstate: ' num2str(runid,'%10.10i')]);
    return;
end
errorline = h5read(a5file,[endpath '/errorline']);
errormod = h5read(a5file,[endpath '/errormod']);
errormsg = h5read(a5file,[endpath '/errormsg']);

% Now handle errors
if any(errormsg~=0)
    % Get some grid info for plotting grids
    gridid=h5readatt(a5file,'/bfield','active');
    disp(['  Using bfieldid: ' gridid]);
    gridpath = ['/bfield/B_STS_' num2str(gridid,'%10.10i') ''];
    rmax = h5read(a5file,[gridpath '/b_rmax']);
    rmin = h5read(a5file,[gridpath '/b_rmin']);
    zmax = h5read(a5file,[gridpath '/b_zmax']);
    zmin = h5read(a5file,[gridpath '/b_zmin']);
    pmax = h5read(a5file,[gridpath '/axis_phimax']);
    pmin = h5read(a5file,[gridpath '/axis_phimin']);
    raxis = h5read(a5file,[gridpath '/axisr']);
    zaxis = h5read(a5file,[gridpath '/axisz']);
    
    % Read ini and endstates
    rhostart   = h5read(a5file,[inipath '/rho']);
    thstart   = h5read(a5file,[inipath '/theta']);
    rstart   = h5read(a5file,[inipath '/r']);
    pstart   = h5read(a5file,[inipath '/phi']);
    zstart   = h5read(a5file,[inipath '/z']);
    mstart   = h5read(a5file,[inipath '/mass']).*amu;
    vllstart   = h5read(a5file,[inipath '/ppar'])./mstart;
    mustart   = h5read(a5file,[inipath '/mu']).*ec;
    brstart   = h5read(a5file,[inipath '/br']);
    bpstart   = h5read(a5file,[inipath '/bphi']);
    bzstart   = h5read(a5file,[inipath '/bz']);
    rhoend   = h5read(a5file,[endpath '/rho']);
    thend   = h5read(a5file,[endpath '/theta']);
    rend   = h5read(a5file,[endpath '/r']);
    pend   = h5read(a5file,[endpath '/phi']);
    zend   = h5read(a5file,[endpath '/z']);
    mend   = h5read(a5file,[endpath '/mass']).*amu;
    vllend   = h5read(a5file,[endpath '/ppar'])./mend;
    muend   = h5read(a5file,[endpath '/mu']).*ec;
    brend   = h5read(a5file,[endpath '/br']);
    bpend   = h5read(a5file,[endpath '/bphi']);
    bzend   = h5read(a5file,[endpath '/bz']);
    
    % Derived quantities
    xstart = rstart.*cosd(pstart);
    ystart = rstart.*sind(pstart);
    bstart = sqrt(brstart.*brstart+bpstart.*bpstart+bzstart.*bzstart);
    vpestart = sqrt(2.*mustart.*bstart./mstart);
    xend = rend.*cosd(pend);
    yend = rend.*sind(pend);
    bend = sqrt(brend.*brend+bpend.*bpend+bzend.*bzend);
    vpeend = sqrt(2.*muend.*bend./mend);
    
    
    fig = figure('Position',[1 1 1024 768],'Color','white','InvertHardCopy','off');
    num_part = sum(errormsg~=0);
    disp(['     Detected ' num2str(num_part,'%i') ' particles with errors!']);
    disp('ERRORS');
    error_range=unique(errormsg)';
    
    % Plot grid bounds
    phi = 0:2*pi./360:2*pi;
    subplot(2,2,1); hold on;
    plot3(rmin.*cos(phi),rmin.*sin(phi),zmin.*ones(1,361),'k');
    plot3(rmax.*cos(phi),rmax.*sin(phi),zmin.*ones(1,361),'k');
    plot3(rmin.*cos(phi),rmin.*sin(phi),zmax.*ones(1,361),'k');
    plot3(rmax.*cos(phi),rmax.*sin(phi),zmax.*ones(1,361),'k');
    plot3([rmin rmax].*cos(0),[rmin rmax].*sin(0),[zmin zmin],'k');
    plot3([rmin rmax].*cos(0),[rmin rmax].*sin(0),[zmax zmax],'k');
    plot3([rmin rmin].*cos(0),[rmin rmin].*sin(0),[zmin zmax],'k');
    plot3([rmax rmax].*cos(0),[rmax rmax].*sin(0),[zmin zmax],'k');
    
    % Plot magnetic axis
    nfp = round(360/pmax);
    raxis = repmat(raxis,[nfp 1])';
    zaxis = repmat(zaxis,[nfp 1])';
    phi = 0:2*pi./(length(raxis)-1):2*pi;
    xaxis = raxis.*cos(phi);
    yaxis = raxis.*sin(phi);
    plot3(xaxis,yaxis,zaxis,'r');
    
    
    % from error.c
    for i = error_range
        if i==0, continue;end % Change to i~=0 to only plot good particles
        err_dex = errormsg == i;
        num_part = sum(err_dex);
        subplot(2,2,1);
        plot3(xstart(err_dex),ystart(err_dex),zstart(err_dex),'o'); hold on;
        plot3(xend(err_dex),yend(err_dex),zend(err_dex),'+');
        subplot(2,2,3);
        plot(rhostart.*cos(thstart),rhostart.*sin(thstart),'o'); hold on;
        plot(rhoend.*cos(thend),rhoend.*sin(thend),'+');
        subplot(2,2,[2 4]);
        plot(vllstart(err_dex),vpestart(err_dex),'o'); hold on;
        plot(vllend(err_dex),vpeend(err_dex),'+'); hold on;
        
    end
    subplot(2,2,1); axis equal; axis off;
    subplot(2,2,3); 
    plot(cosd(0:360),sind(0:360),'k');
    plot(cosd(0:360)/2,sind(0:360)/2,'--k');
    plot(cosd(0:360)/4,sind(0:360)/4,'--k');
    plot(cosd(0:360).*1.25,sind(0:360).*1.25,'--k'); axis equal;
    
end

end

