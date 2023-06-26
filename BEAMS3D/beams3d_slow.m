function data=beams3d_slow(varargin)
%BEAMS3D_SLOW(beam_data,vmec_data) Calculates flux surface slowing down
%   The BEAMS3D_SLOW routine calculates the slowing down power deposition
%   assuming that the particles slow down on flux surfaces after being
%   born.
%
%   Optional Arguments
%       'plots'     : Create plots
%       'beams'     : Downselect beamlines considered
%       'mass'      : Plasma mass [kg] (assumes protons otherwise)
%                       data=beams3d_slow(beam_data,vmec_data,'beams',4:6);
%
%   Example usage
%      vmec_data = read_vmec('wout_test.nc');
%      beam_data = read_beams3d('beams3d_test.h5');
%      data=beams3d_slow(beam_data,vmec_data);
%
%   Maintained by: Samuel Lazerson (samuel.lazerson@ipp.mpg.de)
%   Version:       1.00

% Helpers
me = 9.10938356D-31;
ec = 1.60217662E-19;
hbar = 1.05457182E-34;
eps0 = 8.8541878128E-12;
amu = 1.66053906660E-27;
lplot = 0;
beam_dex = []; % Use to downselect beams
vmec_data=[];
beam_data=[];
data=[];
plasma_mass=[];
plasma_charge=[];
log_type = 3;
lboron=0;

% Handle varargin
if nargin > 0
    i=1;
    while i <= nargin
        if isstruct(varargin{i})
            if isfield(varargin{i},'datatype')
                if strcmp(varargin{i}.datatype,'wout')
                    vmec_data=varargin{i};
                elseif strcmp(varargin{i}.datatype,'BEAMS3D')
                    beam_data=varargin{i};
                end
            end
        else
            switch varargin{i}
                case 'plots'
                    lplot=1;
                case 'beams'
                    i=i+1;
                    beam_dex=varargin{i};
                case 'mass'
                    i=i+1;
                    plasma_mass=varargin{i};
                case 'BEAMS3D'
                    log_type=3;
                case 'full_logarithm'
                    log_type = 2;
                case 'NRLions_logarithm'
                    log_type = 4;
                case 'NRLions_logarithm_old'
                    log_type = 5;
                case 'boron'
                    lboron=1;
                    log_type=1;
                    i=i+1;
                    m_1=varargin{i}(1);
                    Z_1=varargin{i}(2);
                    m_2=varargin{i}(3);
                    Z_2=varargin{i}(4);
            end
        end
        i=i+1;
    end
end

if isempty(beam_data)
    disp('  You must provide BEAMS3D structure for Modeling');
    return;
end

%if isempty(vmec_data)
%    disp('  You must provide VMEC_DATA structure for Vp');
%    return;
%end

