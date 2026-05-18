process SAMTOOLS_MAKE_REF_ALLELES_TSV{
    tag "${chrom}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c5d2818c8b9f58e1fba77ce219fdaf32087ae53e857c4a496402978af26e78c/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.23.1--5b6bb4ede7e612e5'}"


    input:
    val(reference)
    tuple val(chrom), path(tsv)
    

    output:
    tuple val(chrom), path ("${chrom}_pos_ref_alleles.tsv"), emit: ref_alleles

    script:
    """
    paste ${tsv} <(samtools faidx \\
        ${reference} \\
        -r <(awk '{print \$1":"\$2"-"\$2}' ${tsv}) \\
        | grep -v "^>") \\
    | awk 'BEGIN{OFS="\\t"}{print \$1"_"\$2,\$3}' \\
    > ${chrom}_pos_ref_alleles.tsv
    """
}
