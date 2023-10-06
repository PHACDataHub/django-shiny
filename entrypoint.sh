echo "Generating static files..."
python manage.py collectstatic --no-input
echo "Applying migrations..."
python manage.py migrate
echo "Starting server..."
