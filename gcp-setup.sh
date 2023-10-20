#!/bin/bash
_app_name="${1:-django-shiny}"
_vpn_ip="${2:-$(curl ifconfig.me)/32}"
_secret="${3:-$(openssl rand -base64 24)}"
echo "App Name: $_app_name"
echo "VPN IP: $_vpn_ip"

var=${PROJECT_ID:=phx-datadissemination}
echo "Project ID: $PROJECT_ID"
var=${REGION:=northamerica-northeast1}
var=${LOCATION:=$REGION}  # just an alias
echo "Region: $REGION"

# Storage bucket for django MEDIA
var=${BUCKET:=${_app_name}-media}
# echo "Bucket Name: $BUCKET"
gcloud storage buckets create gs://$BUCKET --default-storage-class=STANDARD --location=$LOCATION --uniform-bucket-level-access --public-access-prevention

# Artifact repos for the app itself, and the shiny apps it serves
var=${DJANGO_ARTIFACT_REPO:=${_app_name}-repo}
# echo "Django Artifact Repo Name: $DJANGO_ARTIFACT_REPO"
gcloud artifacts repositories create $DJANGO_ARTIFACT_REPO --repository-format=docker --location=$LOCATION

var=${APPS_ARTIFACT_REPO:=${_app_name}-apps-repo}
# echo "Apps Artifact Repo Name: $APPS_ARTIFACT_REPO"
gcloud artifacts repositories create $APPS_ARTIFACT_REPO --repository-format=docker --location=$LOCATION

# IAM Service Account for app operations (cloudbuild, k8s, etc)
var=${SA_NAME:=${_app_name}-sa}
var=${SA_DISPLAY_NAME:=${_app_name}-service-account}
gcloud iam service-accounts create $SA_NAME \
    --display-name="$SA_DISPLAY_NAME"

# Add IAM Roles to the Service Account
var=${ROLES:="cloudbuild.connectionAdmin cloudbuild.connectionViewer cloudbuild.builds.editor cloudbuild.builds.viewer container.admin secretmanager.secretAccessor storage.objectUser"}
for ROLE_NAME in $ROLES
do
        gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role="$ROLE_NAME"
    done

# Save the account key file to the current directory
var=${KEY_FILE:=./$SA_NAME-key.json}
gcloud iam service-accounts keys create $KEY_FILE --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com

# This is the tricky stuff. See the following tutorial:
# https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools

# Create networks for cloudbuild pool and GKE
var=${CLOUDBUILD_NETWORK:=${_app_name}-cloudbuild-network}
var=${GKE_NETWORK:=${_app_name}-gke-network}
gcloud compute networks create $CLOUDBUILD_NETWORK --subnet-mode=custom
gcloud compute networks create $GKE_NETWORK --subnet-mode=custom

# Create subnets for GKE
# var=${CLOUDBUILD_SUBNET:=${_app_name}-cloudbuild-subnet}
var=${GKE_SUBNET:=${_app_name}-gke-subnet}
gcloud compute networks subnets create $GKE_SUBNET --network=$GKE_NETWORK --range=10.244.252.0/22 --region=$REGION

# Create the GKE private cluster
# Enable control plane access from our VPN IP address
var=${CLUSTER_CONTROL_PLANE_CIDR:=172.16.0.32/28}
var=${GKE_CLUSTER:=${_app_name}-gke-cluster}
gcloud container clusters create $GKE_CLUSTER --region=$REGION --enable-master-authorized-networks --network=$GKE_NETWORK --subnetwork=$GKE_SUBNET --enable-private-nodes --enable-ip-alias --master-ipv4-cidr=$CLUSTER_CONTROL_PLANE_CIDR --master-authorized-networks $VPN_IP

# Update peering on GKE network
var=${GKE_PEERING_NAME:=$(gcloud container clusters describe $GKE_CLUSTER --region=$REGION --format='value(privateClusterConfig.peeringName)')}
gcloud compute networks peerings update $GKE_PEERING_NAME --network=$GKE_NETWORK --export-custom-routes --no-export-subnet-routes-with-public-ip

