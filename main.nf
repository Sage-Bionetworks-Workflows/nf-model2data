
// Find your tower s3 bucket and upload your input files into it
// The tower space is PHI safe
nextflow.enable.dsl = 2

params.view_id = "syn51356905"
params.input_dir = "${projectDir}/input"
params.cpus = "4"
params.memory = "16"

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
    debug true
    secret "SYNAPSE_AUTH_TOKEN"
    cpus "${cpus}"
    memory "${memory}"
    container "ghcr.io/sage-bionetworks-workflows/nf-model2data/dind_image:1.0"
    

    input:
    val container
    val input
    val cpus
    val memory

    output:
    path 'predictions.csv'

    script:
    """
    echo \$SYNAPSE_AUTH_TOKEN | docker login docker.synapse.org --username foo --password-stdin
    docker run -v $input:/input:ro -v  \$PWD:/output:rw $container
    """
}

workflow {
    // "s3://genie-bpc-project-tower-bucket/**"
    // How to log into private docker registry on nextflow tower
    // Need to figure out how to add this as a channel
    // input_files = Channel.fromPath("$params.input", type: 'dir')
    // input_files = params.input
    // docker_images = Channel.fromList(input_docker_list)
    GET_SUBMISSIONS(params.view_id)
    image_ch = GET_SUBMISSIONS.output 
        .splitCsv(header:true) 
        .map { it.dockerimage }
    RUN_DOCKER(image_ch, params.input_dir, params.cpus, params.memory)
}
