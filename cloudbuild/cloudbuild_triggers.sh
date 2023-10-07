FILES="./cloudbuild/*.cloudbuild.sh"
for f in $FILES
do
    echo "Setting up build trigger using $f ..."
    $f
done