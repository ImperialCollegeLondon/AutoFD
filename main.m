% clear the workspace as usual
clear all
close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% AutoFDv2 code (26. March 2026)
%
% Derived from UK-Digital-Heart-Project/AutoFD Version 2.0
%			https://doi.org/10.5281/zenodo.1228962
%
% Major changes:
%
%   General workflow:
%       - modified and sucessfully tested on CPU-strong Linux servers
%       - not tested and adapted to work on Windows or Mac
%       - works only for matching image and segmentation NIfTI data sets by
%          checking the qoffset_xyz and image dimension parameters of the
%          NIfTI files
%       - runs over all subfolders (cases) of the source directory in one
%          parfor loop
%       - image output shows segments and boundary outlines in one overlay
%       - threshold image and interpolated ventricle are stored in
%          .mat-file for later contour analysis without need to calculate
%          the computational expensive level set segmentation again
%       - reports ventricle area, shared boundary with myocardium,
%          trabeculated mass ratio (TMR) and boundary lenght ratio (BLR)
%          additionally to the FDs
%       - please see enclosed bash script for linking data sets from
%          different remote folders to single local source folder
%       - better to use a local folder for storing the results
%
%   LevelSetMethod:
%       - image pixel intensity adjustment is restricted to 4Dsegment labels
%          of the processed ventricle and the LV myocardium which makes it
%          insensitive to pixel intensities outside of the used 4Dsegment
%          labels, e.g., fat or lungs and, therefore, insensitive to the
%          image bounding box size
%       - initialisation restricted to the 4Dsegment label of the processed
%          ventricle, which also makes it insensitive to the image bounding
%          box size
%       - bias field estimation restricted to the 4Dsegment labels of the
%          processed ventricle and adjecent LV myocardium by using nanconv.
%          Previously, the sourrounding pixels of the heart affected the
%          level set method which was also sensitive to the bounding box size
%
%   Box counting:
%       - fixed BoundingBox issue which does not work reliably on edge
%          images with multiple connected components
%       - added pre- and post-padding to already implemented central
%          padding for maximal efficient covering
%       - set largest box size to 25% of smallest object side to reduce
%          wrong box counts due to sampling errors at large box sizes
%       - average FDs for rotations from 0-90deg in 5deg steps which makes
%          FDs more insensitive to ventricle shape especially the less
%          circlular shape of the RV
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Configuration

% modify to the program folder to the path
addpath('~/AutoFDv2')
addpath(genpath('~/AutoFDv2/Dependencies'))

% set the folder to where the source data resides
param.TopLevelSourceFolder = '/data/AutoFDv2/Sources_TitinDCM/ED';
%param.TopLevelSourceFolder = '/data/AutoFDv2/Sources_TitinDCM/ES';

% set source file names
param.SourceImageFileName = 'sa.nii.gz';
param.SourceLabelsFileName = 'seg_sa.nii.gz';

% set the folder to where the results should be saved to
% best to use local folders here
param.TopLevelResultsFolder = '/data/AutoFDv2/Results_TitinDCM/LV_ED';
%param.TopLevelResultsFolder = '/data/AutoFDv2/Results_TitinDCM/LV_ES';
%param.TopLevelResultsFolder = '/data/AutoFDv2/Results_TitinDCM/RV_ED';
%param.TopLevelResultsFolder = '/data/AutoFDv2/Results_TitinDCM/RV_ES';

% please modify the segmentation label to select the LV or RV for analysis
param.SegLabel = 1; % LV label of 4Dsegment
%param.SegLabel = [ 3 4 ]; % RV label can be 3 or 4 depending on the used 4Dsegment version
% RV label is 4 for the UKBB_40616/4D_Segmented_2.0_to_do_motion data
% RV label is 3 for the UKBB_40616/10kWeinija data

% set flag if data should be reprocessed if csv-files already exists
% existing csv-files will not be overwritten, but renamed with timestamp 
% existing image and Matlab files will be overwritten
param.ReprocessExistingResults = 1;

% set different size thresholds for LV and RV
% - analysing the circular/ellipsoidal test contours suggested a minimum area of 100mm^2
% - FD estimation becomes more variable and breaks down for too small ventricle sizes
% - also, do not set size thresholds to 0, this can cause the code to crash
if param.SegLabel == 1 % LV
    %    param.MinVentricleSize = 450; % mm^2
    param.MinVentricleSize = 100; % mm^2 (circle)
    % only analyse LV which is to 100% sourunded by the myocardium
    % Shared Boundary Ratios higher than 1 are most likely erroneous segments
    % and better be excluded from further analysis.
    param.MinSharedBoundaryRatio = 0.8 ;
    param.MaxSharedBoundaryRatio = 1.2 ;
else %RV
    %    param.MinVentricleSize = 450; % mm^2 (RV ED)
    %    param.MinVentricleSize = 300; % mm^2 (RV ES)
    param.MinVentricleSize = 100; % mm^2 (ellipse)
    % RV shares less myocardium than LV so everything between 0-100% is OK
    param.MinSharedBoundaryRatio = 0 ;
    param.MaxSharedBoundaryRatio = 1.2 ;
