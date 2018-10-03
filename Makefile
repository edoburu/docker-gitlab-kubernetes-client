image:
	docker build -t edoburu/gitlab-kubernetes-client .

release:
	docker login
	docker push edoburu/gitlab-kubernetes-client
