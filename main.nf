// Find your tower s3 bucket and upload your input files into it
// The tower space is PHI safe
nextflow.enable.dsl = 2

// Synapse ID for Submission View
params.view_id = "syn51356905"
// Synapse ID for Input Data folder
params.input_id = "syn51390589"
// CPUs to dedicate to RUN_DOCKER
params.cpus = "4"
// Memory to dedicate to RUN_DOCKER
params.memory = "16.GB"


// downloads synapse folder given Synapse ID and stages to /input
process SYNAPSE_STAGE {

    container "sagebionetworks/synapsepythonclient:v2.7.0"
    
    secret 'SYNAPSE_AUTH_TOKEN'

    input:
    val input_id

    output:
    path "input/"

    script:
    """    
    synapse get -r --downloadLocation \$PWD/input ${input_id}
    """
}

// Gets submissions from view
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

// runs docker containers
process RUN_DOCKER {
    secret "SYNAPSE_AUTH_TOKEN"
    cpus "${cpus}"
    memory "${memory}"
    container "ghcr.io/sage-bionetworks-workflows/nf-model2data:latest"
    

    input:
    tuple val(submission_id), val(container)
    path staged_path
    val cpus
    val memory
    val ready

    output:
    tuple val(submission_id), path('predictions.csv')

    script:
    """
    echo \$SYNAPSE_AUTH_TOKEN | docker login docker.synapse.org --username foo --password-stdin
    docker run -v \$PWD/input:/input:ro -v \$PWD:/output:rw $container
    """
}

// import modules
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_BEFORE_RUN } from './modules/update_submission_status.nf'
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_AFTER_RUN } from './modules/update_submission_status.nf'
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_AFTER_VALIDATE } from './modules/update_submission_status.nf'
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_AFTER_SCORE } from './modules/update_submission_status.nf'
include { VALIDATE } from './modules/validate.nf'
include { SCORE } from './modules/score.nf'

workflow {
    SYNAPSE_STAGE(params.input_id)
    staged_path = SYNAPSE_STAGE.output
    GET_SUBMISSIONS(params.view_id)
    image_ch = GET_SUBMISSIONS.output 
        .splitCsv(header:true) 
        .map { row -> tuple(row.submission_id, row.image_id) }
    UPDATE_SUBMISSION_STATUS_BEFORE_RUN(image_ch.map { tuple(it[0], "EVALUATION_IN_PROGRESS") }, "ready")
    RUN_DOCKER(image_ch, staged_path, params.cpus, params.memory, UPDATE_SUBMISSION_STATUS_BEFORE_RUN.output)
    UPDATE_SUBMISSION_STATUS_AFTER_RUN(RUN_DOCKER.output.map { tuple(it[0], "ACCEPTED") }, UPDATE_SUBMISSION_STATUS_BEFORE_RUN.output)
    VALIDATE(RUN_DOCKER.output)
    UPDATE_SUBMISSION_STATUS_AFTER_VALIDATE(VALIDATE.output.map { tuple(it[0], it[2]) }, UPDATE_SUBMISSION_STATUS_AFTER_RUN.output)
    SCORE(VALIDATE.output)
    UPDATE_SUBMISSION_STATUS_AFTER_SCORE(SCORE.output.map { tuple(it[0], it[2]) }, UPDATE_SUBMISSION_STATUS_AFTER_VALIDATE.output)
}
