FILES="./cloudbuild/*.cloudbuild.sh"
for f in $FILES
do
    chmod +x $f
    echo "Setting up build trigger using $f ..."
    $f
done