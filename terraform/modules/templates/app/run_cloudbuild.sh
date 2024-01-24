#!/bin/sh

gcloud builds triggers run ${trigger_name} --region=${region} --branch=${branch_name}
