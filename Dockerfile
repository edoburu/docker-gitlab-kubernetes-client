# Based on https://github.com/linkyard/docker-helm/blob/master/Dockerfile
FROM alpine:3.6 as build
MAINTAINER Diederik van der Boor <opensource@edoburu.nl>

ARG HELM_VERSION=v2.7.2
ARG KUBE_VERSION=v1.8.5

RUN apk add --update --no-cache ca-certificates git
RUN apk add --update -t deps curl tar gzip

RUN curl -Lo /tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl
RUN curl -L http://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar zxv -C /tmp --strip-components=1 linux-amd64/helm
RUN chmod +x /tmp/kubectl /tmp/helm

# The image we keep
FROM alpine:3.6
RUN apk add --update --no-cache git ca-certificates
COPY --from=build /tmp/kubectl /tmp/helm /bin/
COPY create-image-pull-secret create-kubeconfig create-namespace create-release /bin/
CMD ["/bin/helm"]
