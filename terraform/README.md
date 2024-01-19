# Clean Up

## Prerequisites

In order to be deleted, the Github Cloudbuild connection must have no linked repositories.
Delete all instances of apps running in the web app first or else, you will have to manually delete all connections probably from the GCP console.

## Destroying Project Resources

Due to limitations of Terraform and the GCP API, some resources will need to untracked before running `terrafrom destroy`.

Thus, the recommended method to destory project resources is by running:

```
bash gcp-destroy.sh
```

Note, this only destroys the resources initially created by `terrafrom apply`. Thus, the project resources created during the initial setup will remain (i.e. does not undo `bash gcp-setup.sh`).