# Create the Cloud Build private pool
var=${CLOUDBUILD_POOL:=${_app_name}-cloudbuild-pool}
var=${POOL_IP_RANGE:=${_app_name}-cloudbuild-pool-ip-range}
var=${POOL_ADDRESSES:=192.168.0.0}
gcloud compute addresses create $POOL_IP_RANGE --global --purpose=VPC_PEERING --addresses=$POOL_ADDRESSES --prefix-length=20 --network=$CLOUDBUILD_NETWORK

gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com --ranges=$POOL_IP_RANGE --network=$CLOUDBUILD_NETWORK

gcloud compute networks peerings update servicenetworking-googleapis-com --network=$CLOUDBUILD_NETWORK     --export-custom-routes --no-export-subnet-routes-with-public-ip

gcloud builds worker-pools create $CLOUDBUILD_POOL --region=$REGION --peered-network=projects/$PROJECT_ID/global/networks/$CLOUDBUILD_NETWORK

# Create VPN Gateways for GKE and Cloud Build
var=${GKE_VPN_GATEWAY:=${_app_name}-gke-vpn-gateway}
var=${CLOUDBUILD_VPN_GATEWAY:=${_app_name}-cloudbuild-vpn-gateway}

gcloud compute vpn-gateways create $GKE_VPN_GATEWAY --network=$GKE_NETWORK --region=$REGION --stack-type=IPV4_ONLY
gcloud compute vpn-gateways create $CLOUDBUILD_VPN_GATEWAY --network=$CLOUDBUILD_NETWORK --region=$REGION --stack-type=IPV4_ONLY

# Create routers for GKE and Cloud Build
var=${GKE_ROUTER:=${_app_name}-gke-router}
var=${CLOUDBUILD_ROUTER:=${_app_name}-cloudbuild-router}
var=${GKE_ROUTER_ASN:=65001}
var=${CLOUDBUILD_ROUTER_ASN:=65002}

gcloud compute routers create $GKE_ROUTER --region=$REGION --network=$GKE_NETWORK --asn=$GKE_ROUTER_ASN
gcloud compute routers create $CLOUDBUILD_ROUTER --region=$REGION --network=$CLOUDBUILD_NETWORK --asn=$CLOUDBUILD_ROUTER_ASN

# Create two VPN tunnels for each gateway direction (for HA)
var=${GKE_TO_CLOUDBUILD_TUNNEL_1:=${_app_name}-gke-to-cloudbuild-tunnel-1}
var=${GKE_TO_CLOUDBUILD_TUNNEL_2:=${_app_name}-gke-to-cloudbuild-tunnel-2}
var=${CLOUDBUILD_TO_GKE_TUNNEL_1:=${_app_name}-cloudbuild-to-gke-tunnel-1}
var=${CLOUDBUILD_TO_GKE_TUNNEL_2:=${_app_name}-cloudbuild-to-gke-tunnel-2}

gcloud compute vpn-tunnels create $GKE_TO_CLOUDBUILD_TUNNEL_1 --peer-gcp-gateway=$CLOUDBUILD_VPN_GATEWAY --region=$REGION --ike-version=2 --shared-secret=$_secret --router=$GKE_ROUTER --vpn-gateway=$GKE_VPN_GATEWAY --interface=0
gcloud compute vpn-tunnels create $GKE_TO_CLOUDBUILD_TUNNEL_2 --peer-gcp-gateway=$CLOUDBUILD_VPN_GATEWAY --region=$REGION --ike-version=2 --shared-secret=$_secret --router=$GKE_ROUTER --vpn-gateway=$GKE_VPN_GATEWAY --interface=1
gcloud compute vpn-tunnels create $CLOUDBUILD_TO_GKE_TUNNEL_1 --peer-gcp-gateway=$GKE_VPN_GATEWAY --region=$REGION --ike-version=2 --shared-secret=$_secret --router=$CLOUDBUILD_ROUTER --vpn-gateway=$CLOUDBUILD_VPN_GATEWAY --interface=0
gcloud compute vpn-tunnels create $CLOUDBUILD_TO_GKE_TUNNEL_2 --peer-gcp-gateway=$GKE_VPN_GATEWAY --region=$REGION --ike-version=2 --shared-secret=$_secret --router=$CLOUDBUILD_ROUTER --vpn-gateway=$CLOUDBUILD_VPN_GATEWAY --interface=1

