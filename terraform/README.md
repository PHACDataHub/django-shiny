## Clean Up - Destroying Project Resources

Due to limitations of Terrafrom and the GCP API, some resources will need to untracked before running `terrafrom destroy`.

Thus, the recommended method to destory project resources is by running:

```
bash gcp-destroy.sh
```

Note, this only destroys the resources initially created by `terrafrom apply`. Thus, the project resources created during the initial setup will remain (i.e. does not undo `bash gcp-setup.sh`).
