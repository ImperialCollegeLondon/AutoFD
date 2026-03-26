function subfoldermain(SubFolder, param)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% AutoFDv2 code (26. March 2026)
%
% The subfoldermain function does all the processing for each individual sub-folder.
% 
% Changelog to previous version (9. September 2024)
% - added functionality to also work with interpolated segmentation data
% - simplified the BLR calculaion by using the edge of the ventricle label
%   instead of the complicated caclulation of the boundary
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% used for testing subfoldermain routine: n = 3; SubFolder = SubFolders(n).name

% generate output file name
ImageOutputFileName = fullfile(param.TopLevelResultsFolder,'ImageOutput', sprintf('Image-%s.png', SubFolder));
MatOutputFileName = fullfile(param.TopLevelResultsFolder,'MatOutput', sprintf('Matlab-%s.mat', SubFolder));
CSVoutputFileName = fullfile(param.TopLevelResultsFolder,'CSVoutput', sprintf('Data-%s.csv', SubFolder));
ErrorOutputFileName = fullfile(param.TopLevelResultsFolder,'ErrorOutput', sprintf('Error-%s.log', SubFolder));

% check if CSV output already exists and rename with timestamp for backup
if exist(CSVoutputFileName, 'file') == 2
    timestamp = datetime('now','TimeZone','local','Format','yyyyMMddHHmmssSSSS');
    CSVoutputBackupFileName = fullfile(param.TopLevelResultsFolder,'CSVoutput', sprintf('Backup-%s-%s.csv', SubFolder,timestamp));
    movefile(CSVoutputFileName, CSVoutputBackupFileName);
end

% check if Error log already exists and rename with timestamp for backup
if exist(ErrorOutputFileName, 'file') == 2
    timestamp = datetime('now','TimeZone','local','Format','yyyyMMddHHmmssSSSS');
    ErrorOutputBackupFileName = fullfile(param.TopLevelResultsFolder,'ErrorOutput', sprintf('Backup-%s-%s.log', SubFolder,timestamp));
    movefile(ErrorOutputFileName, ErrorOutputBackupFileName);
end

% check if source data exists
if exist(fullfile(param.TopLevelSourceFolder,SubFolder, param.SourceImageFileName),'file') ~= 2 ...
        || exist(fullfile(param.TopLevelSourceFolder,SubFolder, param.SourceLabelsFileName),'file') ~= 2
    % write error log if source data is missing
    errfid = fopen(ErrorOutputFileName, 'at');
    fprintf(errfid, '%s\n', 'Image or segmentation data not found.');
    fclose(errfid);
    % return the subfolder main function without any further processing
    return;
end

%% load NIfTI data

img_nii = load_untouch_nii(fullfile(param.TopLevelSourceFolder,SubFolder, param.SourceImageFileName));
seg_nii = load_untouch_nii(fullfile(param.TopLevelSourceFolder,SubFolder, param.SourceLabelsFileName));

% this was added to also work with interpolated segmentation data
if size(img_nii.img,3) < size(seg_nii.img,3)
% downscale interpolated segmentation
seg_nii.img = seg_nii.img(:,:,round(1+[1:size(seg_nii.img,3)/size(img_nii.img,3):size(seg_nii.img,3)]));
seg_nii.img = imresize3(seg_nii.img,size(img_nii.img),"nearest");
% imshow(seg_nii.img(:,:,8),[],'init',300)
end

% check if xy-position matches between image and segmentation data set
% round offsets and pixdims to 1% accuracy to still keep analysing slight
% misaligned data sets
if round(img_nii.hdr.hist.qoffset_x*100) ~= round(seg_nii.hdr.hist.qoffset_x*100) || ...
        round(img_nii.hdr.hist.qoffset_y*100) ~= round(seg_nii.hdr.hist.qoffset_y*100) || ...
        max(size(img_nii.img,2,3) ~= size(seg_nii.img,2,3)) %|| ...
      %  max(round(img_nii.hdr.dime.pixdim(2:3)*100) ~= round(seg_nii.hdr.dime.pixdim(2:3)*100))
    % write error log if source data is not matching up
    errfid = fopen(ErrorOutputFileName, 'at');
    fprintf(errfid, '%s\n', 'Image and segmentation data does not match in xy-plane position and/or dimension.');
    fclose(errfid);
    % return the subfolder main function without any further processing
    return;
