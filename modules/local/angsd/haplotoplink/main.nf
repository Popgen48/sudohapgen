process ANGSD_HAPLOTOPLINK{
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/angsd:0.940--hce60e53_2':
        'biocontainers/angsd:0.940--hce60e53_2' }"

    input:
    // This expects the .haplo.gz file
    tuple val(meta), path (haplo_gz)

    output:
    // Plink typically outputs .ped and .map, or .bed, .bim, .fam
    // Adjust the glob pattern if angsd outputs something different
    tuple val(meta), path ("${haplo_gz.baseName}.*") , emit: plink_files

    script:
    // Define a convenience variable for the prefix
    def prefix = haplo_gz.baseName.replace(".haplo.gz", "")
    sample = "$meta.id"
    """
    # Run the angsd utility
    # We use the prefix derived from the input file
    haploToPlink ${haplo_gz} ${prefix}

    awk 'BEGIN{OFS="\t"}{print "${sample}","${sample}",0,0,0,0}' ${prefix}.tfam > ${prefix}.modi.tfam

    mv ${prefix}.modi.tfam ${prefix}.tfam

    """
}
