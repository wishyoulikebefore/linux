#!/bin/bash

### generate metadata
mixcr_data=$1
metadata=${mixcr_data}/metadata.txt

printf "file_name\tsample_id\n" >> $metadata

for sample_id  in `ls -l ${mixcr_data}/assemble_result | awk '/^d/ {print $NF}'`;do
        printf "%s\t%s\n" ${mixcr_data}/assemble_result/${sample_id}/${sample_id}.txt ${sample_id} >> $metadata
done;

### convert MiXcr type to VDJ type
convert_dir=${mixcr_data}/convert
vdjtools=/home/zuotianyu/software/vdjtools-1.1.10/vdjtools-1.1.10.jar

cd ${mixcr_data}

java -jar -Xmx20G ${vdjtools} Convert -S MiXcr -m ${metadata} convert/
rm $metadata

### vdjtools analysis
result_path=${mixcr_data}/clone_data
mkdir -p ${result_path}
clone_data=${result_path}

echo 'date +%Y-%m-%d-%H-%M-%S' started

mkdir -p 1_Basic
mkdir -p 2_Diversity
mkdir -p 3_Overlap
mkdir -p 4_Preprocessing
mkdir -p 5_OperateClonotype
mkdir -p 6_Annotation

for sample_id  in `ls -l ${mixcr_data}/assemble_result | awk '/^d/ {print $NF}'`;do
        echo ${sample_id}

###Basic analysis,Generate summary tables
        java -jar -Xmx20G $vdjtools PlotFancySpectratype ${convert_dir}/${sample_id}.txt 1_Basic/PlotFancySpectratype/${sample_id}
        java -jar -Xmx20G $vdjtools PlotSpectratypeV ${convert_dir}/${sample_id}.txt 1_Basic/PlotSpectratypeV/${sample_id}
        java -jar -Xmx20G $vdjtools PlotSpectratypeV -u ${convert_dir}/${sample_id}.txt 1_Basic/PlotSpectratypeV_unweighted/${sample_id}
        java -jar -Xmx20G $vdjtools PlotFancyVJUsage ${convert_dir}/${sample_id}.txt 1_Basic/PlotFancyVJUsage/${sample_id}
        java -jar -Xmx20G $vdjtools PlotFancyVJUsage -u ${convert_dir}/${sample_id}.txt 1_Basic/PlotFancyVJUsage_unweighted/${sample_id}

### Diversity estimation
        java -jar -Xmx20G $vdjtools PlotQuantileStats ${convert_dir}/${sample_id}.txt 2_Diversity/PlotQuantileStats/${sample_id}
done;

###Basic analysis,Generate summary tables
java -jar -Xmx20G $vdjtools CalcBasicStats -m ${convert_dir}/metadata.txt 1_Basic/CalcBasicStats/
java -jar -Xmx20G $vdjtools CalcBasicStats -u -m ${convert_dir}/metadata.txt 1_Basic/CalcBasicStats_unweighted/
java -jar -Xmx20G $vdjtools CalcSegmentUsage -p -m ${convert_dir}/metadata.txt 1_Basic/CalcSegmentUsage/
java -jar -Xmx20G $vdjtools CalcSegmentUsage -u -p -m ${convert_dir}/metadata.txt 1_Basic/CalcSegmentUsage_unweighted/
java -jar -Xmx20G $vdjtools CalcSegmentUsage -f cell -p -m ${convert_dir}/metadata.txt 1_Basic/CalcSegmentUsage/
java -jar -Xmx20G $vdjtools CalcSegmentUsage -l cell -p -m ${convert_dir}/metadata.txt 1_Basic/CalcSegmentUsage_2/
java -jar -Xmx20G $vdjtools CalcSpectratype -m ${convert_dir}/metadata.txt 1_Basic/CalcSpectratype/
java -jar -Xmx20G $vdjtools CalcSpectratype -u -m ${convert_dir}/metadata.txt 1_Basic/CalcSpectratype_unweighted/
java -jar -Xmx20G $vdjtools CalcSpectratype -a -m ${convert_dir}/metadata.txt 1_Basic/CalcSpectratype_aa/               #-a使用CDR3氨基酸序列而非碱基序列

