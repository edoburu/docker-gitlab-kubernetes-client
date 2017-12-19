docker-kubernetes-client
========================

This is a small image that allows to run ``git``, ``kubectl`` and ``helm``.
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
      - create-release "RELEASE_NAME" "CHART_DIR" -f "values-$CI_ENVIRONMENT_SLUG.yml" --set="imageTag=$CI_IMAGE_TAG"
      only:
      - tags


Or run the commands manually:

.. code-block:: bash

  helm upgrade --install --namespace "$KUBE_NAMESPACE" --reset-values "RELEASE_NAME" "CHART_DIR" -f "values-$CI_ENVIRONMENT_SLUG.yml" --set="imageTag=$CI_IMAGE_TAG,nameOverride=$CI_ENVIRONMENT_SLUG"


Development
-----------

To build this image::

    docker build -t edoburu/gitlab-kubernetes-client .

And release::

    docker login
    docker push edoburu/gitlab-kubernetes-client

