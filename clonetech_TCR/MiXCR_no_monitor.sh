#!/bin/bash

project_info=$1
wd=$2

###Project_info
Project_name=`cat ${project_info} | grep "^Project_name=" | cut -f 2 -d "="`
Sample_species=`cat ${project_info} | grep "^Sample_species=" | cut -f 2 -d "="`
Sample_source=`cat ${project_info} | grep "^Sample_source=" | cut -f 2 -d "="`
Sample_chain=`cat ${project_info} | grep "^Sample_chain" | cut -f 2 -d "="`
Sample_path=`cat ${project_info} | grep "^Sample_path" | cut -f 2 -d "="`
Result_path=${wd}/${Sample_source}/${Project_name}

###software
fastqc=/ehpcdata/sge_software/anaconda2/bin/fastqc
trimmomatic=/ehpcdata/sge_software/Trimmomatic/Trimmomatic-0.36/trimmomatic-0.36.jar
TruSeq3PE=/home/zuotianyu/database/reference/TruSeq3-PE-2.fa
cutadapt=/ehpcdata/sge_software/anaconda2/bin/cutadapt
mixcr=/home/zuotianyu/software/mixcr-2.1.12/mixcr

#mkdir for log record 不然sbatch会失败
mkdir -p ${Result_path}/log

for sample_id in `ls -l ${Sample_path} | awk '/^d/ {print $NF}' | cut -d '_' -f 2`;do
	seq1=${Sample_path}/Sample_${sample_id}/${sample_id}*_R1*gz
	seq2=${Sample_path}/Sample_${sample_id}/${sample_id}*_R2*gz
	if [ ! -f "${Sample_path}/Sample_${sample_id}/${sample_id}_combined_R1.fastq.gz" ];then
		mv ${seq1} ${Sample_path}/Sample_${sample_id}/${sample_id}_combined_R1.fastq.gz
		mv ${seq2} ${Sample_path}/Sample_${sample_id}/${sample_id}_combined_R2.fastq.gz
	fi        
	echo "#!/usr/bin/bash
echo `date +%Y-%m-%d-%H-%M-%S` ${sample_id} MiXCR processing started...

###fastqc
mkdir -p ${Result_path}/fastqc/${sample_id}
${fastqc} -o ${Result_path}/fastqc/${sample_id} ${Sample_path}/Sample_${sample_id}/${sample_id}_combined_R1.fastq.gz
${fastqc} -o ${Result_path}/fastqc/${sample_id} ${Sample_path}/Sample_${sample_id}/${sample_id}_combined_R2.fastq.gz

###trim adaptor
mkdir -p ${Result_path}/trim_data/${sample_id}
java -jar ${trimmomatic} PE -phred33 -threads 2 -trimlog ${Result_path}/trim_data/${sample_id}_trim.log \
${Sample_path}/Sample_${sample_id}/${sample_id}_combined_R1.fastq.gz ${Sample_path}/Sample_${sample_id}/${sample_id}_combined_R2.fastq.gz \
${Result_path}/trim_data/${sample_id}/${sample_id}_combined_R1.trim.fastq.gz ${Result_path}/trim_data/${sample_id}/${sample_id}_combined_R1.trim.unpaired.fastq.gz \
${Result_path}/trim_data/${sample_id}/${sample_id}_combined_R2.trim.fastq.gz ${Result_path}/trim_data/${sample_id}/${sample_id}_combined_R2.trim.unpaired.fastq.gz \
ILLUMINACLIP:${TruSeq3PE}:2:30:10:6:true MINLEN:75 > ${Result_path}/trim_data/${sample_id}/${sample_id}_adapter.stat 2>&1

###cutadapt
mkdir -p ${Result_path}/cutadapt_reads/${sample_id}
${cutadapt} -q 20 -o ${Result_path}/cutadapt_reads/${sample_id}/${sample_id}_combined_cut_R1.fastq.gz ${Result_path}/trim_data/${sample_id}/${sample_id}_combined_R1.trim.fastq.gz
${cutadapt} -q 20 -o ${Result_path}/cutadapt_reads/${sample_id}/${sample_id}_combined_cut_R2.fastq.gz ${Result_path}/trim_data/${sample_id}/${sample_id}_combined_R2.trim.fastq.gz

