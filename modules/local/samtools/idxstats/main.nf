process SAMTOOLS_IDXSTATS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c5d2818c8b9f58e1fba77ce219fdaf32087ae53e857c4a496402978af26e78c/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.23.1--5b6bb4ede7e612e5'}"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("chrom_list.txt"), emit: text
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), emit: versions_samtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Get chromosome names (first column of idxstats)
    # Exclude the '*' unmapped placeholder
    samtools idxstats --threads ${task.cpus - 1 } ${bam} | cut -f 1 | grep -v '*' > chrom_list.txt

    # Loop through the list and create individual files
    while read chrom; do
        echo "\$chrom" > "\${chrom}.txt"
    done < chrom_list.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch chrom_list.txt
    """
}
