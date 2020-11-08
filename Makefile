deploy:
	hugo -D
	gsutil -m rsync -r ./public gs://domudall-blog
	gsutil iam ch allUsers:objectViewer gs://domudall-blog
	gsutil web set -m index.html -e 404.html gs://domudall-blog

develop:
	hugo -D server