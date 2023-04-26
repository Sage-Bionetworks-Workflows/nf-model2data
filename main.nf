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

// change submission status to EVALUATION_IN_PROGRESS
process UPDATE_SUBMISSION_BEFORE_RUN {
    secret "SYNAPSE_AUTH_TOKEN"
    container "sagebionetworks/challengeutils:v4.2.0"

    input:
    tuple val(submission_id), val(container)

    output:
    tuple val(submission_id), val(container)

    script:
    """
    challengeutils change-status ${submission_id} EVALUATION_IN_PROGRESS
    """
}

// runs docker containers
process RUN_DOCKER {
    debug true
    secret "SYNAPSE_AUTH_TOKEN"
    cpus "${cpus}"
    memory "${memory}"
    container "ghcr.io/sage-bionetworks-workflows/nf-model2data/dind_image:1.0"
    

    input:
    tuple val(submission_id), val(container)
    path staged_path
    val cpus
    val memory

    output:
    tuple val(submission_id), path('predictions.csv')

    script:
    """
    echo \$SYNAPSE_AUTH_TOKEN | docker login docker.synapse.org --username foo --password-stdin
    docker run -v \$PWD/input:/input:ro -v \$PWD:/output:rw $container
    """
}

// change submission status to ACCEPTED

process UPDATE_SUBMISSION_AFTER_RUN {
    secret "SYNAPSE_AUTH_TOKEN"
    container "sagebionetworks/challengeutils:v4.2.0"

    input:
    tuple val(submission_id), val(output_path)

    output:
    tuple val(submission_id), val(output_path)

    script:
    """
    challengeutils change-status ${submission_id} ACCEPTED
    """
}

workflow {
    SYNAPSE_STAGE(params.input_id)
    staged_path = SYNAPSE_STAGE.output
    GET_SUBMISSIONS(params.view_id)
    image_ch = GET_SUBMISSIONS.output 
        .splitCsv(header:true) 
        .map { row -> tuple(row.submission_id, row.image_id) }
    UPDATE_SUBMISSION_BEFORE_RUN(image_ch)
    RUN_DOCKER(UPDATE_SUBMISSION_BEFORE_RUN.output, staged_path, params.cpus, params.memory)
    UPDATE_SUBMISSION_AFTER_RUN(RUN_DOCKER.output)
}
