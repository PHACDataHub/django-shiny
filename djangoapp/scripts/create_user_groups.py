from shinyauth.models import UserGroup, UserEmailMatch

def run():
    # Public group
    public_group, created = UserGroup.objects.get_or_create(name='Public')
    public_group.save()