end

if  round(img_nii.hdr.hist.qoffset_z*100) ~= round(seg_nii.hdr.hist.qoffset_z*100) %|| ...
     %   img_nii.hdr.dime.dim(4) ~= seg_nii.hdr.dime.dim(4) || ...
     %   round(img_nii.hdr.dime.pixdim(4)*100) ~= round(seg_nii.hdr.dime.pixdim(4)*100)
    % write error log if source data is not matching up
    errfid = fopen(ErrorOutputFileName, 'at');
    fprintf(errfid, '%s\n', 'Image and segmentation data does not match in z-position and/or dimension.');
    fclose(errfid);
    % return the subfolder main function without any further processing
    return;
end

% check if there are any pixel values in the image data
if sum(img_nii.img(:)) == 0
    % write error log if source data is missing
    errfid = fopen(ErrorOutputFileName, 'at');
    fprintf(errfid, '%s\n', 'No pixel values in the image data.');
    fclose(errfid);
    % return the subfolder main function without any further processing
    return;
end

% get original image resolution
param.OriginalResolution = img_nii.hdr.dime.pixdim(2);
% get image slice thickness
param.SliceThickness = img_nii.hdr.dime.pixdim(4);
% get number of slices
param.NumSlices = img_nii.hdr.dime.dim(4);

% make logical array for LV or RV as defined in param.SegLabel
LVRV=zeros(size(seg_nii.img),'logical');
for s=1:numel(param.SegLabel)
    LVRV = LVRV | logical(seg_nii.img == param.SegLabel(s));
end

% make logical array for LV which is labeled as 1
LV = logical(seg_nii.img == 1);
% make logical array for myocardium which is labeled as 2
Myo = logical(seg_nii.img == 2);
% make logical array for RV
RV = logical(seg_nii.img == 3);
RV = RV | logical(seg_nii.img == 4);

% check if there are all the expected labels in the segmentation data
if sum(LV(:)) == 0 || sum(Myo(:)) == 0 || sum(RV(:)) == 0
    % write error log if source data is missing
    errfid = fopen(ErrorOutputFileName, 'at');
    fprintf(errfid, '%s\n', 'No LV, Myo or RV labels in the segmentation data.');
    fclose(errfid);
    % return the subfolder main function without any further processing
    return;
end

%% check slice-by-slice if ventricle is fractured and try to close, also fill any holes
failedimclose = zeros(param.NumSlices,1,'logical');

for slc=1:param.NumSlices
    
    % do not process if ventricle volume is less than half of threshold size
    if sum(sum(LVRV(:,:,slc))) > param.MinVentricleSize/param.OriginalResolution.^2/2
        
        % get number of connected regions
        CC = bwconncomp(LVRV(:,:,slc), 4);
        
        % check and correct small stray regions if more than 1 separate region was found
        if (CC.NumObjects > 1)
            
            % get size of all separate regions
            cellnumel=zeros(CC.NumObjects,1);
            for c=1:CC.NumObjects
                cellnumel(c)=numel(CC.PixelIdxList{c});
            end
            % ignore and delete small stray regions (< 10% of largest region)
            for c=1:CC.NumObjects
                if cellnumel(c) < 0.1*max(cellnumel)
                    tmp = LVRV(:,:,slc);
                    tmp(CC.PixelIdxList{c})=0;
                    LVRV(:,:,slc) = tmp;
                end
            end
            
        end
        
        % get number of connected regions after correcting for small stray regions
        CC = bwconncomp(LVRV(:,:,slc), 4);
        
        % try to fuse if more than 1 separate large regions are found
        if (CC.NumObjects > 1)
            
            Radius = 0.0;
            DR     = ceil(param.ImageClosureStepSize/param.OriginalResolution);
            maxhalfdim = round(max(size(LVRV,[1 2]))/2);
            
            while (CC.NumObjects > 1)
                Radius = Radius + DR;
                Disk = strel('disk', Radius);
                LVRV(:,:,slc) = imclose(LVRV(:,:,slc), Disk);
                
                CC = bwconncomp(LVRV(:,:,slc), 4);
                
                % Stop while loop and write error log
                if (Radius > maxhalfdim)
                    errfid = fopen(ErrorOutputFileName, 'at');
                    fprintf(errfid, '%s%i\n', 'imclose not working on fractured ventricle for slice ',slc);
                    fclose(errfid);
                    failedimclose(slc)=1;
                    break
                end
                
            end
            
        end
        % also fill holes in case there are any
        LVRV(:,:,slc) = imfill(LVRV(:,:,slc), 8, 'holes');
        
    end
