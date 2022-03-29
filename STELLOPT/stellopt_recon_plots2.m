function stellopt_recon_plots2
%stellopt_recon_plots2 Makes reconstruction plots based on STELLOPT runs
%   Just call from command line, it takes care of the rest.
%
% Example usage
%      stellopt_recon_plots2;
%
% Maintained by: Samuel Lazerson (lazerson@pppl.gov)
% Version:       1.00

% Defaults
ntheta = 128;

% Load file
files=dir('stellopt.*');
data = read_stellopt(files.name);
ext = files.name(10:end);
files=dir('wout_*.*.nc');
vmec_data=read_vmec(files(end).name);
files=dir('jacobian.*');
if isempty(files)
    jac_data=[];
else
    jac_data=read_stellopt(files(end).name);
end
files=dir('answers_plot.*');
if isempty(files)
    boot_data=[];
else
    boot_data=read_bootsj(files(end).name);
end
files = dir('jprof.*.*');
if isempty(files)
    jprof=[];
else
    jprof=importdata(files(end).name);
    jprof=jprof.data;
end
files = dir('dprof.*.*');
if isempty(files)
    dprof=[];
else
    dprof=importdata(files(end).name);
    dprof=dprof.data;
end
files = dir('tprof.*.*');
if isempty(files)
    tprof=[];
else
    tprof=importdata(files(end).name);
    tprof=tprof.data;
end
files=[];

% Process Jacobian
if isempty(jac_data)
    sigma_y = [];
    y_fit   = [];
    ljac=0;
