// change submission status
process UPDATE_SUBMISSION_STATUS {
    secret "SYNAPSE_AUTH_TOKEN"
    container "sagebionetworks/challengeutils:v4.2.0"

    input:
    tuple val(submission_id), val(previous)
    val new_status

    output:
    tuple val(submission_id), val(previous)

    script:
    """
    challengeutils change-status ${submission_id} ${new_status}
    """
}
