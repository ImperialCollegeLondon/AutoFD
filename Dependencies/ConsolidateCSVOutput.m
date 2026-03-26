function ConsolidateCSVOutput(param)

% Check summary CSV files exist and backup old files
SummaryCSVoutputFileName_FD = fullfile(param.TopLevelResultsFolder, 'SummaryOutput_FD.csv');
SummaryCSVoutputFileName_VentrSize = fullfile(param.TopLevelResultsFolder, 'SummaryOutput_VentrSize.csv');
SummaryCSVoutputFileName_SharedBoundary = fullfile(param.TopLevelResultsFolder, 'SummaryOutput_SharedBoundary.csv');
SummaryCSVoutputFileName_BLR = fullfile(param.TopLevelResultsFolder, 'SummaryOutput_BoundaryLengthRatio.csv');
SummaryCSVoutputFileName_TMR = fullfile(param.TopLevelResultsFolder, 'SummaryOutput_TrabeculatedMassRatio.csv');

    timestamp = datetime('now','TimeZone','local','Format','yyyyMMddHHmmssSSSS');
if exist(SummaryCSVoutputFileName_FD, 'file') == 2
    SummaryCSVoutputBackupFileName = fullfile(param.TopLevelResultsFolder, sprintf('Backup-SummaryOutput_FD-%s.csv', timestamp));
    movefile(SummaryCSVoutputFileName_FD, SummaryCSVoutputBackupFileName);
end
if exist(SummaryCSVoutputFileName_VentrSize, 'file') == 2
    SummaryCSVoutputBackupFileName = fullfile(param.TopLevelResultsFolder, sprintf('Backup-SummaryOutput_VentrSize-%s.csv', timestamp));
    movefile(SummaryCSVoutputFileName_VentrSize, SummaryCSVoutputBackupFileName);
end
if exist(SummaryCSVoutputFileName_SharedBoundary, 'file') == 2
    SummaryCSVoutputBackupFileName = fullfile(param.TopLevelResultsFolder, sprintf('Backup-SummaryOutput_SharedBoundary-%s.csv', timestamp));
    movefile(SummaryCSVoutputFileName_SharedBoundary, SummaryCSVoutputBackupFileName);
end
if exist(SummaryCSVoutputFileName_BLR, 'file') == 2
    SummaryCSVoutputBackupFileName = fullfile(param.TopLevelResultsFolder, sprintf('Backup-SummaryOutput_BoundaryLengthRatio-%s.csv', timestamp));
    movefile(SummaryCSVoutputFileName_BLR, SummaryCSVoutputBackupFileName);
end

if exist(SummaryCSVoutputFileName_TMR, 'file') == 2
    SummaryCSVoutputBackupFileName = fullfile(param.TopLevelResultsFolder, sprintf('Backup-SummaryOutput_TrabeculatedMassRatio-%s.csv', timestamp));
    movefile(SummaryCSVoutputFileName_TMR, SummaryCSVoutputBackupFileName);
end


CSVfileHeader = [ 'Folder,', ...
           'Slice order,','Interpolation,', ...
           'Min. ventricle size (mm^2),','Image closure step size (mm),', ...
           'Original resolution / mm,','Output resolution / mm,', ...
           'Slice thickness / mm,','Slices present,', ...
           'Slice 1,','Slice 2,','Slice 3,','Slice 4,','Slice 5,', ...
           'Slice 6,','Slice 7,','Slice 8,','Slice 9,','Slice 10,', ...
           'Slice 11,','Slice 12,','Slice 13,','Slice 14,','Slice 15,', ...
           'Slice 16,','Slice 17,','Slice 18,','Slice 19,','Slice 20' ];
                 
    fid = fopen(SummaryCSVoutputFileName_FD, 'wt');
    fprintf(fid, '%s\n', CSVfileHeader);
  fclose(fid);

    fid = fopen(SummaryCSVoutputFileName_VentrSize, 'wt');
    fprintf(fid, '%s\n', CSVfileHeader);
  fclose(fid);

    fid = fopen(SummaryCSVoutputFileName_SharedBoundary, 'wt');
    fprintf(fid, '%s\n', CSVfileHeader);
  fclose(fid);

    fid = fopen(SummaryCSVoutputFileName_BLR, 'wt');
    fprintf(fid, '%s\n', CSVfileHeader);
  fclose(fid);

    fid = fopen(SummaryCSVoutputFileName_TMR, 'wt');
    fprintf(fid, '%s\n', CSVfileHeader);
  fclose(fid);

  Cmd=['for i in ' fullfile(param.TopLevelResultsFolder,'CSVoutput','Data-*.csv') ' ; do sed "1q;d" $i >> ' SummaryCSVoutputFileName_FD ';done'];
system(Cmd);

Cmd=['for i in ' fullfile(param.TopLevelResultsFolder,'CSVoutput','Data-*.csv') ' ; do sed "2q;d" $i >> ' SummaryCSVoutputFileName_VentrSize ';done'];
system(Cmd);

Cmd=['for i in ' fullfile(param.TopLevelResultsFolder,'CSVoutput','Data-*.csv') ' ; do sed "3q;d" $i >> ' SummaryCSVoutputFileName_SharedBoundary ';done'];
system(Cmd);

Cmd=['for i in ' fullfile(param.TopLevelResultsFolder,'CSVoutput','Data-*.csv') ' ; do sed "4q;d" $i >> ' SummaryCSVoutputFileName_BLR ';done'];
system(Cmd);

Cmd=['for i in ' fullfile(param.TopLevelResultsFolder,'CSVoutput','Data-*.csv') ' ; do sed "5q;d" $i >> ' SummaryCSVoutputFileName_TMR ';done'];
system(Cmd);

end