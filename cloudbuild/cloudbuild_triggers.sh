FILES="./cloudbuild/*.cloudbuild.sh"
for f in $FILES
do
    echo "Setting up build trigger using $f ..."
    bash -c $f
done