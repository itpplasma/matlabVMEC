function vmec_spectrum(data,varargin)
%VMEC_SPECTRUM Dumps the VMEC spectrum to the screen
%   Detailed explanation goes here

lspec = 0;
lvmec = 0;
lnescoil = 0;
lfocus = 1;
lhardcode = 0; % For hardcoding things in matlab
lflip = 0; % Flip the jacobian sign
data_save = data;
%
if (lflip)
    for i=1:data.mnmax
        m=data.xm(i);
        if (m>0)
            if mod(m,2) == 0
                data.zmns(i,:) = -data.zmns(i,:);
            else
                data.rmnc(i,:) = -data.rmnc(i,:);
            end
        end
    end
    data.xn = -data.xn;
end

% Note -xn is needed because we use (mu+nv) in MATLAB but VMEC needs
% (mu-nv)
s=data.ns;
%s=96;
if (data.iasym == 0)
    if lspec
        disp('mn   m   n   rmnc   zmns');
        for i=1:data.mnmax
            disp([num2str(i,'%3.3d') '   ' num2str(data.xm(i),'%2.2d') '   ' num2str(data.xn(i),'%+2.2d') '   ' num2str(data.rmnc(i,s),'%e') '   ' num2str(data.zmns(i,s),'%e') ]);
        end
        disp('  m   n   rmnc   zmns   rmns   zmnc');
        for i=1:data.mnmax
            disp(['   ' num2str(data.xm(i),'%2.2d') '   ' num2str(data.xn(i)./data.nfp,'%+2.2d') '   ' num2str(data.rmnc(i,s),'%e') '   ' num2str(data.zmns(i,s),'%e') '      0.0000000000E+00     0.0000000000E+00' ]);
        end
    elseif lnescoil
        disp('  m   n   rmnc   zmns   lmns   rmns   zmnc   lmnc');
        for i=1:data.mnmax
            disp(['   ' num2str(data.xm(i),'%2.2d') '   ' num2str(data.xn(i)./data.nfp,'%+2.2d') '   ' num2str(data.rmnc(i,s),'%e') '   ' num2str(data.zmns(i,s),'%e') '   ' num2str(data.lmns(i,s),'%e') '      0.0000000000E+00     0.0000000000E+00     0.0000000000E+00' ]);
        end
    elseif lvmec
        disp(['  RAXIS = ' num2str(data.rmnc(1:data.ntor+1,1)',' %20.12E ')]);
        disp(['  ZAXIS = ' num2str(data.zmns(1:data.ntor+1,1)',' %20.12E ')]);
        for i=1:data.mnmax
            disp(['  RBC(' num2str(data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i),'%2.2d') ') = ' num2str(data.rmnc(i,s),'%20.12E') '  ZBS(' num2str(data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i),'%2.2d') ') = ' num2str(data.zmns(i,s),'%20.12E') ]);
        end
    elseif lfocus
        disp('#bmn  bNfp nbf');
        disp([num2str(data.mnmax,'%3i ') ' ' num2str(data.nfp,'%3i ') ' ' num2str(data.mnmax,'%3i ')]);
        disp('#------plasma boundary harmonics-------');
        disp('# n m Rbc Rbs Zbc Zbs');
        for i=1:data.mnmax
            disp(['   '  num2str(data.xn(i)./data.nfp,'%+2.2d') '   ' num2str(data.xm(i),'%2.2d') '   ' num2str(data.rmnc(i,s),'%e') '      0.0000000000E+00      0.0000000000E+00 ' num2str(-data.zmns(i,s),'%e') ]);
        end
    elseif lhardcode
        disp(['  RAXIS = [' num2str(data.rmnc(1:data.ntor+1,1)',' %20.12E ') '];']);
        disp(['  ZAXIS = [' num2str(data.zmns(1:data.ntor+1,1)',' %20.12E ') '];']);
        nmax = max(data.xn)./data.nfp+1;
        for i=1:data.mnmax
            disp(['  RBC(' num2str(nmax-data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i)+1,'%2.2d') ') = ' num2str(data.rmnc(i,s),'%20.12E') ';  ZBS(' num2str(nmax-data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i)+1,'%2.2d') ') = ' num2str(data.zmns(i,s),'%20.12E') ';']);
        end
    end
else
    if lspec
        disp('mn   m   n   rmnc   rmns   zmnc   zmns');
        for i=1:data.mnmax
            disp([num2str(i,'%3.3d') '   ' num2str(data.xm(i),'%2.2d') '   ' num2str(data.xn(i),'%+2.2d')...]
                '   ' num2str(data.rmnc(i,s),'%e') '   ' num2str(data.rmns(i,s),'%e')...
                '   ' num2str(data.zmnc(i,s),'%e') '   ' num2str(data.zmns(i,s),'%e') ]);
        end
    elseif lnescoil
        disp('  m   n   rmnc   zmns   lmns   rmns   zmnc   lmnc');
        for i=1:data.mnmax
            disp(['   ' num2str(data.xm(i),'%2.2d') '   ' num2str(data.xn(i),'%+2.2d')...]
                '   ' num2str(data.rmnc(i,s),'%e') '   ' num2str(data.zmns(i,s),'%e') '   ' num2str(data.lmns(i,s),'%e')...
                '   ' num2str(data.zmnc(i,s),'%e') '   ' num2str(data.zmns(i,s),'%e') '   ' num2str(data.lmnc(i,s),'%e') ]);
        end
    elseif lfocus
        disp('#Nbmn  Nfp Nbnorm:');
        disp([num2str(data.mnmax,'%3i ') num2str(data.nfp,'%3i ') num2str(data.mnmax,'%3i ')]);
        disp('#------plasma boundary harmonics-------');
        disp('# n m Rbc Rbs Zbc Zbs');
        for i=1:data.mnmax
            disp(['   '  num2str(data.xn(i),'%+2.2d') '   ' num2str(data.xm(i),'%2.2d') '   ' num2str(data.rmnc(i,s),'%e') '   ' num2str(-data.rmns(i,s),'%e') '   ' num2str(data.zmnc(i,s),'%e') '   ' num2str(-data.zmns(i,s),'%e') ]);
        end
    elseif lvmec
        disp(['  RAXIS_CC = ' num2str(data.rmnc(1:data.ntor+1,1)',' %20.12E %20.12E %20.12E %20.12E %20.12E ')]);
        disp(['  RAXIS_CS = ' num2str(data.rmns(1:data.ntor+1,1)',' %20.12E %20.12E %20.12E %20.12E %20.12E ')]);
        disp(['  ZAXIS_CS = ' num2str(data.zmns(1:data.ntor+1,1)',' %20.12E %20.12E %20.12E %20.12E %20.12E ')]);
        disp(['  ZAXIS_CC = ' num2str(data.zmnc(1:data.ntor+1,1)',' %20.12E %20.12E %20.12E %20.12E %20.12E ')]);
        for i=1:data.mnmax
            disp(['  RBC(' num2str(-data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i),'%2.2d') ') = ' num2str(data.rmnc(i,s),'%20.12E') '  ZBS(' num2str(-data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i),'%2.2d') ') = ' num2str(data.zmns(i,s),'%20.12E') ]);
            disp(['    RBS(' num2str(-data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i),'%2.2d') ') = ' num2str(data.rmns(i,s),'%20.12E') '    ZBC(' num2str(-data.xn(i)./data.nfp,'%2.2d') ',' num2str(data.xm(i),'%2.2d') ') = ' num2str(data.zmnc(i,s),'%20.12E') ]);
        end
    end
end
data =data_save;

end

