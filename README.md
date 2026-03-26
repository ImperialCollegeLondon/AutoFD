# AutoFDv2
Matlab code for automated end-diastolic/end-systolic, left/right ventricle fractal analysis.

Derived from [UK-Digital-Heart-Project/AutoFD Version 2.0](https://doi.org/10.5281/zenodo.1228962).

## Method
Please see the following manuscript for further information:

## Installation and Usage
Clone this repo locally on your CPU-strong computational server and follow the comments in the *main.m* file.

All the source data needs to be in one folder with sub-folders for each subject containing:

- Grayscale short axis image data, e.g., *sa.nii.gz*
- Segmentation matching the image data in dimension and position, e.g., *seg_sa.nii.gz*
- - The segmentation labels need to be:
- - - Background  = 0
- - - Left Ventricle  = 1
- - - Myocardium  = 2
- - - Right Ventricle = 3 or 4

## Outputs
Outputs are written to a results folder defined in the *main.m* file.

- ImageOutput-Folder: contains one image per subject showing the segmented and anlysed contours
- MatOutput-Folder: contains one mat-file per subject with the interpolated ventricle segment and trabeculae
- CSVoutput-Folder: contains one csv-file per subject with the numerical values
- ErrorOutput-Folder: contains one error.log file per subject, if there are any problems detected during running the code
- SummaryOutput-csv files: contain numerical values of all files in the CSVoutput-Folder for
- - The Fractal Dimension (FD)
- - Shared Boundary
- - Ventricle Size
- - Trabeculated Mass Ratio (TMR) and
- - Boundary Length Ratio (BLR)

## Citation
If you find this software useful for your project or research. Please give some credits to authors who developed it by citing some of the following papers. We really appreciate that.
Jan Sedlacik, Kathryn A. McGurk, Paweł F. Tokarczuk, Ben Statton, Alaine Berry, Massimo Marenzana, Declan P. O’Regan. Quantitative ventricular trabeculation assessment in cardiac MRI: optimised blood-pool segmentation, box-counting fractal analysis and non-fractal measurements. International Journal of Cardiovascular Imaging, 2026. https://doi.org/10.1007/s10554-026-03687-9