end

%% get pixel counts for ventricle area and boundary and shared boundary with myocardium
VentricleArea = zeros(20,1);
MyoArea = zeros(20,1);
VentricleBoundary = zeros(20,1);
VentrMyoSharedBoundary = zeros(20,1);
Disk = strel('disk', 1);

for slc=1:param.NumSlices
    if ~failedimclose(slc)
        VentricleArea(slc) = sum(sum(LVRV(:,:,slc)))*param.OriginalResolution.^2;
        MyoArea(slc) = sum(sum(Myo(:,:,slc)))*param.OriginalResolution.^2;
        if param.SegLabel == 1
            % important to take perimeter since overlapping pixels will be
            % counted as shared boundary
            VentricleBoundary(slc) = sum(sum(bwperim(LVRV(:,:,slc))));
        else
            VentricleBoundary(slc) = sum(sum(bwperim(bwconvhull(Myo(:,:,slc)))));
            % imshow(Myo(:,:,slc)+bwconvhull(Myo(:,:,slc)),[])
        end
        % dilate by 1px to get boundary between myocardium and ventricle label 
        MyoDil = imdilate(Myo(:,:,slc),Disk);
        % delete already overlapping labels but fill 1px gap between them 
        MyoDil(LVRV(:,:,slc)) = 0;
        % dilate again by 1px to get overlap for counting shared boundary,
        % even if the labels are 1px apart
        MyoDil = imdilate(MyoDil,Disk);
        % the overlap is the shared boundary
        MyoDilShrdBound = MyoDil & LVRV(:,:,slc);
        VentrMyoSharedBoundary(slc) = sum(MyoDilShrdBound(:));
        %imshow(MyoDil+MyoDilShrdBound,[])
        %imshow(MyoDilShrdBound-bwperim(LVRV(:,:,slc)),[])
    end
end
VentrMyoSharedBoundaryRatio=VentrMyoSharedBoundary./VentricleBoundary;

%% Crop and interpolate

% combined myocardium and ventricle mask is used for later LevelSetMethod
VentricleMyocardium = LVRV | Myo;

% everything 10mm away from the LVRV label is set to zero and cropped
% to keep computation time down especially for the RV
LVRV_dil=imdilate(LVRV,strel('disk',round(10/param.OriginalResolution)));
% imshow(VentricleMyocardium(:,:,5)-LVRV_dil(:,:,5),[])
VentricleMyocardium = VentricleMyocardium & LVRV_dil;
% imshow(VentricleMyocardium(:,:,5),[])

% find maximum in-plane extend of VentricleMyocardium label
maxcroparea=max(VentricleMyocardium,[],3);
% imshow(maxcroparea,[])
bbx=find(max(maxcroparea,[],2));
bbx=bbx([1 end])+[-1; +1];
bby=find(max(maxcroparea,[],1));
bby=bby([1 end])+[-1 +1];

% crop
LV_cropped=LV(bbx(1):bbx(2),bby(1):bby(2),:);
RV_cropped=RV(bbx(1):bbx(2),bby(1):bby(2),:);
Myo_cropped=Myo(bbx(1):bbx(2),bby(1):bby(2),:);
VentricleMyocardium_cropped=VentricleMyocardium(bbx(1):bbx(2),bby(1):bby(2),:);
LVRV_cropped=LVRV(bbx(1):bbx(2),bby(1):bby(2),:);
Img_cropped=double(img_nii.img(bbx(1):bbx(2),bby(1):bby(2),:));

% calculate magnification factor
Magnification = param.OriginalResolution/param.InterpolationPixelSize;
[ MR, MC ] = size(Img_cropped(:,:,1));
NR = uint16(round(Magnification*MR));
NC = uint16(round(Magnification*MC));

