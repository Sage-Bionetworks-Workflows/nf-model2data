
// Find your tower s3 bucket and upload your input files into it
// The tower space is PHI safe
nextflow.enable.dsl = 2

params.view_id = "syn51356905"
// params.input_dir = "${projectDir}/input"
params.cpus = "4"
params.memory = "16.GB"

params.input_folder = "syn51390589"

//downloads synapse folder given Synapse ID
process SYNAPSE_STAGE {

    container "sagebionetworks/synapsepythonclient:v2.7.0"
    
    secret 'SYNAPSE_AUTH_TOKEN'

    input:
    val input_folder

    output:
    path "**"

    script:
    """    
    synapse get -r --downloadLocation ./input ${input_folder}
    """
}

process GET_SUBMISSIONS {
    secret "SYNAPSE_AUTH_TOKEN"
    container "sagebionetworks/synapsepythonclient:v2.7.0"

    input:
    val view

    output:
    path "images.csv"

    script:
    """
    get_submissions.py '${view}'
    """
}

process RUN_DOCKER {
    secret "SYNAPSE_AUTH_TOKEN"
    cpus "${cpus}"
    memory "${memory}"
    container "ghcr.io/sage-bionetworks-workflows/nf-model2data/dind_image:1.0"
    

    input:
    tuple val(submission_id), val(container)
    path "/input/*"
    val cpus
    val memory

    output:
    val submission_id
    path 'predictions.csv'

    script:
    """
    echo \$SYNAPSE_AUTH_TOKEN | docker login docker.synapse.org --username foo --password-stdin
    docker run -v \$PWD/input:/input:ro -v \$PWD:/output:rw $container
    """
}

workflow {
    SYNAPSE_STAGE(params.input_folder)
    GET_SUBMISSIONS(params.view_id)
    image_ch = GET_SUBMISSIONS.output 
        .splitCsv(header:true) 
        .map { row -> tuple(row.submission_id, row.image_id) }
    RUN_DOCKER(image_ch, SYNAPSE_STAGE.output, params.cpus, params.memory)
}
