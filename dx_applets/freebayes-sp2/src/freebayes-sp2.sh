#!/bin/bash
# freebayes-sp2 0.0.1
# Generated by dx-app-wizard.

set -x -e -o pipefail

main() {

    sudo chmod 777 /usr/bin/samtools
    sudo chmod 777 /usr/bin/freebayes
    sudo chmod 777 /usr/bin/bcftools
	
    echo "Value of reference: '$REF'"
    echo "Value of bam: '$BAM'"
    echo "Value of max: '$MAX'"
    
    ref_name=$REF_name
    ref_prefix=$REF_prefix

    dx download "$REF" -o ${ref_name}

    gunzip ${ref_name}

    dx download "$BAM" -o aln.bam
    dx download "$BAI" -o aln.bam.bai

    if ! [ -e ${ref_name%.gz}.fai ]; then
        samtools faidx ${ref_name%.gz}
        awk '{print $1 "\t" $2}' ${ref_name%.gz}.fai > ${ref_name%.gz}.len
    fi

	if ! [ -e ${ref_name}.gaps ]; then
		java -jar /opt/java/fastaGetGaps.jar ${ref_name%.gz} ${ref_name%.gz}.gaps
		awk -F "\t" '$4>3 {print $1"\t"$2"\t"$3}' ${ref_name%.gz}.gaps > ${ref_name%.gz}.gaps.bed
		bedtools complement -i ${ref_name%.gz}.gaps.bed -g ${ref_name%.gz}.len | awk '{print $0"\t"($3-$2)}' > ${ref_name%.gz}.bed
		sort -k4 -nr ${ref_name%.gz}.bed > contigs_sorted.bed
		
	fi

    if ! [ -e vcf ]; then
    	mkdir vcf
        cat contigs_sorted.bed | awk -v bam=aln.bam -v ref=${ref_name%.gz} -v max=$MAX '{print "freebayes --bam "bam" --region \""$1":"$2"-"$3"\" --fasta-reference "ref"  --max-coverage "max" --vcf \"vcf/"$1"_"$2"-"$3".vcf\""}' | parallel --gnu -j $(nproc) -k
    fi

	cat ${ref_name%.gz}.bed | awk '{print "vcf/"$1"_"$2"-"$3".vcf"}' > concat_list.txt
	bcftools concat -f concat_list.txt | bcftools view -Ou -e'type="ref"' | bcftools norm -Ob -f ${ref_name%.gz} -o ${ref_prefix}.bcf --threads $(nproc)
	bcftools index ${ref_prefix}.bcf
	
    pl_bcf=$(dx upload ${ref_prefix}.bcf --brief)
    dx-jobutil-add-output pl_bcf "$pl_bcf" --class=file

	bcftools view -i 'QUAL>1 && (GT="AA" || GT="Aa")' -Oz --threads=$(nproc) ${ref_prefix}.bcf > ${ref_prefix}_changes.vcf.gz
    pl_vcf_changes=$(dx upload ${ref_prefix}_changes.vcf.gz --brief)
    dx-jobutil-add-output pl_vcf_changes "$pl_vcf_changes" --class=file

	bcftools index ${ref_prefix}_changes.vcf.gz
	bcftools consensus -Hla -f ${ref_name%.gz} ${ref_prefix}_changes.vcf.gz > ${ref_prefix}_pl.fa
	gzip ${ref_prefix}_pl.fa
	
    pl_fasta=$(dx upload ${ref_prefix}_pl.fa.gz --brief)
    dx-jobutil-add-output pl_fasta "$pl_fasta" --class=file
 	
}
