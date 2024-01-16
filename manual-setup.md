# Manual steps (can't be scripted or easier not to)

* In cloud build, set up a 2nd gen connection to GitHub. Every Shiny app repo needs to grant owner permissions to the provider auth account of this connection, or else setting up cloud build for the shiny apps won't work!

  * This is currently set up with name "datahub-automation". You can just continue using this. It uses the GitHub account "datahub-automation", which is a hidden owner for the PHACDataHub github organization, intended for this kind of "machine use".
* ~~Create Cloud DNS zone, or add A record for subdomain, pointing at k8s cluster -~~

  * Done in terraform
* Copy cloudbuild.yaml to cloudbuild-test.yaml (etc) and modify to use correct k8s cluster and artifact repo
* Create cloud build trigger pointing at that particular cloudbuild file

  * can also be done in terraform
* After creating `dev`, create a NS record in `prod` with the name servers found by clicking `Registrar Setup `in the top right corner of the `Zone details` page of the DNS zone.