end

% please make sure the slice order of the source data is ordered in this way
% there is no slice order check done in this code
param.AcquisitionOrder = 'Base to Apex';

% all data needs to be interpolated to 0.25mm pixels to allow the
% comparability with previous studies using the same interpolation pixel
% size
param.InterpolationType = 'Imresize - 0.25 mm pixels - cubic';
param.InterpolationPixelSize = 0.25;% mm

% the code will try to fuse fractured ventricle segments using imclose by
% increasing the kernel size in the steps defined here
% very small ventricle fragments, like 1 px strays, will be ignored
param.ImageClosureStepSize = 5 % mm

%% Initialisation

% locate all subfolders and check if there image and label NIfTI files
Listing = dir(param.TopLevelSourceFolder);
SubFolders = Listing(~ismember({Listing.name},{'.','..'}) & cell2mat({Listing.isdir}));
if isempty(SubFolders), error(sprintf('Error: No subfolders found in source directory! \n Please check folder names and file links.'));end
[status,cmdout] = system(['find -L ' param.TopLevelSourceFolder ' -type f  -name ' param.SourceImageFileName ' -print -quit']);
if isempty(cmdout), error(sprintf(['Error: No ' param.SourceImageFileName ' files or valid links found in subfolders! \n Please check folder names and file links.']));end
[status,cmdout] = system(['find -L ' param.TopLevelSourceFolder ' -type f  -name ' param.SourceLabelsFileName ' -print -quit']);
if isempty(cmdout), error(sprintf(['Error: No ' param.SourceLabelsFileName ' files or valid links found in subfolders! \n Please check folder names and file links.']));end
NFOLDERS = size(SubFolders, 1);

% check and create result folders
if ~exist(fullfile(param.TopLevelResultsFolder,'ImageOutput'),'file'), mkdir(fullfile(param.TopLevelResultsFolder,'ImageOutput'));end
if ~exist(fullfile(param.TopLevelResultsFolder,'MatOutput'),'file'), mkdir(fullfile(param.TopLevelResultsFolder,'MatOutput'));end
if ~exist(fullfile(param.TopLevelResultsFolder,'CSVoutput'),'file'), mkdir(fullfile(param.TopLevelResultsFolder,'CSVoutput'));end
if ~exist(fullfile(param.TopLevelResultsFolder,'ErrorOutput'),'file'), mkdir(fullfile(param.TopLevelResultsFolder,'ErrorOutput'));end

% define and check number of local workers
% do not use hyper-threading, this slows down everything due to the extensive I/O
NCORES = floor(feature('numcores'));
% get active parallel workers
ParPool=gcp('nocreate');
% start parallel workers if empty
if isempty(ParPool), ParPool = parpool('local', min(NCORES,NFOLDERS),'SpmdEnabled',false); end
% restart parallel workers if wrong number of workers
if ParPool.NumWorkers~=min(NCORES,NFOLDERS)
    delete(ParPool.Cluster.Jobs); ParPool = parpool('local', min(NCORES,NFOLDERS),'SpmdEnabled',false); end

%% Run image processing on each sub-folder

% the following lines are used for keeping count and showing the progress of the parfor loop
dq1 = parallel.pool.DataQueue;
dq2 = parallel.pool.DataQueue;
global pp; pp = 0; % global variable to keep track of parfor progress
afterEach(dq1, @(SubFolder) ShowProgress1(SubFolder,NFOLDERS));
afterEach(dq2, @(SubFolder) ShowProgress2(SubFolder,NFOLDERS));

tic;
parfor n = 1:NFOLDERS
    
% check and skip if Data-csv file exists and reprocessing flag is set to 1
if exist(fullfile(param.TopLevelResultsFolder,'CSVoutput',['Data-' SubFolders(n).name '.csv']),'file') ...
        &&  ~param.ReprocessExistingResults
    % increment and display parfor progress if processing was skipped
    send(dq1, SubFolders(n).name);
else
    % increment and display parfor progress if processing is executed
    send(dq2, SubFolders(n).name);
    % execute individual FD analysis
    subfoldermain(SubFolders(n).name, param);
end

end
toc;

%% Consolidate CSV output
ConsolidateCSVOutput(param);

%% Report completion
fprintf('Main script completed - all done !\n');

%% Functions for incrementing and displaying parfor progress
function ShowProgress1(SubFolder,NFOLDERS)
global pp; pp = pp + 1;
fprintf('CSV file exists! Skipping processing for: %s (%d/%d)\n' ,SubFolder,pp,NFOLDERS);
end
function ShowProgress2(SubFolder,NFOLDERS)
global pp; pp = pp + 1;
fprintf('Processing: %s (%d/%d)\n' ,SubFolder,pp,NFOLDERS);
end
