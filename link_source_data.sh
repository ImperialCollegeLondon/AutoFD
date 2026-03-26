# create local links to match Auto FD Analysis file names

basedir=/local_disk/AutoFDv2/Sources
mkdir -p $basedir
cd $basedir

for cardphs in ED ES;do
if [ ! -d $cardphs ]; then
  mkdir $cardphs 
fi

for j in /remote_folder/study_data/*;do
  subjdir=$(basename $j)
  if [ ! -d $basedir/$cardphs/$subjdir ]; then
  mkdir $basedir/$cardphs/$subjdir
  ln -s $j/lvsa_"$cardphs".nii.gz $basedir/$cardphs/$subjdir/sa.nii.gz
  ln -s $j/seg_lvsa_SR_"$cardphs".nii.gz $basedir/$cardphs/$subjdir/seg_sa.nii.gz
  #break # uncomment to link only a few test subjects
  fi
done

echo linking $cardphs Done!
done