# You may need to wait a minute here
echo "Waiting for VPN tunnels to come up. Please check cloud console for status, and press any key to continue."
read -n 1 -s

# Router interfaces and BGP routes
var=${GKE_ROUTER_INTERFACE_1:=${_app_name}-gke-to-cloudbuild-bgp-if-1}
var=${GKE_ROUTER_INTERFACE_2:=${_app_name}-gke-to-cloudbuild-bgp-if-2}
var=${GKE_ROUTER_INTERFACE_1_PEER:=${_app_name}-gke-to-cloudbuild-bgp-peer-1}
var=${GKE_ROUTER_INTERFACE_2_PEER:=${_app_name}-gke-to-cloudbuild-bgp-peer-2}
var=${GKE_BGP_IP_1:=169.254.0.1}
var=${GKE_BGP_PEER_IP_1:=169.254.0.2}
var=${GKE_BGP_IP_2:=169.254.1.1}
var=${GKE_BGP_PEER_IP_2:=169.254.1.2}

gcloud compute routers add-interface $GKE_ROUTER --interface-name=$GKE_ROUTER_INTERFACE_1 --ip-address=$GKE_BGP_IP_1 --mask-length=30 --vpn-tunnel=$GKE_TO_CLOUDBUILD_TUNNEL_1 --region=$REGION
gcloud compute routers add-bgp-peer $GKE_ROUTER --peer-name=$GKE_ROUTER_INTERFACE_1_PEER --interface=$GKE_ROUTER_INTERFACE_1 --peer-ip-address=$GKE_BGP_PEER_IP_1 --peer-asn=$CLOUDBUILD_ROUTER_ASN --region=$REGION

gcloud compute routers add-interface $GKE_ROUTER --interface-name=$GKE_ROUTER_INTERFACE_2 --ip-address=$GKE_BGP_IP_2 --mask-length=30 --vpn-tunnel=$GKE_TO_CLOUDBUILD_TUNNEL_2 --region=$REGION
gcloud compute routers add-bgp-peer $GKE_ROUTER --peer-name=$GKE_ROUTER_INTERFACE_2_PEER --interface=$GKE_ROUTER_INTERFACE_2 --peer-ip-address=$GKE_BGP_PEER_IP_2 --peer-asn=$CLOUDBUILD_ROUTER_ASN --region=$REGION

# Same thing the other direction
var=${CLOUDBUILD_ROUTER_INTERFACE_1:=${_app_name}-cloudbuild-to-gke-bgp-if-1}
var=${CLOUDBUILD_ROUTER_INTERFACE_2:=${_app_name}-cloudbuild-to-gke-bgp-if-2}
var=${CLOUDBUILD_ROUTER_INTERFACE_1_PEER:=${_app_name}-cloudbuild-to-gke-bgp-peer-1}
var=${CLOUDBUILD_ROUTER_INTERFACE_2_PEER:=${_app_name}-cloudbuild-to-gke-bgp-peer-2}

