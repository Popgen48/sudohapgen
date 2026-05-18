process PLINK2_RECODE {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::plink2=2.00a5.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a5.10--h449a9fb_0' :
        'biocontainers/plink2:2.00a5.10--h449a9fb_0' }"

    input:
    tuple val(meta), path(tped), path(tfam), path(ref_allele_tsv)

    output:
    tuple val(meta), path("*.vcf"), emit: vcf
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.chrom}"
    // Extract the base name of the tfile from the input files
    def input_base = tped.baseName
    """
    plink2 \\
        --tfile $input_base \\
        $args \\
        --ref-allele 'force' ${ref_allele_tsv} 2 1 \\
        --out $prefix


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version | sed 's/^PLINK v//;s/ 64-bit.*//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.chrom}"
    """
    touch ${prefix}.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version | sed 's/^PLINK v//;s/ 64-bit.*//')
    END_VERSIONS
    """
}
