function [u, b]= lse_bfe_nanconv(u0,Img, b, Ksigma, KONE, nu,timestep,mu,epsilon, iter_lse, MaskVentricleMyocardium)
% This code implements the level set evolution (LSE) and bias field estimation (BFE) 
% proposed in the following paper:
%      C. Li, R. Huang, Z. Ding, C. Gatenby, D. N. Metaxas, and J. C. Gore, 
%      "A Level Set Method for Image Segmentation in the Presence of Intensity
%      Inhomogeneities with Application to MRI", IEEE Trans. Image Processing, 2011
%
% Note: 
%    This code implements the two-phase formulation of the model in the above paper.
%    The two-phase formulation uses the signs of a level set function to represent
%    two disjoint regions, and therefore can be used to segment an image into two regions,
%    which are represented by (u>0) and (u<0), where u is the level set function.
%
%    All rights researved by Chunming Li, who formulated the model, designed and 
%    implemented the algorithm in the above paper.
%
% E-mail: lchunming@gmail.com
% URL: http://www.engr.uconn.edu/~cmli/
% Copyright (c) by Chunming Li
% Author: Chunming Li

% JanS: use nancov to ignore pixels outside of combined mask
b(~MaskVentricleMyocardium)=nan;
KB1 = nanconv(b,Ksigma,'edge');
KB2 = nanconv(b.^2,Ksigma,'edge');
KB1(~MaskVentricleMyocardium)=0;
KB2(~MaskVentricleMyocardium)=0;
%KB1 = conv2(b,Ksigma,'same');
%KB2 = conv2(b.^2,Ksigma,'same');

C = updateC(Img, u0, KB1, KB2, epsilon, MaskVentricleMyocardium);

KONE_Img = Img.^2.*KONE;
u = updateLSF(Img, u0, C, KONE_Img, KB1, KB2, mu, nu, timestep, epsilon, iter_lse);
%JanS: reset anything outside combined mask to initialLSF
u(~MaskVentricleMyocardium)=-1;

Hu=Heaviside(u,epsilon);
M(:,:,1)=Hu;
M(:,:,2)=1-Hu;
b = updateB(Img, C, M,  Ksigma, MaskVentricleMyocardium);


% update level set function
function u = updateLSF(Img, u0, C, KONE_Img, KB1, KB2, mu, nu, timestep, epsilon, iter_lse)
u=u0;
Hu=Heaviside(u,epsilon);
M(:,:,1)=Hu;
M(:,:,2)=1-Hu;
N_class=size(M,3);
e=zeros(size(M));
for kk=1:N_class
    e(:,:,kk) = KONE_Img - 2*Img.*C(kk).*KB1 + C(kk)^2*KB2;
end

for kk=1:iter_lse
    K=curvature_central(u);    % div()
    DiracU=Dirac(u,epsilon);
    ImageTerm=-DiracU.*(e(:,:,1)-e(:,:,2));
    penalizeTerm=mu*(4*del2(u)-K);
    lengthTerm=nu.*DiracU.*K;
    u=u+timestep*(lengthTerm+penalizeTerm+ImageTerm);
end

% update b
function b =updateB(Img, C, M,  Ksigma, MaskVentricleMyocardium)

PC1=zeros(size(Img));
PC2=PC1;
N_class=size(M,3);
for kk=1:N_class
    PC1=PC1+C(kk)*M(:,:,kk);
    PC2=PC2+C(kk)^2*M(:,:,kk);
end
% JanS: use nancov to ignore pixels outside of combined mask
PC1(~MaskVentricleMyocardium)=nan;
PC2(~MaskVentricleMyocardium)=nan;
KNm1 = nanconv(PC1.*Img,Ksigma,'edge');
KDn1 = nanconv(PC2,Ksigma,'edge');
KNm1(~MaskVentricleMyocardium)=0;
KDn1(~MaskVentricleMyocardium)=0;
%KNm1 = conv2(PC1.*Img,Ksigma,'same');
%KDn1 = conv2(PC2,Ksigma,'same');


b = KNm1./KDn1;

% Update C
function C_new =updateC(Img, u, Kb1, Kb2, epsilon, MaskVentricleMyocardium)
Hu=Heaviside(u,epsilon);
M(:,:,1)=Hu;
M(:,:,2)=1-Hu;
N_class=size(M,3);
C_new=zeros(N_class,1);
for kk=1:N_class
    Nm2 = Kb1.*Img.*M(:,:,kk);
    Dn2 = Kb2.*M(:,:,kk);
%JanS: sum only over combined mask and ignor anything outside of it
    C_new(kk) = sum(Nm2(MaskVentricleMyocardium(:)))/sum(Dn2(MaskVentricleMyocardium(:)));
%    C_new(kk) = sum(Nm2(:))/sum(Dn2(:));
end

function k = curvature_central(u)
% compute curvature for u with central difference scheme
[ux,uy] = gradient(u);
normDu = sqrt(ux.^2+uy.^2+1e-10);
Nx = ux./normDu;
Ny = uy./normDu;
[nxx,~] = gradient(Nx);
[~,nyy] = gradient(Ny);
k = nxx+nyy;

function h = Heaviside(x,epsilon)    
h=0.5*(1+(2/pi)*atan(x./epsilon));

function f = Dirac(x, epsilon)    
f=(epsilon/pi)./(epsilon^2.+x.^2);

