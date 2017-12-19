docker-kubernetes-client
========================

This is a small image that allows to run ``git``, ``kubectl`` and ``helm``.

Usage from GitLab
-----------------

This can be used as GitLab runner image:

In ``.gitlab-ci.yml``:

.. code-block:: yaml

    job_name:
      stage: deploy
      image: edoburu/kubernetes-client
      environment:
        name: production
        url: http://example.com/
      when: manual
      script:
      - create-image-pull-secret "$CI_PROJECT_PATH_SLUG-registry"
      - create-release "RELEASE_NAME" "CHART_DIR" -f "values-$CI_ENVIRONMENT_SLUG.yml" --set="imageTag=$CI_COMMIT_TAG"
      only:
      - tags


Or run the commands manually:

.. code-block:: bash

  helm upgrade --install --namespace "$KUBE_NAMESPACE" --reset-values "RELEASE_NAME" "CHART_DIR" -f "values-$CI_ENVIRONMENT_SLUG.yml" --set="imageTag=$CI_COMMIT_TAG,nameOverride=$CI_ENVIRONMENT_SLUG"

It's assumed that the namespace is already set-up.
This can be done using:

.. code-block:: bash

    docker run --rm  -v "$HOME/.kube:/root/.kube" edoburu/gitlab-kubernetes-client create-namespace mynamespace

This installs Tiller in a single namespace, with a ``tiller`` and ``deploy`` user::


Development
-----------

To build this image::

    docker build -t edoburu/gitlab-kubernetes-client .

And release::

    docker login
    docker push edoburu/gitlab-kubernetes-client

