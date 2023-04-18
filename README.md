# nf-model2data
This is the nextflow workflow that runs model to data challenges.

## Prerequisites

In order to use this workflow, you must already have completed the following steps:

1. Created a Synapse project shared with challenge participants.
2. Created an evaluation queue within the Synapse project.
3. One or more Docker containers must have already been submitted to your evaluation queue.
4. Created a submission view that at least includes the `id`, `status`, `dockerrepositoryname`, and `dockerdigest` columns.

## Running the workflow

The workflow takes several inputs. They are:

1. `view_id` (required): The Synapse ID for your submission view.
2. `input_dir` (required): The directory holding the testing data for submissions. Defaults to `${projectDir}/input`
3. `cpus` (optional): Number of CPUs to dedicate to the `RUN_DOCKER` process i.e. the challenge executions. Defaults to `4`
4. `memory` (optional): Amount of memory to dedicate to the `RUN_DOCKER` process i.e. the challenge executions. Defaults to `16.GB`

Run the workflow locally:
```
nextflow run main.nf --view_id "<your_view_id>"
```

### Profiles

The workflow comes with two preconfigured `profiles` for memory and CPU allocation. The `local` profile is equivilent to the default (`cpus` = `4`; `memory` = `16.GB`) this is intended to be used for runs on local machines with adequate resources. The `tower` profile dedicates double the resources (`cpus` = `8`; `memory` = `32.GB`) and can be used when running the workflow on Nextflow Tower for improved performance. 
