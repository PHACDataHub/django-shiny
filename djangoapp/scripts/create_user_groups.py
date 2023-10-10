from shinyauth.models import UserGroup, UserEmailMatch

def run():
    # Public group
    public_group, created = UserGroup.objects.get_or_create(name='Public')
    if created:
        public_email_match = UserEmailMatch.objects.create(
            name='any',
            email_regex='.*'
        )
        public_group.email_matches.add(public_email_match)
        public_group.save()

    # PHAC-only group
    phac_group, created = UserGroup.objects.get_or_create(name='PHAC')
    if created:
        phac_email_match = UserEmailMatch.objects.create(
            name='phac-aspc.gc.ca',
            # ending in @phac-aspc.gc.ca
            email_regex='.*@phac-aspc\.gc\.ca$'
        )
        phac_group.email_matches.add(phac_email_match)
        phac_group.save()
    
    # GC-wide group
    gc_group, created = UserGroup.objects.get_or_create(name='GC')
    if created:
        gc_group.email_matches.add(UserEmailMatch.objects.create(
            name='canada.ca',
            email_regex='.*@canada$'
        ))
        # Ending in @*.gc.ca
        gc_group.email_matches.add(UserEmailMatch.objects.create(
            name='gc.ca',
            email_regex='.*@.*\.gc\.ca$'
        ))
        gc_group.save()

    # Ontario.ca group
    ontario_group, created = UserGroup.objects.get_or_create(name='Ontario')
    if created:
        ontario_group.email_matches.add(UserEmailMatch.objects.create(
            name='ontario.ca',
            email_regex='.*@ontario\.ca$'
        ))
        ontario_group.save()