%Default to all beams
if isempty(beam_dex)
    beam_dex = unique(double(beam_data.Beam)');
end

% Sanity check on beams
if max(beam_dex) > max(beam_data.Beam)
    disp( '  Selected beam larger than availalbe beams');
    disp(['      beams: ' num2str(max(beam_dex),'%i')]);
    disp(['      beam_data: ' num2str(max(beam_data.Beam),'%i')]);
    return;
end

% Downselect beams
dex = zeros(1,length(beam_data.Beam));
for i = beam_dex(1:end)
    dex = dex + (beam_data.Beam' == i);
end
dex = dex > 0;

% Calc Vperp
vperp = beams3d_calc_vperp(beam_data);

% Calc dV/ds
if isempty(vmec_data)
    [s, ~, dVds] = beams3d_volume(beam_data);
    ra = sqrt(s);
    vp_spl = pchip(ra,2.*ra.*dVds);
else
    vmec_factor = 4*pi*pi; % normalization on Vp in VMEC
    s = 0:1./(vmec_data.ns-1):1;
    ra = sqrt(s);
    vp_spl = pchip(ra,2.*ra.*vmec_data.vp.*vmec_factor);
end

% Handle lack of plasma mass
if isempty(plasma_mass)
    plasma_mass = 1.6726219E-27;
    if isfield(beam_data,'plasma_mass')
        plasma_mass = beam_data.plasma_mass;
    end
end

% Handle lack of plasma charge
if isempty(plasma_charge)
    plasma_charge = 1.6726219E-27;
    if isfield(beam_data,'plasma_Zmean')
        plasma_charge = beam_data.plasma_Zmean*ec;
    end
end

% Check to see what type of run it is and extract information
ldex=1;
if any(beam_data.neut_lines(1,:) > 0) %NBI run
    ldex=2;
end
NEUT   = beam_data.neut_lines(ldex,:);
dex    = and(NEUT == 0,dex);
R_BEAM = beam_data.R_lines(ldex,dex);
B_BEAM = beam_data.B_lines(ldex,dex);
P_BEAM = mod(beam_data.PHI_lines(ldex,dex),max(beam_data.phiaxis));
Z_BEAM = beam_data.Z_lines(ldex,dex);
S_BEAM = beam_data.S_lines(ldex,dex);
SPEED  = sqrt(beam_data.vll_lines(ldex,dex).^2+vperp(ldex,dex).^2);
PITCH  = beam_data.vll_lines(ldex,dex)./SPEED;
W_BEAM = beam_data.Weight(dex)';
MASS   = beam_data.mass(dex)';
CHARGE = beam_data.charge(dex)';
myZ    = CHARGE./ec;
ZMEAN= beam_data.plasma_Zmean;
E_BEAM = (0.5).*MASS.*SPEED.*SPEED;

% Get profile information
NE   = permute(beam_data.NE,[2 1 3]);
NI   = permute(beam_data.NI,[1 3 2 4]);
TI   = permute(beam_data.TI,[2 1 3]);
TE   = permute(beam_data.TE,[2 1 3]);
ZEFF   = permute(beam_data.ZEFF_ARR,[2 1 3]);
ZEFF(isnan(ZEFF))=1;
MODB   = permute(sqrt(beam_data.B_R.^2+beam_data.B_PHI.^2+beam_data.B_Z.^2),[2 1 3]);
NE_BEAM= interp3(beam_data.raxis,beam_data.phiaxis,beam_data.zaxis,...
    NE,R_BEAM,P_BEAM,Z_BEAM);

num_species = sum(sum(beam_data.NI,[2,3,4])~=0);


if log_type==3 && num_species==1
    NI_AUX_Z = CHARGE(1)/ec; %TODO: revise
    NI_AUX_M = plasma_mass;
end

for i = 1:num_species
    NI_BEAM(i,:) = interp3(beam_data.raxis,beam_data.phiaxis,beam_data.zaxis,...
        squeeze(NI(i,:,:,:)),R_BEAM,P_BEAM,Z_BEAM);
end
TE_BEAM= interp3(beam_data.raxis,beam_data.phiaxis,beam_data.zaxis,...
    TE,R_BEAM,P_BEAM,Z_BEAM);
TI_BEAM= interp3(beam_data.raxis,beam_data.phiaxis,beam_data.zaxis,...
    TI,R_BEAM,P_BEAM,Z_BEAM);
ZE_BEAM= interp3(beam_data.raxis,beam_data.phiaxis,beam_data.zaxis,...
    ZEFF,R_BEAM,P_BEAM,Z_BEAM);
MODB_BEAM= interp3(beam_data.raxis,beam_data.phiaxis,beam_data.zaxis,...
    MODB,R_BEAM,P_BEAM,Z_BEAM);

if num_species==1 && lboron
    %%%%%%%%
    %CALCULATE ZMEAN FROM ZEFF AND ASSUMED BORON IMPURITY, and calculate
    %boron and ion density
    %%%%%%%%
    %     Z_1 = 1;%plasma_charge/ec;
    %     m_1 = 2.014;
    %
    %     Z_2 = 5;
    %     m_2 = 10.811;
    m_pl=m_1;
    %     Z_2 = 74;%TUNGSTEN
    %     m_2 = 183.84;%TUNGSTEN
    %     Z_2 = 6;%Carbon
    %     m_2 = 12.011;%Carbon
    %c_B=(max(beam_data.ZEFF_ARR,[],'all')-Z_D^2)/(Z_B^2-Z_B*Z_D^2); %Caution Max of ZEFF
    c_B=(ZE_BEAM-Z_1^2)/(Z_2^2-Z_2*Z_1^2); %Caution Max of ZEFF


    data.c_B=c_B(1);
    NI_BEAM(1,:) = NE_BEAM.*(1-Z_2.*c_B);
    NI_BEAM(2,:) = NE_BEAM.*c_B;
    NI_AUX_M(1)=m_1*amu;
    NI_AUX_M(2)=m_2*amu;
    NI_AUX_Z(1)=Z_1;
    NI_AUX_Z(2)=Z_2;

    plasma_mass(2) = plasma_mass.*m_2;
    plasma_charge(1)=Z_1*ec;
    plasma_charge(2)=Z_2*ec;
    num_species=2;

    disp('Adding Boron impurity to single ion run!');

    data.NI_BEAM=NI_BEAM;

    data.ZMEAN_set=ZMEAN;
    ZMEAN = Z_1^2/m_1*(1-Z_2*c_B)+c_B*Z_2^2/m_2;
    %ZMEAN=(NI_BEAM(1,:).*Z_1.^2/m_1 + NI_BEAM(2,:).*Z_2.^2/m_2) ./ (NE_BEAM);
    ZMEAN=ZMEAN(1);
    data.ZMEAN =ZMEAN;
end

% PInj
if size(W_BEAM,2) == 1, W_BEAM=W_BEAM'; end % Flip W
Pinj = sum(E_BEAM.*W_BEAM);
Iinj = sum(CHARGE.*W_BEAM);

% Calculate Values
TE3=TE_BEAM.^3;
beta = SPEED./299792458;
% denb =  N_BEAM;
% tempb=TE_BEAM/1000;%TI?
% zb = plasma_charge/ec;
ab = plasma_mass./amu;
at = MASS/amu;
% zt = CHARGE/ec;
% et = E_BEAM/ec/1000;
if log_type==1
    mae  = me.*MASS./(me+MASS);
    ue    = sqrt(ec.*TE_BEAM./me);
    uave2  = SPEED.*SPEED + ue.*ue;
    rmincle = myZ.*ZE_BEAM.*ec.*ec./(mae.*uave2);
    rminque = hbar./(2.*mae.*sqrt(uave2));
    rmine = max(rmincle,rminque);
    omegape2 = NE_BEAM.*ec.*ec./(me.*eps0);
    omegace = ec.*B_BEAM./me;
    omegae2 = omegape2+omegace.*omegace;
    for i=1:num_species
        map  = plasma_mass(i).*MASS./(plasma_mass(i)+MASS);
        Zi =NI_AUX_Z(i);
        ai = NI_AUX_M(i)./amu;
        % Calculate the ion temperature and speed for each species
        ui = sqrt(ec.*TI_BEAM./plasma_mass(i));
        uavi2(i,:) = SPEED.*SPEED + ui.*ui;
 uavi2(i,:)= 9.58d10*(TI_BEAM./1000.0./ai+SPEED.^2/ec*amu/1000.0/at);
        % Calculate the minimum distance of closest approach for each ion species
        rmincli = myZ.*Zi.*ec.*ec./(map.*uavi2(i,:));
        rminqui = hbar./(2.*map.*sqrt(uavi2(i,:)));
        rmini(i,:) = max(rmincli,rminqui);
data.bmin(i,:)=rmini(i,:);
        % Calculate the plasma frequency for each ion species
        %omegapi2 = (Zi.*ec.*ec)./(plasma_mass(i).*eps0);
        %omegaci = ec.*B_BEAM./plasma_mass(i);
        omegai2(i,:) = 1.74.* Zi.^2./ai .*NI_BEAM(i,:) + 9.18e15 .* Zi.^2 / ai.^2 .* B_BEAM.^2;

    end
 data.vrel2=uavi2;
 data.omegae2=omegae2;
    % Calculate the ion and electron Coulomb logarithm for each species
     data.sm=sum(omegai2./uavi2,1);
    rmax = sqrt(1./(omegae2./uave2 + sum(omegai2./uavi2,1)));
    coulomb_loge = log(rmax./rmine);
    coulomb_loge(coulomb_loge <=1) = 1;
    for i = 1:num_species
        coulomb_logi(i,:) = log(rmax./rmini(i,:));
    end
    coulomb_logi(coulomb_logi <=1) = 1;

    for i = 1:num_species
        ai = plasma_mass(i)./amu;
        Zi = plasma_charge(i)./ec;
        zi2_ai(i,:) = NI_BEAM(i,:).*Zi.^2./ai .* coulomb_logi(i,:);
        zi2(i,:) = NI_BEAM(i,:).*Zi.^2 .* coulomb_logi(i,:);
    end
    zi2_ai = sum(zi2_ai,1)./(NE_BEAM.*coulomb_loge);
    zi2 = sum(zi2,1)./(NE_BEAM.*coulomb_loge);
    zi2_ai2 = data.ZMEAN_set .* mean(coulomb_logi,1)./coulomb_loge;% myZ.^2./ai .*
    zi22 = ZE_BEAM .* mean(coulomb_logi,1)./coulomb_loge;
    data.coulomb_loge = coulomb_loge;
    data.coulomb_logi = coulomb_logi;
    data.rmax=rmax;
    data.zi2_ai= zi2_ai;
    data.zi2= zi2;
    v_crit = 5.33e4 .* sqrt(TE_BEAM) .* zi2_ai.^(1/3);
    vcrit_cube = v_crit.^3;
    tau_spit = 6.32e8 .* (MASS./amu) ./ (myZ.^2 .* coulomb_loge) .* TE_BEAM.^(3/2) ./ (NE_BEAM.*1E-6);
    plasma_mass = plasma_mass(1);
    plasma_charge = plasma_charge(1);
elseif log_type == 2
    ai = plasma_mass/amu;
    Zi = plasma_charge./ec;
    map  = plasma_mass.*MASS./(plasma_mass+MASS);
    mae  = me.*MASS./(me+MASS);
    ue    = sqrt(3.*ec.*TE_BEAM./me);
    ui    = sqrt(3.*ec.*TI_BEAM./plasma_mass);
    uave2  = SPEED.*SPEED + ue.*ue;
    uavi2  = SPEED.*SPEED + ui.*ui;
    rmincle = myZ.*ZE_BEAM.*ec.*ec./(mae.*uave2);
    rmincli = myZ.*ZE_BEAM.*ec.*ec./(map.*uavi2);
    rminque = hbar./(2.*mae.*sqrt(uave2));
    rminqui = hbar./(2.*map.*sqrt(uavi2));
    rmine = max(rmincle,rminque);
    rmini = max(rmincli,rminqui);

    omegape2 = NE_BEAM.*ec.*ec./(me.*eps0);
    omegapi2 = (Zi.*ec.*ec)./(plasma_mass(i).*eps0);
    omegapi2 = (NE_BEAM).*ec.*ec./(plasma_mass.*eps0);
    omegace = ec.*B_BEAM./me;
    omegaci = ec.*B_BEAM./plasma_mass;
    omegae2 = omegape2+omegace.*omegace;
    %omegai2(i,:) = 1.74.* Zi.^2./ai + 9.18e15 .* Zi.^2 / ai.^2 * B_BEAM.^2;
    %omegai2 = omegapi2+omegaci.*omegaci;
    omegai2 =1.74.* ZMEAN + 9.18e15 .* ZMEAN/ai .* B_BEAM.^2; %ZMEAN.^2./ZE_BEAM
    rmax = sqrt(1./(omegae2./uave2 + omegai2./uavi2));

    coulomb_loge = log(rmax./rmine);
    coulomb_logi = log(rmax./rmini);
    coulomb_loge(coulomb_loge <=1) = 1;
    coulomb_logi(coulomb_logi <=1) = 1;



    zi2_ai = ZMEAN .* coulomb_logi./coulomb_loge;% myZ.^2./ai .*
    zi2 = ZE_BEAM .* coulomb_logi./coulomb_loge;

    data.coulomb_loge = coulomb_loge;
    data.coulomb_logi = coulomb_logi;
    data.rmax=rmax;
    data.zi2_ai= zi2_ai;
    data.zi2= zi2;
    fact_crit =  ((0.75.*sqrt(pi.*plasma_mass./me)).^(1./3.)).*sqrt(2*ec./plasma_mass);
    % fact_crit=sqrt(2*ec./plasma_mass)*(0.75*sqrt(pi)*sqrt(plasma_mass/me)).^(1/3);
    v_crit =fact_crit.*sqrt(TE_BEAM) .* zi2_ai.^(1/3);
    vcrit_cube = v_crit.^3;
    %tau_spit = 6.32e8 .* (MASS./amu) ./ (myZ.^2 .* coulomb_loge) .* TE_BEAM.^(3/2) ./ (NE_BEAM.*1E-6);
    tau_spit=3.777183e41.*MASS.*TE_BEAM.^(3/2)./(myZ.^2 .* coulomb_loge.*NE_BEAM);
elseif log_type == 3
    plasma_mass = plasma_mass(1);
    plasma_charge = plasma_charge(1);
    %NI_AUX_M is in kg, NI_AUX_Z is in ec
    sm = zeros(size(S_BEAM));
    for i = 1:num_species
        omega2 = 1.74.*NI_AUX_Z(i).^2 ./ (NI_AUX_M(i)./amu).*NI_BEAM(i,:) + 9.18e15 .* NI_AUX_Z(i).^2 ./ (NI_AUX_M(i)/amu).^2 .* B_BEAM.^2;
        vrel2= 9.58d10*(TI_BEAM./1000.0./(NI_AUX_M(i)./amu)+SPEED.^2/ec*amu/1000.0/at);
        sm=sm+omega2./vrel2;
    end
    %Electrons

    omega2 = 1.74.*1836.1.*NE_BEAM + 9.18e15 .* 1836.1.^2 .* B_BEAM.^2;
    vrel2= 9.58d10*(TE_BEAM./1000.0.*1836.1+SPEED.^2/ec*amu/1000.0/at);


 data.sm=sm;

    bmincl=0.13793d0.*abs(CHARGE./ec).*(1/1836.1+MASS./amu)./(1/1836.1.*MASS./amu.*vrel2);
    bminqu=1.9121d-8*(MASS./amu+1/1836.1)./(1/1836.1*MASS./amu.*sqrt(vrel2));
    bmin=max(bmincl,bminqu);

data.omegae2=omega2;

    sm=sm+omega2./vrel2;
    bmax = sqrt(1./(sm));
    coulomb_loge=log(bmax./bmin); %only last coulomb log is saved - nubeam keeps per-species coulomb log, but not sure what effect this has
    zi2_ai=zeros(size(coulomb_loge));
    zi2=zeros(size(coulomb_loge));
    for i = 1:num_species
        vrel2= 9.58d10*(3*TI_BEAM./1000.0./(NI_AUX_M(i)/amu)+SPEED.^2./ec.*MASS./1000.0./at);
        bmincl=0.13793d0.*abs(NI_AUX_Z(i).*CHARGE/ec).*(NI_AUX_M(i)/amu+MASS./amu)./(NI_AUX_M(i)/amu)./(MASS/amu)./vrel2;
        bminqu=1.9121d-8.*(NI_AUX_M(i)./amu+MASS./amu)./(NI_AUX_M(i)./amu)./(MASS./amu)./sqrt(vrel2);
        bmin=max(bmincl,bminqu);
         data.vrel2(i,:)=vrel2;
        data.bmin(i,:)=bmin;
        coulomb_logi=log(bmax./bmin); %only last coulomb log is saved - nubeam keeps per-species coulomb log, but not sure what effect this has
        zi2_ai =zi2_ai+ NI_BEAM(i,:).*NI_AUX_Z(i).^2./(NI_AUX_M(i)./amu) .* coulomb_logi;
        zi2 = zi2+NI_BEAM(i,:).*NI_AUX_Z(i).^2 .* coulomb_logi;
    end
    zi2_ai = zi2_ai./(NE_BEAM.*coulomb_loge);
    zi2 = zi2./(NE_BEAM.*coulomb_loge);
    coulomb_loge(coulomb_loge <=1) = 1;
    coulomb_logi(coulomb_logi <=1) = 1;

    % zi2_ai = ZMEAN .* coulomb_logi./coulomb_loge;% myZ.^2./ai .*
    % zi2 = ZE_BEAM .* coulomb_logi./coulomb_loge;

    data.coulomb_loge = coulomb_loge;
    data.coulomb_logi = coulomb_logi;
    data.rmax=bmax;
    data.zi2_ai= zi2_ai;
    data.zi2= zi2;
    % fact_crit=sqrt(2*ec./plasma_mass)*(0.75*sqrt(pi)*sqrt(plasma_mass/me)).^(1/3);
    %v_crit =5.33e4 .*sqrt(TE_BEAM) .* zi2_ai.^(1/3);
    %tau_spit = 6.32e8 .* (MASS./amu) ./ (myZ.^2 .* coulomb_loge) .* TE_BEAM.^(3/2) ./ (NE_BEAM.*1E-6);
    tau_spit=3.777183e41.*MASS.*TE_BEAM.^(3/2)./(myZ.^2 .* coulomb_loge.*NE_BEAM);
    fact_crit =  ((0.75.*sqrt(pi.*plasma_mass./me)).^(1./3.)).*sqrt(2*ec./plasma_mass);
    %v_crit = fact_crit.*sqrt(TE_BEAM) .*(ZMEAN.*coulomb_logi./coulomb_loge).^(1/3);
    v_crit = fact_crit.*sqrt(TE_BEAM) .*zi2_ai.^(1/3);
    vcrit_cube = v_crit.^3;
    %v_crit = ((0.75.*sqrt(pi.*plasma_mass./me)).^(1./3.)).*sqrt(2.*TE_BEAM.*ec./plasma_mass).* (coulomb_log./coulomb_loge).^(1/3);
    %v_crit = 5.33e4 .* sqrt(TE_BEAM) .* (myZ.^2./ (plasma_mass/amu) .* coulomb_log./coulomb_loge).^(1/3);
    %vcrit_cube = v_crit.^3;
    %tau_spit = 3.777183E41.*MASS.*sqrt(TE3)./(NE_BEAM.*myZ.*myZ.*coulomb_loge);
    % v_crit = ((0.75.*sqrt(pi.*plasma_mass./me)).^(1./3.)).*sqrt(2.*TE_BEAM.*ec./plasma_mass);
    % vcrit_cube = v_crit.^3;
    % tau_spit = 3.777183E41.*MASS.*sqrt(TE3)./(NE_BEAM.*myZ.*myZ.*coulomb_log);
    % nu0_fe = 6.6E-11 .* NE_BEAM .* myZ.*myZ ./ sqrt(at./9.31E-31) ./ (E_BEAM ./ 1.6022E-19).^(3/2) .* (coulomb_log./17);
    % data.nu0_fe = nu0_fe;

elseif log_type == 4
    coulomb_log = 43 - log(myZ.*ZE_BEAM.*(MASS+plasma_mass).*sqrt(NE_BEAM.*1E-6./TE_BEAM)./(MASS.*plasma_mass.*beta.*beta.*6.02214076208E+26));
    %coulomb_log=[];
    %coulomb_log = 35 - log(myZ.*ZE_BEAM.*(MASS+plasma_mass).*sqrt(NE_BEAM.*1E-6./TE_BEAM)./(MASS.*plasma_mass.*beta.*beta.*6.02214076208E+26));
    coulomb_log(coulomb_log <=1) = 1;
    v_crit = ((0.75.*sqrt(pi.*plasma_mass./me)).^(1./3.)).*sqrt(2.*TE_BEAM.*ec./plasma_mass);
    vcrit_cube = v_crit.^3;
    tau_spit = 3.777183E41.*MASS.*sqrt(TE3)./(NE_BEAM.*myZ.*myZ.*coulomb_log);
    nu0_fe = 6.6E-11 .* NE_BEAM .* myZ.*myZ ./ sqrt(MASS./9.31E-31) ./ (E_BEAM ./ 1.6022E-19).^(3/2) .* (coulomb_log./17);
elseif    log_type == 5
    %coulomb_log=[];
    coulomb_log = 35 - log(myZ.*ZE_BEAM.*(MASS+plasma_mass).*sqrt(NE_BEAM.*1E-6./TE_BEAM)./(MASS.*plasma_mass.*beta.*beta.*6.02214076208E+26));
    coulomb_log(coulomb_log <=1) = 1;
    v_crit = ((0.75.*sqrt(pi.*plasma_mass./me)).^(1./3.)).*sqrt(2.*TE_BEAM.*ec./plasma_mass);
    vcrit_cube = v_crit.^3;
    tau_spit = 3.777183E41.*MASS.*sqrt(TE3)./(NE_BEAM.*myZ.*myZ.*coulomb_log);
    nu0_fe = 6.6E-11 .* NE_BEAM .* myZ.*myZ ./ sqrt(MASS./9.31E-31) ./ (E_BEAM ./ 1.6022E-19).^(3/2) .* (coulomb_log./17);
end

% Integrate
C1 = 1./tau_spit;
C2 = vcrit_cube./tau_spit;
% if lplot
%     figure
%     plot(C2,'.')
% end
v_sound = 1.5*sqrt(ec.*TI_BEAM./plasma_mass);
V  = SPEED;
V2 = V;
dt= 1E-4; %Previous setting (W7-X presumably);
dt = 2E-3; %Gives correct NPART for AUG #38581 benchmark
%dt = 2E-4; %Gives correct NPART for AUG #38581 benchmark
Ee = zeros(1,length(W_BEAM));
Ei = zeros(1,length(W_BEAM));
jb = zeros(1,length(W_BEAM));
dist = zeros(1,length(W_BEAM));
t=0;
while any(V > v_sound)
    t = t+dt;
    dex = V > v_sound;
    dve = C1(dex).*V(dex);
    dvi = C2(dex)./(V(dex).*V(dex));
    dvt = dve+dvi;
    V2(dex) = V(dex) - dvt.*dt;
    Ee(dex) = Ee(dex) + V(dex).*dve.*dt;
    Ei(dex) = Ei(dex) + V(dex).*dvi.*dt;
    jb(dex) = jb(dex) + V(dex).*PITCH(dex).*dt;
    dist(dex)=dist(dex)+W_BEAM(dex)*dt;
    V = max(V2,v_sound);
    disp([num2str(t) ' ' num2str(V(1:3))]);
end
Pe = MASS.*W_BEAM.*Ee;
Pi = MASS.*W_BEAM.*Ei;
J = CHARGE.*W_BEAM.*jb;

% Define RHO
RHO_BEAM = sqrt(abs(S_BEAM));
[~,RHO] = hist(RHO_BEAM,100);
RHO=[0 RHO];

% Sum by beam and rho
PE_RHO = zeros(1,length(RHO));
PI_RHO = zeros(1,length(RHO));
J_RHO  = zeros(1,length(RHO));
PART_RHO  = zeros(1,length(RHO));
for i = 1:length(RHO)-1
    dex = and(RHO_BEAM<RHO(i+1), RHO_BEAM>= RHO(i));
    %dex = and(dex,BEAM==k);
    PE_RHO(i+1) = sum(Pe(dex));
    PI_RHO(i+1) = sum(Pi(dex));
    J_RHO(i+1) = sum(J(dex));
    PART_RHO(i+1) = sum(dist(dex));
end
npart=sum(PART_RHO);
fprintf('Total no. of fast ions: %.2e\n',sum(PART_RHO));

% Calculate Volume for each radial point
% dV = dV/drho * drho
vp = ppval(vp_spl,RHO)./length(RHO);

if lplot
    if max(PE_RHO) > 1E6 || max(PI_RHO) > 1E6
        factor = 1.0E-6;
        units = '[MW/\Phi]';
        units2 = '[MW/m^3]';
    elseif max(PE_RHO) > 1E3 || max(PI_RHO) > 1E3
        factor = 1.0E-3;
        units = '[kW/\Phi]';
        units2 = '[kW/m^3]';
    else
        factor = 1.0;
        units = '[W/\Phi]';
        units2 = '[W/m^3]';
    end
    if max(J_RHO)>1E6
        factorj = 1E-6;
        unitsj2  = '[MA/m^2]';
    elseif max(J_RHO) > 1E3
        factorj = 1E-3;
        unitsj2  = '[kA/m^2]';
    else
        factorj = 1.0;
        unitsj2  = '[A/m^2]';
    end
    vp2=vp;
    vp2(1)=vp2(2);
    figure('Position',[1 1 1024 768],'Color','white');
    plot(RHO,factor.*PE_RHO./vp2,'b','LineWidth',4);
    hold on;
    plot(RHO,factor.*PI_RHO./vp2,'r','LineWidth',4);
    set(gca,'FontSize',36);
    xlabel('Effective Radius (\rho/a)');
    ylabel(['Power Density ' units2]);
    title('BEAMS3D Simple Power Deposition');
    legend('P_{electrons}','P_{ions}');
    text(min(xlim)+0.025*diff(xlim),...
        max(ylim)-0.050*diff(ylim),...
        ['P_{injected} = ' num2str(Pinj./1E6,'%5.2f [MW]')],'Color','black','FontSize',36);
    text(min(xlim)+0.025*diff(xlim),...
        max(ylim)-0.110*diff(ylim),...
        ['\tau_{therm} = ' num2str(round(t.*1E3),'%4i [ms]')],'Color','black','FontSize',36);
    figure('Position',[1 1 1024 768],'Color','white');
    plot(RHO,factorj.*J_RHO./vp2,'k','LineWidth',4);
    text(min(xlim)+0.025*diff(xlim),...
        max(ylim)-0.050*diff(ylim),...
        ['I_{inj} = ' num2str(Iinj,'%5.2f [A]')],'Color','black','FontSize',36);
    set(gca,'FontSize',36);
    xlabel('Effective Radius (\rho/a)');
    ylabel(['Beam Current ' unitsj2]);
    title('BEAMS3D Simple Current');
    figure('Position',[1 1 1024 768],'Color','white');
    %yyaxis right
    hold on
    plot(RHO_BEAM,C2./SPEED.^2,'.','DisplayName', 'Ions')
    %yyaxis left
    plot(RHO_BEAM,C1.*SPEED,'.','DisplayName', 'Electrons')
    title('Initial Slowing down');
    xlabel('Effective Radius (\rho/a)');
    ylabel('Ion slowing down m/s]');
    legend();
end

data.PE = PE_RHO;
data.PI = PI_RHO;
data.RHO  = RHO;
data.Pinj = Pinj;
data.Iinj = Iinj;
data.PART_RHO=PART_RHO;
data.npart=npart;
data.tslow = t;
data.tau_spit = tau_spit;
data.v_crit=v_crit;
data.V=V;
data.V2=V2;
data.RHO_BEAM=RHO_BEAM;
data.E_BEAM=E_BEAM;
data.ZMEAN=ZMEAN;
data.ZEFF=mean(ZE_BEAM,'omitnan');

if ~isempty(vp)
    data.VP = vp;
    data.QE = PE_RHO./vp;
    data.QI = PI_RHO./vp;
    data.JB =  J_RHO./vp;
    data.QE(1) = 0;
    data.QI(1) = 0;
    data.JB(1) = 0;
end


return
end