function dist = beams3d_getdistrpz(data,r,phi,z,vll,vperp)
%BEAMS3D_GETDISTPRZ Calculates the distribution function
%   This BEAMS3D_GETDISTRPZ function calculates the distribution function
%   at a position in the cylindrical phase space given a BEAMS3D data
%   structure as returned by READ_BEAMS3D.  Either a single point or array
%   of points can be passed to the funciton as R [m], PHI (rad), Z [m],
%   V_parallel [m/s], and vperp [m/s].  Points which fall outside the
%   domain return 0.  The function returns a 2D array of size (NBEAMS,
%   NPTS) where NPTS is the nubmer of requested datapoints.
%
% Example usage
%      % Return an RPZ shaped array
%      beam_data = read_beams3d('beams3d_test.h5');
%      raxis   = 4.5:0.05:6.5;
%      zaxis   = -1.0:0.05:1.0;
%      paxis   = 0:2*pi/40:2*pi;
%      vmax    = beam_data.partvmax;
%      vllaxis = -vmax:2.*vmax./31:vmax;
%      vperpaxis = 0:vmax./15:vmax;
%      [R,P,Z,V,W] = ndgrid(raxis,paxis,zaxis,vllaxis,vperpaxis);
%      nsave = size(R);
%      ntotal = prod(nsave);
%      R = reshape(R,[1 ntotal]);
%      P = reshape(P,[1 ntotal]);
%      Z = reshape(Z,[1 ntotal]);
%      V = reshape(V,[1 ntotal]);
%      W = reshape(W,[1 ntotal]);
%      dist=beams3d_getdistrpz(beam_data,R,P,Z,V,W);
%      dist = reshape(dist,[size(dist,1) nsave]);
%
% Maintained by: Samuel Lazerson (samuel.lazerson@ipp.mpg.de)
% Version:       1.20

% Developer note, as of v2.9 BEAMS3D normalizes dist5D by m^3/s^3, meaning
% there is no volume normalization.  Now we can get dV for each flux
% surface easily.  However we have problems when calculating the dV for
% each voxel.  A trivial (but oversimplified) view is to divide by the
% number of voxels (nu*nv).  Which is what we do for now.

% Helpers
vt=vll+data.partvmax;
ds=1.0;
du=2*pi;
dp=2*pi;
dv=2*data.partvmax;
dw=data.partvmax;

% Interpolate
S   = permute(data.S_ARR,[2 1 3]);
U   = permute(data.U_ARR,[2 1 3]);
pgrid = mod(phi,data.phiaxis(end));
sval= interp3(data.raxis,data.phiaxis,data.zaxis,...
    S,r,pgrid,z);
uval= interp3(data.raxis,data.phiaxis,data.zaxis,...
    U,r,pgrid,z);
pval = mod(phi,2*pi);
rhoval = sqrt(sval);


% Calculate indexes
dexr=floor(data.ns_prof1.*rhoval./ds)+1;
dexu=min(floor(data.ns_prof2.*uval./du)+1,data.ns_prof2);
dexp=floor(data.ns_prof3.*pval./dp)+1;
dexv=floor(data.ns_prof4.*vt./dv)+1;
dexw=floor(data.ns_prof5.*vperp./dw)+1; %verp defined as zero

mask1=and(dexr>0,dexr<=data.ns_prof1);
mask3=and(dexp>0,dexp<=data.ns_prof3);
mask4=and(dexv>0,dexv<=data.ns_prof4);
mask5=and(dexw>0,dexw<=data.ns_prof5);
maskt=(mask1 & mask3 & mask4 & mask5);

% Normalize dist_prof by volume
dist5d_norm=data.dist_prof;
edges=0:1./data.ns_prof1:1;
rho_b3d = 0.5.*(edges(1:end-1)+edges(2:end));
[s,~,Vp]=beams3d_volume(data);
deltaV = pchip(sqrt(s),2.*Vp.*sqrt(s),rho_b3d)./data.ns_prof1;
deltaV = deltaV./(data.ns_prof2.*data.ns_prof3);
for i=1:data.ns_prof1
    dist5d_norm(:,i,:,:,:,:) = dist5d_norm(:,i,:,:,:,:)./deltaV(i);
end


dist=zeros(data.nbeams,length(r));
for i=1:length(maskt)
    if maskt(i)
        dist(:,i) = dist5d_norm(:,dexr(i),dexu(i),dexp(i),dexv(i),dexw(i));
    end
end

end