% interpolate
Img_interp = imresize(Img_cropped, [NR, NC], 'cubic');
LVRV_interp = imresize(LVRV_cropped, [NR, NC], 'cubic');
VentricleMyocardium_interp = imresize(VentricleMyocardium_cropped, [NR, NC], 'cubic');
LV_interp = imresize(LV_cropped, [NR, NC], 'cubic');
RV_interp = imresize(RV_cropped, [NR, NC], 'cubic');
Myo_interp = imresize(Myo_cropped, [NR, NC], 'cubic');

% slice-by-slice image intensity adjustment
for slc=1:param.NumSlices
    
    Image_slc=Img_interp(:,:,slc);
    if VentricleArea(slc) > param.MinVentricleSize ...
            && VentrMyoSharedBoundaryRatio(slc) >= param.MinSharedBoundaryRatio ...
            && VentrMyoSharedBoundaryRatio(slc) <= param.MaxSharedBoundaryRatio
        
        MyocardiumVentricleMask_slc=logical(VentricleMyocardium_interp(:,:,slc));
        VentricleMask_slc=logical(LVRV_interp(:,:,slc));
        % scale between 0 and 1 within combined mask and saturate 1% of lowest and
        % highest pixel intensities to adjust pixel intensities
        Imin = quantile(Image_slc(MyocardiumVentricleMask_slc(:)),0.01);
        Imax = quantile(Image_slc(VentricleMask_slc(:)),0.99);
    else
        Imin = quantile(Image_slc(:),0.01);
        Imax = quantile(Image_slc(:),0.99);
    end
    Img = (Image_slc - Imin)/(Imax - Imin);
    Img(Img<0)=0;
    Img(Img>1)=1;
    Img_interp(:,:,slc)=Img;
end


%% slice-by-slice level set segmentation and FD caclulation
% initialise array for storing fractal dimensions of each slice
FDs=zeros(20,1)*nan; % Fractal Dimension
TMR=zeros(20,1)*nan; % Trabeculated Mass Ratio
BLR=zeros(20,1)*nan; % Boundary Length Ratio

% initialise array for storing images of each slice
ImgOut=zeros([size(Img_interp(:,:,1)) 3 param.NumSlices]);

MatOut=zeros(size(Img_interp));