gcloud compute routers add-interface $CLOUDBUILD_ROUTER --interface-name=$CLOUDBUILD_ROUTER_INTERFACE_1 --ip-address=$GKE_BGP_PEER_IP_1 --mask-length=30 --vpn-tunnel=$CLOUDBUILD_TO_GKE_TUNNEL_1 --region=$REGION
gcloud compute routers add-bgp-peer $CLOUDBUILD_ROUTER --peer-name=$CLOUDBUILD_ROUTER_INTERFACE_1_PEER --interface=$CLOUDBUILD_ROUTER_INTERFACE_1 --peer-ip-address=$GKE_BGP_IP_1 --peer-asn=$GKE_ROUTER_ASN --region=$REGION

gcloud compute routers add-interface $CLOUDBUILD_ROUTER --interface-name=$CLOUDBUILD_ROUTER_INTERFACE_2 --ip-address=$GKE_BGP_PEER_IP_2 --mask-length=30 --vpn-tunnel=$CLOUDBUILD_TO_GKE_TUNNEL_2 --region=$REGION
gcloud compute routers add-bgp-peer $CLOUDBUILD_ROUTER --peer-name=$CLOUDBUILD_ROUTER_INTERFACE_2_PEER --interface=$CLOUDBUILD_ROUTER_INTERFACE_2 --peer-ip-address=$GKE_BGP_IP_2 --peer-asn=$GKE_ROUTER_ASN --region=$REGION

# Configure to advertise routes
gcloud compute routers update-bgp-peer $GKE_ROUTER --peer-name=$GKE_ROUTER_INTERFACE_1_PEER --region=$REGION --advertisement-mode=CUSTOM --set-advertisement-ranges=$CLUSTER_CONTROL_PLANE_CIDR
gcloud compute routers update-bgp-peer $GKE_ROUTER --peer-name=$GKE_ROUTER_INTERFACE_2_PEER --region=$REGION --advertisement-mode=CUSTOM --set-advertisement-ranges=$CLUSTER_CONTROL_PLANE_CIDR
gcloud compute routers update-bgp-peer $CLOUDBUILD_ROUTER --peer-name=$CLOUDBUILD_ROUTER_INTERFACE_1_PEER --region=$REGION --advertisement-mode=CUSTOM --set-advertisement-ranges=$POOL_ADDRESSES/20
gcloud compute routers update-bgp-peer $CLOUDBUILD_ROUTER --peer-name=$CLOUDBUILD_ROUTER_INTERFACE_2_PEER --region=$REGION --advertisement-mode=CUSTOM --set-advertisement-ranges=$POOL_ADDRESSES/20

# Add private pool network range to control plane authorized networks in GKE
gcloud container clusters update $GKE_CLUSTER --enable-master-authorized-networks --region=$REGION --master-authorized-networks=$POOL_ADDRESSES/20

# Allow cloud build service account to access GKE cluster control pane
var=${PROJECT_NUMBER:=$(gcloud projects describe $PROJECT_ID --format 'value(projectNumber)')}
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com --role=roles/container.developer

# Validate
mkdir private-pool-test && cd private-pool-test

cat > cloudbuild.yaml <<EOF
steps:
- name: "gcr.io/cloud-builders/kubectl"
  args: ['get', 'nodes']
  env:
  - 'CLOUDSDK_COMPUTE_REGION=$REGION'
  - 'CLOUDSDK_CONTAINER_CLUSTER=$GKE_CLUSTER'
options:
  workerPool:
    'projects/$GOOGLE_CLOUD_PROJECT/locations/$REGION/workerPools/$CLOUDBUILD_POOL'
EOF

gcloud builds submit --config=cloudbuild.yaml

# Set up Cloud NAT for GKE so there is a static outgoing IP
# (TODO) and print it to the user (for allowlisting)
# I have done this before, just need to script it
# Cloud NAT  https://cloud.google.com/nat/docs/gke-example#create-nat
# Start at step 6!

# Set up static incoming IP for pointing DNS to the app
# (TODO - can't get this working!)

# Deploy the kubernetes yaml files
# (TODO - could automate the modification of these files?)

# Set up cloud build trigger for django app
# (TODO - could automate modification of cloudbuild.yaml, or use substitutions)