### Diversity estimation
java -jar -Xmx20G $vdjtools RarefactionPlot -m ${convert_dir}/metadata.txt -l sample_id -f cell 2_Diversity/RarefactionPlot/
java -jar -Xmx20G $vdjtools RarefactionPlot -m ${convert_dir}/metadata.txt -f sample_id -l cell 2_Diversity/RarefactionPlot_2/
java -jar -Xmx20G $vdjtools CalcDiversityStats -m ${convert_dir}/metadata.txt 2_Diversity/CalcDiversityStats/


# Sample overlapping   这个地方需要改写（配对分析）
#java -jar -Xmx20G $vdjtools OverlapPair -p ${clone_data}/174-i5a.txt ${clone_data}/175-i5a.txt 3_Overlap/10.174-175-i5a
java -jar -Xmx20G $vdjtools CalcPairwiseDistances -m ${convert_dir}/metadata.txt 3_Overlap/CalcPairwiseDistances/
java -jar -Xmx20G $vdjtools ClusterSamples -p -f cell -l sample_id 3_Overlap/11 3_Overlap/ClusterSamples/
java -jar -Xmx20G $vdjtools ClusterSamples -f cell -l sample_id 3_Overlap/11 3_Overlap/ClusterSamples_2/
java -jar -Xmx20G $vdjtools ClusterSamples -p -e -f cell -l sample_id 3_Overlap/11 3_Overlap/ClusterSamples_3/
java -jar -Xmx20G $vdjtools ClusterSamples -p -l cell -f sample_id 3_Overlap/11 3_Overlap/ClusterSamples_4/
java -jar -Xmx20G $vdjtools TestClusters 3_Overlap/12.1 3_Overlap/TestClusters/
java -jar -Xmx20G $vdjtools TestClusters -e 3_Overlap/12.1 3_Overlap/TestClusters_2/
java -jar -Xmx20G $vdjtools TrackClonotypes -p -m ${convert_dir}/metadata.txt 3_Overlap/TrackClonotypes/
java -jar -Xmx20G $vdjtools TrackClonotypes -f cell -p -m ${convert_dir}/metadata.txt 3_Overlap/TrackClonotypes_2/


# Pre-processing
java -jar -Xmx20G $vdjtools Correct -m ${convert_dir}/metadata.txt 4_Preprocessing/15/
java -jar -Xmx20G $vdjtools Decontaminate -c -m ${convert_dir}/metadata.txt 4_Preprocessing/16/
java -jar -Xmx20G $vdjtools Downsample -m ${convert_dir}/metadata.txt -c -x 10000 4_Preprocessing/17/
java -jar -Xmx20G $vdjtools FilterNonFunctional -m ${convert_dir}/metadata.txt -c 4_Preprocessing/18/
java -jar -Xmx20G $vdjtools SelectTop -m ${convert_dir}/metadata.txt -x 20 4_Preprocessing/19/
java -jar -Xmx20G $vdjtools FilterByFrequency -m ${convert_dir}/metadata.txt 4_Preprocessing/20/
java -jar -Xmx20G $vdjtools ApplySampleAsFilter -m ${convert_dir}/metadata.txt 4_Preprocessing/21/
java -jar -Xmx20G $vdjtools FilterBySegment -v v1 -m ${convert_dir}/metadata.txt 4_Preprocessing/22/


###Operate on clonotype tables
java -jar -Xmx20G $vdjtools JoinSamples -p -m ${convert_dir}/metadata.txt 5_OperateClonotype/JoinSamples/
java -jar -Xmx20G $vdjtools PoolSamples -m ${convert_dir}/metadata.txt 5_OperateClonotype/PoolSamples/


# Annotate each clonotype in each sample with insert size, total CDR3 hydrophobicity and other basic and amino acid properties
java -jar -Xmx20G $vdjtools CalcDegreeStats -m ${convert_dir}/metadata.txt 6_Annotation/CalcDegreeStats/
java -jar -Xmx20G $vdjtools CalcCdrAAProfile -m ${convert_dir}/metadata.txt 6_Annotation/CalcCdrAAProfile/
java -jar -Xmx20G $vdjtools Annotate -m ${convert_dir}/metadata.txt 6_Annotation/Annotate/
java -jar -Xmx20G $vdjtools ScanDatabase -m ${convert_dir}/metadata.txt 6_Annotation/ScanDatabase/


echo 'Job has been done!'
echo $(date +%Y-%m-%d-%H-%M-%S)