###align
mkdir -p ${Result_path}/align_result/${sample_id}
${mixcr} align --library imgt -s ${Sample_species} -r ${Result_path}/align_result/${sample_id}/alignmentReport.txt -c ${Sample_chain} -a -g -OjParameters.parameters.floatingRightBound=false -OvParameters.geneFeatureToAlign=VTranscript -OdParameters.geneFeatureToAlign=DRegion -OjParameters.geneFeatureToAlign=JRegion --not-aligned-R1 ${Result_path}/align_result/${sample_id}/not_aligned_R1.fastq --not-aligned-R2 ${Result_path}/align_result/${sample_id}/not_aligned_R2.fastq ${Result_path}/cutadapt_reads/${sample_id}/${sample_id}_combined_cut_R1.fastq.gz ${Result_path}/cutadapt_reads/${sample_id}/${sample_id}_combined_cut_R2.fastq.gz ${Result_path}/align_result/${sample_id}/alignments.vdjca
echo `date +%Y-%m-%d-%H-%M-%S` The align has been done!

###assemble
mkdir -p ${Result_path}/assemble_result/${sample_id}
${mixcr} assemble -r ${Result_path}/assemble_result/${sample_id}/assembleReport.txt -t 8 -OassemblingFeatures=CDR3 -OqualityAggregationType=Average -OaddReadsCountOnClustering=true --index ${Result_path}/assemble_result/${sample_id}/index_file ${Result_path}/align_result/${sample_id}/alignments.vdjca ${Result_path}/assemble_result/${sample_id}/clone.clns
echo `date +%Y-%m-%d-%H-%M-%S` The assemble has been done!

###exportAlign
${mixcr} exportAlignments -readID -vHits -vGene -dHits -dGene -jHits -jGene -cloneId ${Result_path}/assemble_result/${sample_id}/index_file ${Result_path}/align_result/${sample_id}/alignments.vdjca ${Result_path}/align_result/${sample_id}/alignmentsGene.txt
${mixcr} exportAlignments -readID -Sequence -quality -nFeature FR1 -nFeature CDR1 -nFeature FR2 -nFeature CDR2 -nFeature FR3 -nFeature CDR3 -nFeature FR4 -aaFeature FR1 -aaFeature CDR1 -aaFeature FR2 -aaFeature CDR2 -aaFeature FR3 -aaFeature CDR3 -aaFeatureFR4 ${Result_path}/align_result/${sample_id}/alignments.vdjca ${Result_path}/align_result/${sample_id}/alignmentsSequence.txt
${mixcr} exportAlignments -cloneId ${Result_path}/assemble_result/${sample_id}/index_file -descrR1 -descrR2 ${Result_path}/align_result/${sample_id}/alignments.vdjca ${Result_path}/align_result/${sample_id}/alignmentsDescr.txt
echo `date +%Y-%m-%d-%H-%M-%S` exportAlign has been done !

###exportAssemble
${mixcr} exportClones -o -t -cloneId -count -fraction -vHit -dHit -jHit -nFeature CDR3 -aaFeature CDR3 -readIds ${Result_path}/assemble_result/${sample_id}/index_file ${Result_path}/assemble_result/${sample_id}/clone.clns ${Result_path}/assemble_result/${sample_id}/clone.txt
${mixcr} exportClones -o -t ${Result_path}/assemble_result/${sample_id}/clone.clns ${Result_path}/assemble_result/${sample_id}/${sample_id}.txt
echo `date +%Y-%m-%d-%H-%M-%S` exportAssemble has been done !

echo `date +%Y-%m-%d-%H-%M-%S` ${sample_id} MiXCR processing ended...
" > ${wd}/${sample_id}.sh
        sbatch --output=${Result_path}/log/${sample_id}.out --error=${Result_path}/log/${sample_id}.err ${wd}/${sample_id}.sh
        sleep 3s

done;