for slc=1:param.NumSlices
    
    LVRV_interp_slc=LVRV_interp(:,:,slc);
    Img_interp_slc=Img_interp(:,:,slc);
    VentricleMyocardium_interp_slc=VentricleMyocardium_interp(:,:,slc);
    
    % scale image data to only 50% of full contrast to better see colored
    % edges which are added with full color contrast
    RGBoutImg=repmat(Img_interp_slc,1,1,3)*0.5;
    tmp=RGBoutImg(:,:,1); tmp(edge(LV_interp(:,:,slc), 'Sobel') | edge(RV_interp(:,:,slc), 'Sobel'))=1;
    RGBoutImg(:,:,1)=tmp;
    tmp=RGBoutImg(:,:,3); tmp(edge(Myo_interp(:,:,slc), 'Sobel'))=1;
    RGBoutImg(:,:,3)=tmp;
    
    % only process if there is ventricle and myocardium in the slice
    if VentricleArea(slc) > param.MinVentricleSize ...
            && VentrMyoSharedBoundaryRatio(slc) >= param.MinSharedBoundaryRatio ...
            && VentrMyoSharedBoundaryRatio(slc) <= param.MaxSharedBoundaryRatio
        
        % LevelSetDetection
        ThresholdImage = LevelSetMethod(Img_interp_slc, LVRV_interp_slc, VentricleMyocardium_interp_slc);
        %imshow(Img_interp_slc+LVRV_interp_slc+VentricleMyocardium_interp_slc,[]);
        %imshow(ThresholdImage+Img_interp_slc);
        
        % find connected components in binary image
        CC = bwconncomp(ThresholdImage, 4);
        
        % check and correct small stray regions if more than 1 separate region was found
        if (CC.NumObjects > 1)
            
            % get size of all separate regions
            cellnumel=zeros(CC.NumObjects,1);
            for c=1:CC.NumObjects
                cellnumel(c)=numel(CC.PixelIdxList{c});
            end
            % ignore and delete small stray regions (< 1% of largest region)
            for c=1:CC.NumObjects
                if cellnumel(c) < 0.01*max(cellnumel)
                    tmp = ThresholdImage;
                    tmp(CC.PixelIdxList{c})=0;
                    ThresholdImage = tmp;
                end
            end
            
        end
        % imshow(ThresholdImage)
        
        %  correct wrongly detected blood pool segment, if image intensity is lower for
        %  supposed blood pool segment with respect to supposed trabeculae segment
        if mean(Img_interp_slc(ThresholdImage(:) & LVRV_interp_slc(:))) < mean(Img_interp_slc(~ThresholdImage(:) & LVRV_interp_slc(:))) ...
                || isnan(mean(Img_interp_slc(ThresholdImage(:) & LVRV_interp_slc(:))))
            ThresholdImage = ~ThresholdImage;
        end
        
        % put ThresholdImage into Matlab output
        MatOut(:,:,slc) = ThresholdImage;
        
        % put ThresholdImage into image output
        tmp=RGBoutImg(:,:,2); tmp(edge(ThresholdImage, 'Sobel'))=1;
        RGBoutImg(:,:,2)=tmp;
        % imshow(RGBoutImg,[])
        
        % Box-counting while rotating image from 0-90deg and taking mean FD
        FDrot=zeros(19,1);
        TMRrot=zeros(19,1);
        BLRrot=zeros(19,1);

        % reset EdgeImageRot cell array and minimim image size
        clearvars 'EdgeImageRot' 'RotImage'
        minimgsz = min(size(ThresholdImage));

        % rotate object from 0-90deg in 5deg steps
        for r=1:19
            RotImage{r}=imrotate(ThresholdImage,(r-1)*5,'bicubic');
            EdgeImage = edge(RotImage{r}, 'Sobel');
            bbx=find(max(EdgeImage,[],2));
            bbx=bbx([1 end]);
            bby=find(max(EdgeImage,[],1));
            bby=bby([1 end]);
            EdgeImageRot{r}=EdgeImage(bbx(1):bbx(2),bby(1):bby(2));
            % get minimum object size to be used for box counting method
            % over all 0-90deg object rotations
            minimgsz = min([size( EdgeImageRot{r}),minimgsz]);
            % imshow(EdgeImage)
        end
        
        % set largest box size to 25% of smallest object dimension
        % this avoids the sampling errors at larger box sizes
        maxboxsz = floor(0.25*minimgsz);

        % set smallest box size to 2 pixel
        % this should be higher for true FD measurements, but larger box sizes 
        % exclude the FD estimation of smaller ventricles
        minboxsz = 2;
        
        for r=1:19
            [ boxcnt, boxsz] = bxct(EdgeImageRot{r},minboxsz,maxboxsz);
            
            boxfitrot = polyfit(log(boxsz), log(boxcnt), 1);
            FDrot(r)=-boxfitrot(1);
            
            % alternative trabeculation measurements:
            % - Trabeculated Mass Ratio (TMR)
            LVRV_interp_slc_rot = imrotate(LVRV_interp_slc,(r-1)*5,'bicubic');
            TMRrot(r) = 1 - ( sum(RotImage{r}(:)) / sum(LVRV_interp_slc_rot(:)) );

            % - Boundary Length Ratio (BLR) - simplified calculation
            rotLVRV_interp_slc_edge = edge(LVRV_interp_slc_rot, 'Sobel');
            BLRrot(r) =  sum(rotLVRV_interp_slc_edge(:)) / sum(EdgeImageRot{r}(:));
                       
        end
        FDs(slc) = mean(FDrot);
        TMR(slc) = mean(TMRrot);
        BLR(slc) = mean(BLRrot);
        
    end
    ImgOut(:,:,:,slc)=RGBoutImg;
    
end
save(MatOutputFileName,'MatOut','LVRV_interp');

%% generate CSV output

csvfid = fopen(CSVoutputFileName, 'wt');

% output FDs
FDs(FDs==0)=nan;
FormattedOutput=sprintf([repmat('%.9f,',1,19),'%.9f'],FDs);
OutputData = sprintf('%s,%s,%s,%.2f,%.2f,%.4f,%.4f,%.2f,%1d,%s', ...
    SubFolder, param.AcquisitionOrder, param.InterpolationType, ...
    param.MinVentricleSize, param.ImageClosureStepSize, ...
    param.OriginalResolution, param.InterpolationPixelSize, ...
    param.SliceThickness, param.NumSlices, FormattedOutput);
