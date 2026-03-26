function ImageContour = LevelSetMethod(Image, VentricleMask, MyocardiumVentricleMask)

% This code applies the level set evolution (LSE) and bias field estimation (BFE) 
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

% set outside of mask to zero
    Image(~MyocardiumVentricleMask) = 0;

% crop to 2px larger bounding box to prevent artifacts at the image border
    bbx=find(max(MyocardiumVentricleMask,[],2));
    bbx=bbx([1 end])+[-1; +1]*2;
    bby=find(max(MyocardiumVentricleMask,[],1));
    bby=bby([1 end])+[-1 +1]*2;

    Img=Image(bbx(1):bbx(2),bby(1):bby(2));
    VentricleMask=VentricleMask(bbx(1):bbx(2),bby(1):bby(2));
    MyocardiumVentricleMask=MyocardiumVentricleMask(bbx(1):bbx(2),bby(1):bby(2));
    
sigma   = 4;
epsilon = 3;

A   = 255;

Img = Img * A;

nu  = 0.001*A^2;            % Coefficient of arc length term

iter_outer = 100;           % Outer iteration for level set evolution
iter_inner = 10;            % Inner iteration for level set evolution

timestep = 0.1;
mu = 1;                     % Coefficient for distance regularization term (regularize the level set function)

% Initialize level set function
initialLSF = - ones(size(Img));
% initialise using ventrice mask
initialLSF(VentricleMask) = 1;

u = initialLSF;

b = ones(size(Img));                                     % Initialize the bias field

K = fspecial('gaussian', round(2*sigma)*2 + 1, sigma);   % Gaussian kernel

KONE = ones(size(Img));

for n=1:iter_outer
    % run level set evolution with nanconv bias field estimation
    % nanconv restricst the bfe to the ventricle and myocardium
    [u, b] = lse_bfe_nanconv(u, Img, b, K, KONE, nu, timestep, mu, epsilon, iter_inner, MyocardiumVentricleMask);
end
% remove mis-segmentation outside of ventricle, e.g., at outer myocardium border of the heart
contourI = (u > 0) & VentricleMask;

ImageContour=zeros(size(Image));
    ImageContour(bbx(1):bbx(2),bby(1):bby(2))=contourI;

end

