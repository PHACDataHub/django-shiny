import os

from shinyauth.models import UserGroup, UserEmailMatch

def run():
    # Public group
    public_group, created = UserGroup.objects.get_or_create(name='Public')
    public_group.save()

    # Get current directory
    current_dir = os.path.dirname(os.path.realpath(__file__))
    parent_dir = os.path.dirname(current_dir)

    # In ENV variable GCP_SA_KEY_JSON, we have a JSON string with the
    # service account key.
    # We need to write it <parent_dir>/gcp_service_account_key.json

    # Get the JSON string
    json_str = os.environ.get('GCP_SA_KEY_JSON')
    print('Retrieved Service Account Key JSON string from ENV variable')
    if json_str:
        # Write it to file
        with open(os.path.join(parent_dir, 'gcp_service_account_key.json'), 'w') as f:
            f.write(json_str)
        print('Wrote Service Account Key JSON string to file')