else
    Npar = jac_data.n;
    Npnt = jac_data.m;
    Nfit = jac_data.n;
    y_dat = data.TARGETS(end,:);
    y_fit = data.VALS(end,:);
    y_sig = data.SIGMAS(end,:);
    jac   = jac_data.jac';
    chisq = ((data.TARGETS-data.VALS)./data.SIGMAS).^2;
    chisq_tot = sum(chisq,2);
    delta_y=(y_dat-y_fit)./y_sig;
    weights_sq = (Npnt-Nfit+1)./((delta_y'*delta_y) * ones(Npnt,1));
    weights_sq(delta_y' == 0) = 1.0E-18;
    JtWJ       = jac' * ( jac.* ( weights_sq * ones(1,Npar)));
    covar      = inv(JtWJ);
    sigma_p    = abs(sqrt(diag(covar)));
    sigma_y    = zeros(Npnt,1);
    for i = 1:Npnt
        sigma_y(i) = jac(i,:)*covar*jac(i,:)';
    end
    sigma_y    = abs(sqrt(sigma_y).*y_sig');
    sigma_yp   = abs(sqrt(weights_sq+sigma_y).*y_sig');
    ljac=1;
end


% Cycle through options
if isfield(data,'TE_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    zeta = mean(data.TE_PHI(1,:));
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),tprof(:,3)./1000,vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot(data.TE_R(end,:),data.TE_Z(end,:),'ow','MarkerSize',8,'LineWidth',2);
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'T_e [keV]');
    subplot(1,2,1);
    plot(data.TE_R(1,:),data.TE_target(end,:)./1000,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(data.TE_R(1,:),data.TE_equil(end,:)./1000,'+b','MarkerSize',8,'LineWidth',2);
    %plot(sqrt(tprof(:,1)),tprof(:,3)./1000,'b','LineWidth',4);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'Electron Temperature');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=data.TE_R(1,:);
        [~,dex]=sort(s,'ascend');
        fill([s(dex) fliplr(s(dex))],[yup(dex) fliplr(ydn(dex))]./1E3,'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    axis tight;
    hold off;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('T_e [keV]');
    ylim([0 1.5.*max(tprof(:,3))/1000]);
    %xlim([0 1.2]);
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','Electron Temperature Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_te_' ext '.fig']);
    saveas(fig,['recon_te_' ext '.png']);
    close(fig);
end


if isfield(data,'NE_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    zeta = mean(data.NE_PHI(1,:));
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),tprof(:,2)./1E19,vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot(data.NE_R(1,:),data.NE_Z(1,:),'ow','MarkerSize',8,'LineWidth',2);
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'n_e x10^{19} [m^{-3}]');
    subplot(1,2,1);
    scalefact=max(tprof(:,2));
    if any(data.NE_target(end,:)>1E10)
        scalefact=1;
    end
    plot(data.NE_R(end,:),scalefact.*data.NE_target(end,:)./1E19,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(data.NE_R(end,:),scalefact.*data.NE_equil(end,:)./1E19,'+b','MarkerSize',8,'LineWidth',2);
    %plot(sqrt(tprof(:,1)),tprof(:,2)./1E19,'b','LineWidth',4);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'Electron Density');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            if ~isempty(strfind(jac_data.target_name{i},'Line Integrated')), continue; end;
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=data.NE_R(end,:);
        [~,dex]=sort(s,'ascend');
        fill([s(dex) fliplr(s(dex))],scalefact.*[yup(dex) fliplr(ydn(dex))]./1E19,'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    axis tight;
    hold off;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('n_e 10^{19} [m^{-3}]');
    %ylim([0 1.5.*scalefact/1E19]);
    %xlim([0 1.2]);
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','Electron Density Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_ne_' ext '.fig']);
    saveas(fig,['recon_ne_' ext '.png']);
    close(fig);
end

if isfield(data,'NELINE_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    zeta = mean([data.NELINE_PHI0(1,:) data.NELINE_PHI1(1,:)]);
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),tprof(:,2)./1E19,vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot([data.NELINE_R0(1,:); data.NELINE_R1(1,:)],[data.NELINE_Z0(1,:); data.NELINE_Z1(1,:)],'k','LineWidth',2);
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'n_e x10^{19} [m^{-3}]');
    subplot(1,2,1);
    plot(1:length(data.NELINE_target(end,:)),data.NELINE_target(end,:)./1E19,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(1:length(data.NELINE_target(end,:)),data.NELINE_equil(end,:)./1E19,'+b','MarkerSize',8,'LineWidth',2);
    hold off;
    axis tight;
    ylim([0 2.0*max(ylim)]);
    set(gca,'FontSize',24);
    xlabel('Channel');
    ylabel('Line Int. Density [m^{-2}]');
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','Line Int Density Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_neline_' ext '.fig']);
    saveas(fig,['recon_neline_' ext '.png']);
    close(fig);
end

if isfield(data,'VISBREMLINE_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    % Calc Visbrem
    Ry=2.1798723611035D-18;
    ec=1.60217662E-19;
    hc=1.98644582E-25;
    te = tprof(:,3).*ec;
    ne = tprof(:,2);
    ze = tprof(:,5);
    %g2 = ze.*ze.*Ry./(te);
    utemp = hc./(te);
    gauntff = 1.35.*(te./ec).^(0.15);
    visbrem = gauntff.*ne.*ne.*ze.*exp(-utemp)./(sqrt(te));
    zeta = mean([data.VISBREMLINE_PHI0(1,:) data.VISBREMLINE_PHI1(1,:)]);
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),visbrem,vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot([data.VISBREMLINE_R0(1,:); data.VISBREMLINE_R1(1,:)],...
        [data.VISBREMLINE_Z0(1,:); data.VISBREMLINE_Z1(1,:)],'k','LineWidth',2);
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'Vis. Brem.');
    subplot(1,2,1);
    plot(1:length(data.VISBREMLINE_target(end,:)),data.VISBREMLINE_target(end,:),'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(1:length(data.VISBREMLINE_target(end,:)),data.VISBREMLINE_equil(end,:),'+b','MarkerSize',8,'LineWidth',2);
    hold off;
    axis tight;
    ylim([0 2.0*max(ylim)]);
    set(gca,'FontSize',24);
    xlabel('Channel');
    ylabel('Line Int. Vis. Bremsstrahllung');
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','Line Int. Vis. Brem. Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_visbremline_' ext '.fig']);
    saveas(fig,['recon_visbremline_' ext '.png']);
    close(fig);
end

if isfield(data,'ZEFFLINE_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    zeta = mean([data.ZEFFLINE_PHI0(1,:) data.ZEFFLINE_PHI1(1,:)]);
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),tprof(:,5),vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot([data.ZEFFLINE_R0(1,:); data.ZEFFLINE_R1(1,:)],[data.ZEFFLINE_Z0(1,:); data.ZEFFLINE_Z1(1,:)],'k','LineWidth',2);
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'Z_{eff}');
    subplot(1,2,1);
    plot(1:length(data.ZEFFLINE_target(end,:)),data.ZEFFLINE_target(end,:),'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(1:length(data.ZEFFLINE_target(end,:)),data.ZEFFLINE_equil(end,:),'+b','MarkerSize',8,'LineWidth',2);
    hold off;
    axis tight;
    ylim([0 2.0*max(ylim)]);
    set(gca,'FontSize',24);
    xlabel('Channel');
    ylabel('Line Int. Z_{eff}');
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','Line Int Z_{eff} Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_zeffline_' ext '.fig']);
    saveas(fig,['recon_zeffline_' ext '.png']);
    close(fig);
end

if isfield(data,'TI_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    zeta = mean(data.TI_PHI(1,:));
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),tprof(:,4)./1000,vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot(data.TI_R(end,:),data.TI_Z(end,:),'ow','MarkerSize',8,'LineWidth',2);
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'T_i [keV]');
    subplot(1,2,1);
    plot(data.TI_R(end,:),data.TI_target(end,:)./1000,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(data.TI_R(end,:),data.TI_equil(end,:)./1000,'+b','MarkerSize',8,'LineWidth',2);
    %plot(sqrt(tprof(:,1)),tprof(:,3)./1000,'b','LineWidth',4);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'Ion Temperature');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=data.TI_R(1,:);
        [~,dex]=sort(s,'ascend');
        fill([s(dex) fliplr(s(dex))],[yup(dex) fliplr(ydn(dex))]./1E3,'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    axis tight;
    hold off;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('T_i [keV]');
    ylim([0 1.5.*max(tprof(:,4))/1000]);
    %xlim([0 1.2]);
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','CXRS Ion Temperature Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_cxrs_ti_' ext '.fig']);
    saveas(fig,['recon_cxrs_ti_' ext '.png']);
    close(fig);
end

if isfield(data,'XICS_BRIGHT_target')
    if isempty(dprof)
        files = dir('dprof.*.*');
        dprof=importdata(files(end).name);
        dprof=dprof.data;
    end
    zeta = mean(data.XICS_BRIGHT_PHI0(1,:));
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(dprof(:,1),dprof(:,2),vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot([data.XICS_BRIGHT_R0(1,:); data.XICS_BRIGHT_R1(1,:)],[data.XICS_BRIGHT_Z0(1,:); data.XICS_BRIGHT_Z1(1,:)],'k','LineWidth',1);
    text(5.15,1,'1');
    text(5.15,0,num2str(length(data.XICS_BRIGHT_R0(1,:))));
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'Eff. Emiss. [arb]');
    subplot(1,2,1);
    hold on;
    plot(1:length(data.XICS_BRIGHT_target(end,:)),data.XICS_BRIGHT_target(end,:),'ok','MarkerSize',8,'LineWidth',2);
    plot(1:length(data.XICS_BRIGHT_target(end,:)),data.XICS_BRIGHT_equil(end,:),'+b','MarkerSize',8,'LineWidth',2);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'XICS Brightness');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=1:length(data.XICS_BRIGHT_target(end,:));
        fill([s fliplr(s)],[yup fliplr(ydn)],'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    hold off;
    ylim([0 1.2*max(ylim)]);
    xlim([0 length(data.XICS_BRIGHT_target(end,:))+1]);
    set(gca,'FontSize',24);
    xlabel('Channel');
    ylabel('\int\epsilon_{XICS}dl   [arb]');
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','XICS Emissivity Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_xics_bright_' ext '.fig']);
    saveas(fig,['recon_xics_bright_' ext '.png']);
    close(fig);
end

if isfield(data,'XICS_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    zeta = mean(data.XICS_PHI0(1,:));
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),tprof(:,4)./1E3,vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot([data.XICS_R0(1,:); data.XICS_R1(1,:)],[data.XICS_Z0(1,:); data.XICS_Z1(1,:)],'k','LineWidth',1);
    text(5.15,1,'1');
    text(5.15,0,num2str(length(data.XICS_R0(1,:))));
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'T_i [keV]');
    subplot(1,2,1);
    hold on;
    plot(1:length(data.XICS_target(end,:)),data.XICS_target(end,:),'ok','MarkerSize',8,'LineWidth',2);
    plot(1:length(data.XICS_target(end,:)),data.XICS_equil(end,:),'+b','MarkerSize',8,'LineWidth',2);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'XICS Signal');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=1:length(data.XICS_target(end,:));
        fill([s fliplr(s)],[yup fliplr(ydn)],'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    hold off;
    ylim([0 1.2*max(ylim)]);
    xlim([0 length(data.XICS_target(end,:))+1]);
    set(gca,'FontSize',24);
    xlabel('Channel');
    ylabel('\int\epsilon_{XICS}T_i dl   [arb]');
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','XICS Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_xics_ti_' ext '.fig']);
    saveas(fig,['recon_xics_ti_' ext '.png']);
    close(fig);
end

if isfield(data,'XICS_W3_target')
    if isempty(tprof)
        files = dir('tprof.*.*');
        tprof=importdata(files(end).name);
        tprof=tprof.data;
    end
    zeta = mean(data.XICS_W3_PHI0(1,:));
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    f = pchip(tprof(:,1),tprof(:,3)./1E3,vmec_data.phi./vmec_data.phi(end));
    f = repmat(f',[1 ntheta]);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot([data.XICS_R0(1,:); data.XICS_R1(1,:)],[data.XICS_Z0(1,:); data.XICS_Z1(1,:)],'k','LineWidth',1);
    text(5.15,1,'1');
    text(5.15,0,num2str(length(data.XICS_R0(1,:))));
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,'T_e [keV]');
    subplot(1,2,1);
    hold on;
    plot(1:length(data.XICS_W3_target(end,:)),data.XICS_W3_target(end,:),'ok','MarkerSize',8,'LineWidth',2);
    plot(1:length(data.XICS_W3_target(end,:)),data.XICS_W3_equil(end,:),'+b','MarkerSize',8,'LineWidth',2);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'XICS W3 Factor');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=1:length(data.XICS_W3_target(end,:));
        fill([s fliplr(s)],[yup fliplr(ydn)],'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    hold off;
    ylim([0 1.2*max(ylim)]);
    xlim([0 length(data.XICS_W3_target(end,:))+1]);
    set(gca,'FontSize',24);
    xlabel('Channel');
    ylabel('\int\epsilon_{W3}dl   [arb]');
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','XICS W3 Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_xics_te_' ext '.fig']);
    saveas(fig,['recon_xics_te_' ext '.png']);
    close(fig);
end



if isfield(data,'XICS_V_target')
    if isempty(dprof)
        files = dir('dprof.*.*');
        dprof=importdata(files(end).name);
        dprof=dprof.data;
    end
    zeta = mean(data.XICS_V_PHI0(1,:));
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    b = cfunct(theta,zeta,vmec_data.bmnc,vmec_data.xm_nyq,vmec_data.xn_nyq);
    s=vmec_data.phi./vmec_data.phi(end);
    s2=dprof(:,1);
    s2=s2(1:end-1)+diff(s2)/2;
    f=pchip(s2,diff(dprof(:,3)./1E3)./dprof(2,1),s);
    s2=s(1:end-1)+diff(s)/2;
    dr=pchip(s2,diff(r)'./s(2),s)';
    dz=pchip(s2,diff(z)'./s(2),s)';
    f = -repmat(f',[1 ntheta])./(sqrt(dr.*dr+dz.*dz).*b);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(1,2,2);
    torocont(r,z,f,1);
    hold on;
    plot([data.XICS_V_R0(end,:); data.XICS_V_R1(end,:)],[data.XICS_V_Z0(end,:); data.XICS_V_Z1(end,:)],'k','LineWidth',1);
    text(5.15,1,'1');
    text(5.15,0,num2str(length(data.XICS_V_R0(end,:))));
    hold off;
    colormap jet;
    set(gca,'FontSize',24);
    xlabel('R [m]');
    ylabel('Z [m]');
    ha = colorbar;
    set(ha,'FontSize',24);
    ylabel(ha,' V_\perp [km/s]');
    subplot(1,2,1);
    hold on;
    plot(1:length(data.XICS_V_target(end,:)),data.XICS_V_target(end,:)./1E3,'ok','MarkerSize',8,'LineWidth',2);
    plot(1:length(data.XICS_V_target(end,:)),data.XICS_V_equil(end,:)./1E3,'+b','MarkerSize',8,'LineWidth',2);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'XICS Perp. Velocity');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=1:length(data.XICS_V_target(end,:));
        fill([s fliplr(s)],[yup fliplr(ydn)]./1E3,'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    hold off;
    ylim([1.2*min(ylim) 1.2*max(ylim)]);
    xlim([0 length(data.XICS_V_target(end,:))+1]);
    set(gca,'FontSize',24);
    xlabel('Channel');
    ylabel('\int v dl   [k.Rad]');
    legend('Exp.','Recon.');
    set(gca,'Position',[0.162 0.237 0.303 0.576]);
    annotation('textbox',[0.1 0.85 0.8 0.1],'string','XICS V Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_xics_v_' ext '.fig']);
    saveas(fig,['recon_xics_v_' ext '.png']);
    close(fig);
end

if isfield(data,'ECEREFLECT_target')
    fig = figure('Position',[1 1 1024 768],'Color','white');
    plot(data.ECEREFLECT_freq(end,:),data.ECEREFLECT_target(end,:)./1000,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(data.ECEREFLECT_freq(end,:),data.ECEREFLECT_equil(end,:)./1000,'+b','MarkerSize',8,'LineWidth',2);
    plot(data.ECEREFLECT_freq(end,:),data.ECEREFLECT_tradx(end,:)./1000,'xb','MarkerSize',8,'LineWidth',2);
    plot(data.ECEREFLECT_freq(end,:),data.ECEREFLECT_trado(end,:)./1000,'^r','MarkerSize',8,'LineWidth',2);
    %%%%%%%%% Red lines
    if ljac
        IndexC=strfind(jac_data.target_name,'ECE Reflectometry Diagnostic');
        Index = find(not(cellfun('isempty',IndexC)));
        yup=[]; ydn=[]; n=1;
        for i=Index
            yup(n) = y_fit(i) + 1.96.*real(sigma_y(i));
            ydn(n) = y_fit(i) - 1.96.*real(sigma_y(i));
            n = n +1;
        end
        s=data.ECEREFLECT_freq(end,:);
        [~,dex]=sort(s,'ascend');
        fill([s(dex) fliplr(s(dex))],[yup(dex) fliplr(ydn(dex))]./1E3,'blue','EdgeColor','none','FaceAlpha',0.33);
    end
    %%%%%%%%%
    hold off;
    set(gca,'FontSize',24);
    xlabel('Freq. [GHz]');
    ylabel('T_{Rad} [keV]');
    axis tight;
    legend('Exp.','Recon.','X-Mode','O-Mode');
    title('ECE Signal Reconstruction');
    saveas(fig,['recon_ece_' ext '.fig']);
    saveas(fig,['recon_ece_' ext '.png']);
    close(fig);
end

if isfield(data,'FLUXLOOPS_target')
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(2,2,1);
    [ax,h1,h2]=plotyy(sqrt(vmec_data.phi./vmec_data.phi(end)),vmec_data.presf./1E3,...
        sqrt(vmec_data.phi./vmec_data.phi(end)),vmec_data.jcurv./1E3);
    set(h1,'Color','b','LineWidth',2);
    set(h2,'Color','r','LineWidth',2);
    set(ax(1),'FontSize',12,'YColor','b');
    set(ax(2),'FontSize',12,'YColor','r');
    xlabel(ax(1),'Rho');
    ylabel(ax(1),'Press. [kPa]');
    ylabel(ax(2),'Current [kA/m^{-2}]');
    subplot(2,2,2)
    if ~isempty(jprof)
        plot(sqrt(jprof(:,1)),jprof(:,2),'--g');
        hold on;
        plot(sqrt(jprof(:,1)),jprof(:,3),'-k');
        plot(sqrt(jprof(:,1)),jprof(:,4),'-r');
        set(gca,'FontSize',12);
        xlabel('Rho');
        ylabel('dI/ds');
        legend('Driven','Bootstrap','Total');
    else
        text(0.2,0.5,'No JPROF');
    end
    subplot(2,2,[3 4]);
    f=(data.FLUXLOOPS_equil(end,:)-data.FLUXLOOPS_target(end,:))./data.FLUXLOOPS_target(end,:);
    f(data.FLUXLOOPS_target(end,:)==0) = 0;
    bar(1:length(data.FLUXLOOPS_target(end,:)),f.*100,'k');
    set(gca,'FontSize',24);
    xlabel('Flux Loop Index');
    ylabel('Signal [% Diff.]');
    axis tight;
    annotation('textbox',[0.1 0.9 0.8 0.1],'string','Flux Loop Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_fluxloop_' ext '.fig']);
    saveas(fig,['recon_fluxloop_' ext '.png']);
    close(fig);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    dex = find(data.FLUXLOOPS_target(end,:)~=0);
    f = data.FLUXLOOPS_equil(end,dex);
    plot(dex,data.FLUXLOOPS_target(end,dex).*1000,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(dex,f.*1000,'+b','MarkerSize',8,'LineWidth',2);
    hold off;
    set(gca,'FontSize',24);
    xlabel('Flux Loop Index');
    ylabel('Signal [mWb]');
    title('Flux Loop Reconstruction');
    legend('Exp.','Recon.');
    saveas(fig,['recon_fluxloop_act_' ext '.fig']);
    saveas(fig,['recon_fluxloop_act_' ext '.png']);
    close(fig);
end

if isfield(data,'SEGROG_target')
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(2,2,1);
    [ax,h1,h2]=plotyy(sqrt(vmec_data.phi./vmec_data.phi(end)),vmec_data.presf./1E3,...
        sqrt(vmec_data.phi./vmec_data.phi(end)),vmec_data.jcurv./1E3);
    set(h1,'Color','b','LineWidth',2);
    set(h2,'Color','r','LineWidth',2);
    set(ax(1),'FontSize',12,'YColor','b');
    set(ax(2),'FontSize',12,'YColor','r');
    xlabel(ax(1),'Rho');
    ylabel(ax(1),'Press. [kPa]');
    ylabel(ax(2),'Current [kA/m^{-2}]');
    subplot(2,2,2)
    if ~isempty(jprof)
        plot(sqrt(jprof(:,1)),jprof(:,2),'--g');
        hold on;
        plot(sqrt(jprof(:,1)),jprof(:,3),'-k');
        plot(sqrt(jprof(:,1)),jprof(:,4),'-r');
        set(gca,'FontSize',12);
        xlabel('Rho');
        ylabel('dI/ds');
        legend('Driven','Bootstrap','Total');
    else
        text(0.2,0.5,'No JPROF');
    end
    subplot(2,2,[3 4]);
    f=(data.SEGROG_equil(end,:)-data.SEGROG_target(end,:))./data.SEGROG_target(end,:);
    f(data.SEGROG_target(end,:)==0) = 0;
    bar(1:length(data.SEGROG_target(end,:)),f.*100,'k');
    set(gca,'FontSize',24);
    xlabel('Rogowski Index');
    ylabel('Signal [% Diff.]');
    axis tight;
    ylim([-100 100]);
    legend('Exp.','Recon.');
    annotation('textbox',[0.1 0.9 0.8 0.1],'string','Rogowski Reconstruction','FontSize',24,'LineStyle','none','HorizontalAlignment','center');
    saveas(fig,['recon_segrog_' ext '.fig']);
    saveas(fig,['recon_segrog_' ext '.png']);
    close(fig);
    fig = figure('Position',[1 1 1024 768],'Color','white');
    dex = find(data.SEGROG_target(end,:)~=0);
    f = data.SEGROG_equil(end,dex);
    plot(dex,data.SEGROG_target(end,dex).*1000,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    plot(dex,f.*1000,'+b','MarkerSize',8,'LineWidth',2);
    hold off;
    set(gca,'FontSize',24);
    xlabel('Rogowski Index');
    ylabel('Signal [mT-m]');
    title('Rogowski Reconstruction');
    legend('Exp.','Recon.');
    saveas(fig,['recon_segrog_act_' ext '.fig']);
    saveas(fig,['recon_segrog_act_' ext '.png']);
    close(fig);
end

% Plot Profiles
if ~isempty(tprof)
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(2,2,1);
    plot(sqrt(tprof(:,1)),tprof(:,3)./1E3,'b','LineWidth',2);
    hold on;
    plot(sqrt(tprof(:,1)),tprof(:,4)./1E3,'r','LineWidth',2);
    hold off;
    set(gca,'FontSize',24);
    xlabel('Rho');
    ylabel('T [keV]');
    legend('Electron','Ion');
    title('Temperatures');
    subplot(2,2,2);
    plot(sqrt(tprof(:,1)),tprof(:,2)./1E19,'b','LineWidth',2);
    hold on;
    plot(sqrt(tprof(:,1)),tprof(:,2)./(tprof(:,5).*1E19),'r','LineWidth',2);
    hold off;
    set(gca,'FontSize',24);
    xlabel('Rho');
    ylabel('n x10^{19} [m^{-3}]');
    legend('Electron','Ion');
    title('Densities');
    subplot(2,2,3);
    plot(sqrt(tprof(:,1)),tprof(:,5),'k','LineWidth',2);
    set(gca,'FontSize',24);
    xlabel('Rho');
    ylabel('Z_{eff}');
    title('Effective Ion Charge');
    subplot(2,2,4);
    plot(sqrt(tprof(:,1)),tprof(:,6)./1E3,'k','LineWidth',2);
    set(gca,'FontSize',24);
    xlabel('Rho');
    ylabel('P [kPA]');
    title('Pressure');
    saveas(fig,['recon_tprof_' ext '.fig']);
    saveas(fig,['recon_tprof_' ext '.png']);
    close(fig);
    fid = fopen(['recon_tprof_' ext '.txt'],'w');
    rho = 0:0.1:1;
    fprintf(fid,'  NE_AUX_S =');
    fprintf(fid,' %20.10E ',rho.^2);
    fprintf(fid,'\n  NE_AUX_F =');
    fprintf(fid,' %20.10E ',pchip(sqrt(tprof(:,1)),tprof(:,2),rho));
    fprintf(fid,'\n  TE_AUX_S =');
    fprintf(fid,' %20.10E ',rho.^2);
    fprintf(fid,'\n  TE_AUX_F =');
    fprintf(fid,' %20.10E ',pchip(sqrt(tprof(:,1)),tprof(:,3),rho));
    fprintf(fid,'\n  TI_AUX_S =');
    fprintf(fid,' %20.10E ',rho.^2);
    fprintf(fid,'\n  TI_AUX_F =');
    fprintf(fid,' %20.10E ',pchip(sqrt(tprof(:,1)),tprof(:,4),rho));
    fprintf(fid,'\n');
    fclose(fid);
    
end


if ~isempty(dprof)
    fig = figure('Position',[1 1 1024 768],'Color','white');
    subplot(2,2,1);
    plot(sqrt(dprof(:,1)),dprof(:,2),'k','LineWidth',2);
    set(gca,'FontSize',24);
    xlabel('Rho');
    ylabel('\epsilon_{XICS} [arb]');
    title('XICS Effective Emissivity');
    ylim([0 1.05*max(ylim)]);
    subplot(2,2,3);
    plot(sqrt(dprof(:,1)),dprof(:,3)./1E3,'k','LineWidth',2);
    set(gca,'FontSize',24);
    xlabel('Rho');
    ylabel('\Phi [kV]');
    title('E-Static Potential');
    subplot(2,2,4);
    x = 0:0.001:1;
    f = pchip(sqrt(dprof(:,1)),dprof(:,3),x);
    plot(x,-1.0E-3.*gradient(f,x(2)-x(1))./vmec_data.Aminor,'k','LineWidth',2);
    set(gca,'FontSize',24);
    xlabel('Rho');
    ylabel('E_\rho [kV/m]');
    title('Rad. Electric Field');
    axis tight;
    saveas(fig,['recon_dprof_' ext '.fig']);
    saveas(fig,['recon_dprof_' ext '.png']);
    close(fig);
end



if ~isempty(boot_data)  && ~isempty(vmec_data)
    fig = figure('Position',[1 1 1024 768],'Color','white');
    mu0 = 4*pi*1E-6;
    dIda = 2.*sqrt(boot_data.s).*boot_data.dIds./mu0;
    plot(sqrt(boot_data.s),dIda./1E3,'ok','MarkerSize',8,'LineWidth',2);
    hold on;
    dIda_fit = 2.*sqrt(boot_data.s).*boot_data.j_fit./mu0;
    plot(sqrt(boot_data.s),dIda_fit./1E3,'r','LineWidth',2);
    dIda_vmec = 2.*sqrt(0:1./(vmec_data.ns-1):1).*vmec_data.jcurv;
    plot(sqrt(0:1./(vmec_data.ns-1):1),dIda_vmec./1E3,'b','LineWidth',2);
    set(gca,'FontSize',18);
    xlabel('Rho');
    ylabel('dI/d\rho [kA/m^{-2}]');
    title('BOOTSTRAP Profile');
    legend('BOOTSJ','FIT (power\_series)','VMEC');
    text(0.05,max(ylim)-0.10*diff(ylim),['VMEC Current : ' num2str(vmec_data.Itor./1E3) ' [kA]'],'FontSize',18);
    text(0.05,max(ylim)-0.15*diff(ylim),['BOOTSJ Current : ' num2str(boot_data.curtor./(mu0.*1E3)) ' [kA]'],'FontSize',18);
    saveas(fig,['recon_bootstrap_' ext '.fig']);
    saveas(fig,['recon_bootstrap_' ext '.png']);
    close(fig);
    fid = fopen(['recon_jprof_' ext '.txt'],'w');
    rho = 0:0.1:1;
    fprintf(fid,'  NCURR = 1\n');
    fprintf(fid,'  PCURR_TYPE = ''power_series''\n');
    fprintf(fid,'  AC =');
    fprintf(fid,' %20.10E ',boot_data.ac_poly);
    fprintf(fid,'\n');
    fprintf(fid,'!  CURTOR = %20.10E !FROM BOOTSJ\n',boot_data.curtor/mu0);
    fprintf(fid,'! FOR STELLOPT\n');
    fprintf(fid,'  BOOTJ_TYPE = ''power_series''\n');
    fprintf(fid,'  BOOTJ_AUX_F =');
    fprintf(fid,' %20.10E ',boot_data.ac_poly);
    fprintf(fid,'\n');
    fclose(fid);
end


if ~isempty(vmec_data)
    fig = figure('Position',[1 1 1024 768],'Color','white');
    zeta = [0 0.25 0.5].*2*pi/vmec_data.nfp;
    theta = 0:2*pi./(ntheta-1):2*pi;
    r = cfunct(theta,zeta,vmec_data.rmnc,vmec_data.xm,vmec_data.xn);
    z = sfunct(theta,zeta,vmec_data.zmns,vmec_data.xm,vmec_data.xn);
    b0=sum(vmec_data.bmnc);
    b0=b0(1);
    subplot(2,2,1);
    plot(r(end,:,3),z(end,:,3),'r','LineWidth',4);
    hold on;
    plot(r(end,:,2),z(end,:,2),'g','LineWidth',4);
    plot(r(end,:,1),z(end,:,1),'b','LineWidth',4);
    plot(r(1,1,3),z(1,1,3),'+r','MarkerSize',12,'LineWidth',4);
    plot(r(1,1,2),z(1,1,2),'+g','MarkerSize',12,'LineWidth',4);
    plot(r(1,1,1),z(1,1,1),'+b','MarkerSize',12,'LineWidth',4);
    hold off;
    axis equal;
    text(0.02*diff(xlim)+min(xlim),0.29*diff(ylim)+min(ylim),['V=' num2str(vmec_data.Volume,'%5.1f') ' m^3'],'FontSize',18);
    text(0.02*diff(xlim)+min(xlim),0.17*diff(ylim)+min(ylim),['\Phi=' num2str(vmec_data.phi(end),'%6.3f') ' Wb'],'FontSize',18);
    text(0.02*diff(xlim)+min(xlim),0.05*diff(ylim)+min(ylim),['B_0=' num2str(b0,'%5.2f') ' T'],'FontSize',18);
    set(gca,'FontSize',18);
    xlabel('R [m]');
    ylabel('Z [m]');
    title('VMEC Equilibrium');
    subplot(2,2,2);
    plot(vmec_data.phi./vmec_data.phi(end),vmec_data.presf./1E3,'k','LineWidth',2);
    text(0.02*diff(xlim)+min(xlim),0.07*diff(ylim)+min(ylim),['\beta=' num2str(vmec_data.betatot*100,'%4.2f') '%'],'FontSize',18);
    set(gca,'FontSize',18);
    xlabel('Norm. Flux (s)');
    ylabel('P [kPa]');
    title('Pressure Profile');
    subplot(2,2,3);
    plot(vmec_data.phi./vmec_data.phi(end),vmec_data.iotaf,'k','LineWidth',2);
    set(gca,'FontSize',18);
    xlabel('Norm. Flux (s)');
    ylabel('\iota');
    title('Rot. Trans. Profile');
    subplot(2,2,4);
    plot(vmec_data.phi./vmec_data.phi(end),vmec_data.jcurv./1E3,'k','LineWidth',2);
    text(0.02*diff(xlim)+min(xlim),0.07*diff(ylim)+min(ylim),['I_{tor}=' num2str(vmec_data.Itor./1E3,'%6.2f') ' kA'],'FontSize',18);
    set(gca,'FontSize',18);
    xlabel('Norm. Flux (s)');
    ylabel('dI/ds [kA/m^{-2}]');
    title('Current Profile');
    
    saveas(fig,['recon_vmec_' ext '.fig']);
    saveas(fig,['recon_vmec_' ext '.png']);
    close(fig);
end

end

