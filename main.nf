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

// import modules
include { SYNAPSE_STAGE } from './modules/synapse_stage.nf'
include { GET_SUBMISSIONS } from './modules/get_submissions.nf'
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_BEFORE_RUN } from './modules/update_submission_status.nf'
include { RUN_DOCKER } from './modules/run_docker.nf'
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_AFTER_RUN } from './modules/update_submission_status.nf'
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_AFTER_VALIDATE } from './modules/update_submission_status.nf'
include { UPDATE_SUBMISSION_STATUS as UPDATE_SUBMISSION_STATUS_AFTER_SCORE } from './modules/update_submission_status.nf'
include { VALIDATE } from './modules/validate.nf'
include { SCORE } from './modules/score.nf'
include { ANNOTATE_SUBMISSION } from './modules/annotate_submission.nf'

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
    ANNOTATE_SUBMISSION(SCORE.output)
}
