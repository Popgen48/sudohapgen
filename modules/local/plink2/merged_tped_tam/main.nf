process PLINK2_MERGE_TPED_TFAM{
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::plink2=2.00a5.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a5.10--h449a9fb_0' :
        'biocontainers/plink2:2.00a5.10--h449a9fb_0' }"

    input:
    tuple val(meta), path(tped_files), path(tfam_files)

    output:
    tuple val(meta), path("${prefix}.tped"), path("${prefix}.tfam"), emit: merged

    script:
    prefix = "${meta.id}"
    """
    set -euo pipefail

    # Get chromosome prefixes
    ls *.tped | sed 's/.tped\$//' | sort -V > prefixes.txt

    # First chromosome used as base
    first=\$(head -n 1 prefixes.txt)

    # Remaining chromosomes go into merge list
    tail -n +2 prefixes.txt | \
        awk '{print \$1".tped", \$1".tfam"}' \
        > merge_list.txt

    plink2 \\
        --tfile "\$first" \\
        --pmerge-list merge_list.txt \\
        --recode transpose \\
        --out ${prefix}
    """

    stub:
    """
    touch ${prefix}.tped
    touch ${prefix}.tfam
    """
}
