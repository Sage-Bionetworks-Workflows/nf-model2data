# nf-model2data
This is the nextflow workflow that runs model to data challenges.

```
nextflow pull Sage-Bionetworks-Challenges/nf-model2data
nextflow run Sage-Bionetworks-Challenges/nf-model2data
```

## Requirements
Must have a submission view created on the challenge project in Synapse. The view MUST INCLUDE the `status`, `dockerrepositoryname`, and `dockerdigest` columns.
