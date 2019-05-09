#!/bin/bash
# asm-stats 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See https://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.
set -x -e -o pipefail

main() {

    echo "Value of asm: '$asm'"
    echo "Value of gsize: '$gsize'"
    echo "Value of mode: '$mode'"

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    dx download "$asm" -o asm.fasta.gz
    gunzip asm.fasta.gz
	
	java -jar -Xmx1g /opt/java/fastaContigSize.jar asm.fasta
    
    printf "Scaffolds\n" > asm_stats.txt
    
    java -jar -Xmx1g /opt/java/lenCalcNGStats.jar asm.fasta.len $gsize >> asm_stats.txt
    
    if [[ "$mode" == "c" ]]; then

    	asm_stats=$(dx upload asm_stats.txt --brief)
    
    	dx-jobutil-add-output asm_stats "$asm_stats" --class=file

		exit 0
	fi
	
	N_BASES=`awk '{sum+=$2; sumN+=$3} END {print (sum-sumN)}' asm.fasta.len`
	echo "N bases: $N_BASES"
	
	java -jar -Xmx2g /opt/java/fastaGetGaps.jar asm.fasta asm.gaps.txt
	
	awk -F "\t" '$4>3 {print $1"\t"$2"\t"$3}' asm.gaps.txt > asm.gaps.bed
	
	awk '{print $1"\t0\t"$(NF-1)}' asm.fasta.len > fasta.len.bed
	
	bedtools subtract -a fasta.len.bed -b asm.gaps.bed | awk '{print $1"\t"$NF-$(NF-1)}' > asm.contigs.len
	
	java -jar -Xmx1g /opt/java/lenCalcNGStats.jar asm.contigs.len $gsize 1 > asm.contigs.stats

    printf "\nContigs\n" >> asm_stats.txt	
	cat asm.contigs.stats >> asm_stats.txt

	java -jar -Xmx1g /opt/java/lenCalcNGStats.jar asm.gaps.txt $gsize 3 > asm.gaps.stats

    printf "\nGaps\n" >> asm_stats.txt	
	cat asm.gaps.stats >> asm_stats.txt	

    if [[ "$mode" != "p" ]]; then

    	asm_stats=$(dx upload asm_stats.txt --brief)
    
    	dx-jobutil-add-output asm_stats "$asm_stats" --class=file

		exit 0
	fi

	printf "\n=== Primary Stats ===\n" >> asm_stats.txt
	grep "scaffold_" fasta.len > asm.p.len
	java -jar -Xmx1g /opt/java/lenCalcNGStats.jar asm.p.len $gsize > asm.p.stats

	printf "\nScaffolds\n" >> asm_stats.txt
	cat $asm.p.stats >> asm_stats.txt	

	grep "scaffold_" asm.contigs.len > asm.contigs.p.len
	java -jar -Xmx1g /opt/java/lenCalcNGStats.jar asm.contigs.p.len $gsize 1 > asm.contigs.p.stats
	printf "\nContigs\n" >> asm_stats.txt
	cat $asm.contigs.p.stats >> asm_stats.txt

	grep "scaffold_" asm.gaps > asm.gaps.p
	java -jar -Xmx1g /opt/java/lenCalcNGStats.jar asm.gaps.p $gsize 3 > asm.gaps.p.stats
	printf "\nGaps\n" >> asm_stats.txt
	cat $asm.gaps.p.stats >> asm_stats.txt	

	printf "\nExtract primary set\n" >> asm_stats.txt 
	cut -f1 asm.p.len > asm.p.list
	java -jar -Xmx1g /opt/java/fastaExtractFromList.jar asm.fasta asm.p.list asm.p.fasta

	printf "\n=== Alt Stats ===\n" >> asm_stats.txt 
	grep -v "scaffold_" fasta.len > asm.h.len
	java -jar -Xmx1g $script/lenCalcNGStats.jar asm.h.len $gsize > asm.h.stats
	cat $asm.h.stats >> asm_stats.txt	


}
