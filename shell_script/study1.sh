cd ../
wd=`pwd`
if [ ! -d "/native/$USER" ];then
   mkdir /native/$USER
fi

rsync -hltr  Sample_${prefix}/*fastq.gz /native/$USER/Sample_${prefix}_skewer/
cd /native/$USER/Sample_${prefix}_skewer


${skewer} \
-x AGATCGGAAGAGC \
-y AGATCGGAAGAGC \
-m pe -r 0.1 -d 0.03 -q 20 -Q 20 -l 20 -n -o ${prefix} -f sanger --quiet -X -t 8 ${prefix}_R1.fastq.gz ${prefix}_R2.fastq.gz
mv ${prefix}-trimmed-pair1.fastq ${prefix}_R1.trimmed.fastq
mv ${prefix}-trimmed-pair2.fastq ${prefix}_R2.trimmed.fastq
${pigz} -6 -p 8 ${prefix}_R1.trimmed.fastq
${pigz} -6 -p 8 ${prefix}_R2.trimmed.fastq

mv ${prefix}-untrimmed-excluded-pair1.fastq ${prefix}_R1.dropped.fastq
mv ${prefix}-untrimmed-excluded-pair2.fastq ${prefix}_R2.dropped.fastq
${pigz} -6 -p 8 ${prefix}_R1.dropped.fastq
${pigz} -6 -p 8 ${prefix}_R2.dropped.fastq

rsync -hltr  /native/$USER/Sample_${prefix}_skewer/* $wd/Sample_${prefix}/
rm  -rf /native/$USER/Sample_${prefix}_skewer



