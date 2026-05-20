/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SAMTOOLS_IDXSTATS      } from '../modules/local/samtools/idxstats/main'
include { SAMTOOLS_VIEW          } from '../modules/local/samtools/view/main'
include { SAMTOOLS_INDEX         } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_MAKE_REF_ALLELES_TSV } from '../modules/local/samtools/make_ref_alleles_tsv/main'
include { ANGSD_DOHAPLO          } from '../modules/local/angsd/dohaplo/main'
include { ANGSD_HAPLOTOPLINK     } from '../modules/local/angsd/haplotoplink/main'
include { PLINK2_RECODE          } from '../modules/local/plink2/recode/main'
include { PLINK2_MERGE_TPED_TFAM } from '../modules/local/plink2/merged_tped_tam/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_sudohapgen_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SUDOHAPGEN {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()


    if(!params.include_chroms){
        //
        // MODULE : SAMTOOLS_IDXSTATS
        //

            SAMTOOLS_IDXSTATS(
                ch_samplesheet.take(1)
            )

        chrom_text_file = SAMTOOLS_IDXSTATS.out.text.map{meta,txt -> txt}

    }

    else{
            chrom_text_file = channel.fromPath(params.include_chroms)
        }

    chrom_names_ch = chrom_text_file
        .splitText()
        .map { it.trim() }

    ch_samtools_view = ch_samplesheet.combine(chrom_names_ch)
    
    //
    // MODULE: SAMTOOLS_VIEW
    //
    SAMTOOLS_VIEW(
        ch_samtools_view,
        [[],[],[]],
        [[],[]],
        [[],[]],
        []
    )

    //
    // MODULE: SAMTOOLS_INDEX
    //
    SAMTOOLS_INDEX(
        SAMTOOLS_VIEW.out.bam
    )

    ch_meta_bam_idx = SAMTOOLS_VIEW.out.bam.combine(SAMTOOLS_INDEX.out.index,by:0)

    sites_file = channel.fromPath(params.sites_file)

    ch_meta_filepath = sites_file.splitCsv(header: true)
    .map { row -> 
        // We return a tuple where the first element is the join key (chrom)
        return [ row.chrom, row.file_path ] 
    }

    ch_chrom_meta_bam_bai = ch_meta_bam_idx.map{meta,bam,idx->tuple(meta.chrom,meta,bam,idx)}

    ch_angsd_dohaplo = ch_chrom_meta_bam_bai.join(ch_meta_filepath).map{chrom,meta,bam,idx,sites_f -> tuple(meta,bam,idx,sites_f)}

    //
    // MODULE: ANGSD_DOHAPLO
    //
    ANGSD_DOHAPLO(
        ch_angsd_dohaplo.map { meta, bam, idx, sites_f ->
            def sites_dir = file(sites_f).parent
            tuple(meta, bam, idx, sites_f, sites_dir, [])
            }
    )

    //
    // MODULE: ANGSD_HAPLOTOPLINK
    //
    ANGSD_HAPLOTOPLINK(
        ANGSD_DOHAPLO.out.haplo
    )
    
    ch_tped_tfam = ANGSD_HAPLOTOPLINK.out.tped.join(ANGSD_HAPLOTOPLINK.out.tfam).map{meta, tped, tfam-> tuple(meta.chrom, meta.id,tped,tfam)}





    //ch_plink2_recode = ANGSD_HAPLOTOPLINK.out.plink_files.map{meta,files->tuple(meta,files[0],files[1])}

    if(params.ref_fasta){

            ref_fasta = Channel.fromPath(params.ref_fasta, checkIfExists: true)

            SAMTOOLS_MAKE_REF_ALLELES_TSV(
                ch_meta_filepath.combine(ref_fasta)
            )

            ch_plink2_recode = SAMTOOLS_MAKE_REF_ALLELES_TSV.out.ref_alleles.combine(ch_tped_tfam,by:0)
            ch_plink2_recode = ch_plink2_recode.map{chrm,tsv,prefix,tped,tfam->tuple([id:prefix,chrom:chrm],tped,tfam,tsv)}
            
        }

    PLINK2_RECODE(
        ch_plink2_recode
    )


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'sudohapgen_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