% replace NaN with NA which is supported by R
OutputData = strrep(OutputData, 'NaN', 'NA');
fprintf(csvfid, '%s\n', OutputData);

% output ventricle size
VentricleArea = MyoArea;
VentricleArea(VentricleArea==0)=nan;
FormattedOutput=sprintf([repmat('%.2f,',1,19),'%.2f'],VentricleArea);
OutputData = sprintf('%s,%s,%s,%.2f,%.2f,%.4f,%.4f,%.2f,%1d,%s', ...
    SubFolder, param.AcquisitionOrder, param.InterpolationType, ...
    param.MinVentricleSize, param.ImageClosureStepSize, ...
    param.OriginalResolution, param.InterpolationPixelSize, ...
    param.SliceThickness, param.NumSlices, FormattedOutput);
% replace NaN with NA which is supported by R
OutputData = strrep(OutputData, 'NaN', 'NA');
fprintf(csvfid, '%s\n', OutputData);

% output shared ventricle myocard boundary ratio
VentrMyoSharedBoundaryRatio(VentrMyoSharedBoundaryRatio==0)=nan;
FormattedOutput=sprintf([repmat('%.4f,',1,19),'%.4f'],VentrMyoSharedBoundaryRatio);
OutputData = sprintf('%s,%s,%s,%.2f,%.2f,%.4f,%.4f,%.2f,%1d,%s', ...
    SubFolder, param.AcquisitionOrder, param.InterpolationType, ...
    param.MinVentricleSize, param.ImageClosureStepSize, ...
    param.OriginalResolution, param.InterpolationPixelSize, ...
    param.SliceThickness, param.NumSlices, FormattedOutput);
% replace NaN with NA which is supported by R
OutputData = strrep(OutputData, 'NaN', 'NA');
fprintf(csvfid, '%s\n', OutputData);

% output Boundary Length Ratio
BLR(BLR==0)=nan;
FormattedOutput=sprintf([repmat('%.9f,',1,19),'%.9f'],BLR);
OutputData = sprintf('%s,%s,%s,%.2f,%.2f,%.4f,%.4f,%.2f,%1d,%s', ...
    SubFolder, param.AcquisitionOrder, param.InterpolationType, ...
    param.MinVentricleSize, param.ImageClosureStepSize, ...
    param.OriginalResolution, param.InterpolationPixelSize, ...
    param.SliceThickness, param.NumSlices, FormattedOutput);
% replace NaN with NA which is supported by R
OutputData = strrep(OutputData, 'NaN', 'NA');
fprintf(csvfid, '%s\n', OutputData);

% output Trabeculated Mass Ratio
TMR(TMR==0)=nan;
FormattedOutput=sprintf([repmat('%.9f,',1,19),'%.9f'],TMR);
OutputData = sprintf('%s,%s,%s,%.2f,%.2f,%.4f,%.4f,%.2f,%1d,%s', ...
    SubFolder, param.AcquisitionOrder, param.InterpolationType, ...
    param.MinVentricleSize, param.ImageClosureStepSize, ...
    param.OriginalResolution, param.InterpolationPixelSize, ...
    param.SliceThickness, param.NumSlices, FormattedOutput);
% replace NaN with NA which is supported by R
OutputData = strrep(OutputData, 'NaN', 'NA');
fprintf(csvfid, '%s\n', OutputData);

fclose(csvfid);

%% generate image output

xsz=size(ImgOut,2);
ysz=size(ImgOut,1);

ComImgOut=zeros(xsz*ceil(param.NumSlices/4),xsz*4,3);
slc=0;
for slcy=1:ceil(param.NumSlices/4)
    for slcx=1:4
        slc=slc+1;
        if slc<=param.NumSlices
            ComImgOut(ysz*(slcy-1)+1:ysz*(slcy-1)+ysz,xsz*(slcx-1)+1:xsz*(slcx-1)+xsz,:)=ImgOut(:,:,:,slc);
        end
    end
end
%close 1, figure(1), imshow(ComImgOut)
imwrite(ComImgOut,ImageOutputFileName);

end
