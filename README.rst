docker-kubernetes-client
========================

This is a small image that allows to run ``git``, ``kubectl`` and ``helm``.

It also provides some convenient commands to perform a release.

Helm is already initialized, so no ``helm init --client-only`` is needed.
When you install charts from the standard repositories, upgrade first: ``helm repo update``

Usage
-----

Perform the deployment from ``.gitlab-ci.yml``:

.. code-block:: yaml

    image: edoburu/gitlab-kubernetes-client

    stages:
    - build
    - deploy

    before_script:
      # Allow sh substitution to support both tags and commit releases.
      - export IMAGE_TAG=${CI_COMMIT_TAG:-git_${CI_COMMIT_REF_NAME}_$CI_COMMIT_SHA}

    build image:
      # Some extra settings might be needed here depending on the runner config...
      stage: build
      script:
      - docker build -t $CI_REGISTRY_IMAGE:$IMAGE_TAG .
      - docker run --rm $CI_REGISTRY_IMAGE:$IMAGE_TAG /script/to/run/tests
      - docker login -u $CI_REGISTRY_USER -p $CI_JOB_TOKEN $CI_REGISTRY
      - docker push $CI_REGISTRY_IMAGE:$IMAGE_TAG

    deploy to production:
      stage: deploy
      environment:
        name: production
        url: http://example.com/
      when: manual
      script:
      - helm upgrade
            --install
            --tiller-namespace="$KUBE_NAMESPACE"
            --namespace "$KUBE_NAMESPACE"
            --reset-values
            --values "values-$CI_ENVIRONMENT_SLUG.yml"
            --set="imageTag=$IMAGE_TAG,nameOverride=$CI_ENVIRONMENT_SLUG"
            "RELEASE_NAME" "CHART_DIR"
      only:
      - tags

Instead of running ``helm`` directly, you can also use the more friendly ``create-release`` script:

.. code-block:: bash

    create-release "RELEASE_NAME" "CHART_DIR" --values "values-$CI_ENVIRONMENT_SLUG.yml" --set="imageTag=$CI_COMMIT_TAG"

Any ``helm`` arguments can be passed, including ``--dry-run --debug`` to see what would happen.

The examples assume you'll create a ``values-{env}.yml`` file with specific deployment configurations per environment.


Preparation
-----------

Making sure Kubernetes can access your GitLab container registry
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. Create an access token in your GitLab account settings and give it **read_registry** access.

2. Store the access token as a secret in Kubernetes:

.. code-block:: bash

    kubectl create secret gitlab-registry $NAME \
        --namespace=$NAMESPACE \
        --docker-server=registry.example.com '
        --docker-username=USERNAME \
        --docker-email=EMAIL \
        --docker-password=ACCESS_TOKEN

3. Use that secret in the deployment template:

.. code-block:: yaml

    kind: Deployment
    spec:
      template:
        spec:
          imagePullSecrets:
            - name: gitlab-registry
          containers:
            - image: "{{ .Values.imageRepository }}:{{ .Values.imageTag }}"


Make sure GitLab can access Kubernetes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create a namespace where the application will be deployed at.
There is a helper script to do everything for you:

.. code-block:: bash

    docker run --rm -v "$HOME/.kube:/root/.kube" edoburu/gitlab-kubernetes-client create-namespace MY_NAMESPACE

This installs Tiller in a single namespace, with a ``tiller`` and ``deploy`` user.
You can pass ``--dry-run`` to see the configuration it would apply.

Next, configure the "Kubernetes" integration in the GitLab project.
The ``create-namespace`` already gave all values for it,
but you can also request them again:

.. code-block:: bash

    docker run --rm -v "$HOME/.kube:/root/.kube" edoburu/gitlab-kubernetes-client get-gitlab-settings USER_NAME --namespace=NAMESPACE


Development
-----------

To build this image::

    docker build -t edoburu/gitlab-kubernetes-client .

And release::

    docker login
    docker push edoburu/gitlab-kubernetes-client

