docker-kubernetes-client
========================

This is a small image that allows to run ``git``, ``docker``, ``kubectl`` and ``helm``.

It also provides some convenient commands to perform a release.

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
      # CI_PIPELINE_ID is useful to force redeploys on pipeline triggers
      # CI_COMMIT_TAG is only filled for tags.
      # CI_COMMIT_REF_NAME can be a tag or branch name
      - export IMAGE_TAG=ci_${CI_PIPELINE_ID}_${CI_COMMIT_TAG:-git_${CI_COMMIT_REF_NAME}_$CI_COMMIT_SHA}

    build image:
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
            --set="image.tag=$IMAGE_TAG,nameOverride=$CI_ENVIRONMENT_SLUG"
            "RELEASE_NAME" "CHART_DIR"
      only:
      - tags
      - triggers
      except:
      - beta  # when part of trigger

Instead of running ``helm`` directly, you can also use the more friendly ``create-release`` script:

.. code-block:: bash

    create-release "RELEASE_NAME" "CHART_DIR" --values "values-$CI_ENVIRONMENT_SLUG.yml" --set="image.tag=$CI_COMMIT_TAG"

Any ``helm`` arguments can be passed, including ``--dry-run --debug`` to see what would happen.

Notes
~~~~~

The examples assume you'll create a ``values-{env}.yml`` file with specific deployment configurations per environment.

Some extra settings might be needed to perform docker builds, this depends on your
setup for `building docker images in GitLab <https://docs.gitlab.com/ce/ci/docker/using_docker_build.html>`_

The 'trigger' feature can be used to allow redeploys for an updated base image.
This can be used to automatically deploy security updates.


Preparation
-----------

Provide a container registry
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can use any registry (e.g. cloud based like Docker Hub).
In the examples, it's assumed that the GitLab container registry is enabled.
This also provides several `variables during build <https://docs.gitlab.com/ce/ci/variables/README.html#predefined-variables-environment-variables>`_:

* ``$CI_REGISTRY_IMAGE`` that points to your ``registry.example.com/namespace/project``.
* ``$CI_REGISTRY`` points to your ``registry.example.com``
* ``$CI_REGISTRY_USER`` points to a user account.
* ``$CI_JOB_TOKEN`` is a rotating password that can be used to push images.

When the GitLab container registry is not enabled,
provide these environment variables using
`secret build variables <https://docs.gitlab.com/ce/ci/variables/README.html#secret-variables>`_,
so the example ``.gitlab-ci.yml`` still works without changes.


Create a namespace for the app
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Preferably, different clients should exist in different namespaces.
There is a helper script to do everything for you:

.. code-block:: bash

    docker run --rm -v "$HOME/.kube:/root/.kube" edoburu/gitlab-kubernetes-client create-namespace MY_NAMESPACE

This installs Tiller in a single namespace, with a ``tiller`` and ``deploy`` user.
At the end, it prints all settings needed for
`GitLab Kubernetes integration <https://docs.gitlab.com/ce/user/project/integrations/kubernetes.html>`_.

You can pass ``--dry-run`` to see the configuration it would apply.


Make sure Kubernetes can access your GitLab container registry
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. Create a `personal access token <https://docs.gitlab.com/ce/user/profile/personal_access_tokens.html>`_
   in your GitLab account settings and give it **read_registry** access.

2. Store the access token as a `docker-registry secret <https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/>`_ in Kubernetes:

.. code-block:: bash

    kubectl create secret gitlab-registry $NAME \
        --namespace=$NAMESPACE \
        --docker-server=registry.example.com \
        --docker-username=USERNAME \
        --docker-email=EMAIL \
        --docker-password=PERSONAL_ACCESS_TOKEN

3. Use this secret in the ``imagePullSecrets``.

Either in the `pod template <https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod>`_:

.. code-block:: yaml

    kind: Deployment
    spec:
      template:
        spec:
          imagePullSecrets:
            - name: gitlab-registry
          containers:
            - image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"

Or in the `serviceaccount of the Pod <https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account>`_.

Make sure GitLab can access Kubernetes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``create-namespace`` already gave all values for it, but you can request them again for the ``deploy`` user:

.. code-block:: bash

    docker run --rm -v "$HOME/.kube:/root/.kube" edoburu/gitlab-kubernetes-client get-gitlab-settings deploy namespace=NAMESPACE

Open the `GitLab Kubernetes integration <https://docs.gitlab.com/ce/user/project/integrations/kubernetes.html>`_
in your project to enter the displayed values

When Kubernetes integration is enabled, GitLab adds several environment variables
to the build environment so ``kubectl`` and ``helm`` Just Work (TM):

* ``$KUBECONFIG`` points to a kubeconfig file
* ``$KUBE_CA_PEM`` contains the full CA certificate data.
* ``$KUBE_CA_PEM_FILE`` points to a file with the CA certificate data.
* ``$KUBE_NAMESPACE`` points to your namespace
* ``$KUBE_TOKEN`` contains your service account token
* ``$KUBE_URL`` contains your API server URL.


Using standard helm charts
--------------------------

Helm is already initialized, so no ``helm init --client-only`` is needed.
When you use charts from standard `Kubernetes Chart repositories <https://github.com/kubernetes/charts>`_,
download the latest repository caches::

    helm repo update

Afterwards, ``helm install stable/...`` works as expected.
