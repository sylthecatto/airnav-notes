---
tags: [airnav-cadet, cicd, jenkins, kubernetes, argocd, docker, exam]
module: CI-CD & GitOps
namespace: exam-3
status: complete
---

# CI/CD Practical — Jenkins, Kubernetes & ArgoCD
---
Resources Used:
- https://kubernetes.io/docs/reference/kubectl
- https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret/
- https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/
- https://hub.docker.com/_/python
- https://docs.docker.com/reference/dockerfile/
- https://www.docker.com/blog/docker-best-practices-using-arg-and-env-in-your-dockerfiles/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
-  https://www.jenkins.io/doc/book/pipeline/jenkinsfile/
- https://www.jenkins.io/doc/book/pipeline/syntax/
---

## Hans - Assigned Values

| Field                 | Value                                                   |
| --------------------- | ------------------------------------------------------- |
| Trainee               | Hans                                                    |
| Namespace             | `exam-3`                                                |
| App name              | `portal-c`                                              |
| NodePort (staging)    | `30083`                                                 |
| NodePort (production) | `30183`                                                 |
| App repo              | `https://github.com/sylthecatto/hans-devops.git`        |
| Config repo           | `https://github.com/sylthecatto/hans-devops-config.git` |
| Registry              | `192.168.10.23:5000`                                    |

--- 

- NOTE: Last friday, the repo hans-devops was created in preparation for this practical exam, a placeholder file named placeholder.txt was pushed in order to create both staging and production branches and was later removed once the source code was available.

---

## Step 1: Creating the config repository

```bash
cd ~/Documents
mkdir hans-devops-config
cd hans -devops-config/
git init -b staging

# COPY the placeholder file that was present in hans-devops to this folder

git add .
git commit -m "initial: placeholder file"
git remote add origin https://github.com/sylthecatto/hans-devops-config.git
git push -u origin staging

# Create production branch 
git checkout -b production
git push -u origin production
```

---

## Step 2: Set up my assigned values in node 20

## SSH into the control node at 192.168.10.20
	NOTE: MUST CONNECT TO NETWORK GE-BL9300-200 /5
	
```bash
ssh root@192.168.8.199 #app server  (password root)
ssh root@192.168.10.20 #contorl node (pasword root)
```

## check existing namespaces
-  https://kubernetes.io/docs/reference/kubectl
	kubectl get namespaces

## Creating the namespace
	kubectl create namespace exam-3
		double check using kubectl get namespaces

## Setting up image pull secret
- https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

	ImagePullSecret
		kubectl create secret docker-registry registry-cred \
		  --docker-server=192.168.10.23:5000 \
		  --docker-username=exam \
		  --docker-password=exam \
		  -n exam-3:


- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret/
	API_KEY
		kubectl create secret generic portal-c-secret \
		  --from-literal=API_KEY=hans-exam-key-2026 \
		  -n exam-3


	CHECK THE CREATED SECRETS
		kubectl get secrets -n exam-3

---

## Step 3: Preparing the app repo

	UNZIP THE DOWNLOADED SOURCE CODE FROM GDRIVE
```bash
unzip ~/Downloads/app-20260817T014135Z-1-001.zip
```
	
	TRANSFER THE FILES TO THE LOCAL APP REPO FOLDER LOCATED AT ~/Documents/hans-devops/
```bash
cd app
cp exam-source-app.py exam-source-requirements.txt exam-source-config.json ~/Documents/hans-devops			
```
	
	CD TO THE LOCAL APP REPO AND CHANGE CONTENTS OF config.json
```bash
	cd ~/Documents/hans-devops/
	# remove the placeholder.txt
	git rm placeholder.txt
	# Edit source config using neovim
	nvim exam-source-config.json 
	
	# PREVIOUS CONTENTS
	#{
	  #"app_name": "Portal",
	  #"subtitle": "Running on Kubernetes with GitOps",
	  #"owner": "unassigned"
	#}
	
	# CHANGED TO
	#{
	  #"app_name": "portal-c",
	  #"subtitle": "Running on Kubernetes with GitOps",
	  #"owner": "Hans"
	#}
	
	#Save and quit using :wq and then check the contents using cat to double check
	cat exam-source-config.json
```

	COMMIT CHANGES TO BOTH STAGING AND PRODUCTION
```bash
git add exam-source-app.py exam-source-config.json exam-source-requirements.txt
git commit -m "added source files, removed placeholder.txt, and edited exam-source-config.json"
git push origin staging

git checkout production
git rm placeholder.txt
git checkout staging -- exam-source-app.py exam-source-config.json exam-source-requirements.txt
git add exam-source-app.py exam-source-config.json exam-source-requirements.txt
git commit -m "added source files, removed placeholder.txt, and edited exam-source-config.json"
git push origin production
```
		


## Step 4: Creating the Dockerfile

- https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/

```bash
 cd ~/Documents/hans-devops
 # Create the file
 touch Dockerfile
 # Edit the file
 nvim Dockerfile
```


- https://hub.docker.com/_/python
- https://docs.docker.com/reference/dockerfile/
- https://www.docker.com/blog/docker-best-practices-using-arg-and-env-in-your-dockerfiles/

```bash
# Base image from Dockerhub, as of writing this, python 3.14 is the stable release, 3.15 is available but it is still a rolling release and could add changes that could break
FROM python:3.14-slim

# Set working directory
WORKDIR /app 

# Copy the requirements file 
COPY exam-source-requirements.txt .

# Install dependencies (Flask & gunicorn)
RUN pip install --no-cache-dir -r exam-source-requirements.txt

# Copy source code
COPY exam-source-app.py .

# Copy default config 
COPY exam-source-config.json /app/config/config.json

# Jenkins passes the real version in at build time
ARG APP_VERSION=unset
ENV APP_VERSION=$APP_VERSION

EXPOSE 5000

# Setup an app user so the container doesn't run as the root user
RUN useradd app && chown -R app /app
USER app


# Run
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "exam-source-app:app"]
```


	Pushing the Dockerfile to the repo

```bash
git add Dockerfile
git commit -m "add Dockerfile for portal-c"
git push origin production

git checkout staging
git checkout production -- Dockerfile
git add Dockerfile
git commit -m "add Dockerfile for portal-c"
git push origin staging
```


## Step 5: Setting up the config repo

```bash
cd ~/Documents/hans-devops-config
git checkout staging
touch deployment.yaml service.yaml
nvim deployment.yaml
nvim service.yaml
```


- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

CONTENTS OF deployment.yaml (staging)
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-c-staging
  namespace: exam-3
  labels:
    app: portal-c
    env: staging
spec:
  replicas: 2
  # only manage pods matching these exact labels
  selector:
    matchLabels:
      app: portal-c
      env: staging
  template:
    metadata:
      labels:
        app: portal-c
        env: staging
    spec:
      # lets the pod pull from the private registry
      imagePullSecrets:
        - name: registry-cred
      containers:
        - name: portal-c
          # Jenkins overwrites this line with the real tag it built
          image: 192.168.10.23:5000/portal-c:0.1.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5000
          env:
            - name: APP_ENV
              value: staging
            # pulled from the Secret we created, not typed here
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: portal-c-secret
                  key: API_KEY
          # liveness: is the process alive
          livenessProbe:
            httpGet:
              path: /healthz
              port: 5000
            initialDelaySeconds: 10
            periodSeconds: 10
          # readiness: can it actually serve traffic right now
          readinessProbe:
            httpGet:
              path: /readyz
              port: 5000
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
```



- https://kubernetes.io/docs/concepts/services-networking/service/

CONTENTS OF service.yaml (staging)
```bash
apiVersion: v1
kind: Service
metadata:
  name: portal-c-staging
  namespace: exam-3
spec:
  type: NodePort
  selector:
    app: portal-c
    env: staging
  ports:
    - port: 80
      targetPort: 5000
      nodePort: 30083
```

PUSH STAGING MANIFESTS 
NOTE: Hans 
	NodePort (staging): 30083
	NodePort (production): 30183
```bash
git add deployment.yaml service.yaml
git commit -m "add k8s manifests for portal-c staging"
git push origin staging

git checkout production
git checkout staging -- deployment.yaml service.yaml

nvim deployment.yaml
# Deployment Changes:
	# change metadata: name: portal-c-staging  to portal-c-production
	# change env: staging to production
	# change selector: matchLabels: env: staging to production
	# change template: env: staging to production
	# change env: value: staging to production

nvim service.yaml
# Services Changes:
	# change metadata: name: portal-c-staging to portal-c-production
	# change spec: selector: env: staging to production
	# change nodePort: 30083 to 30183

git add deployment.yaml service.yaml
git commit -m "add k8s manifests for portal-c production"
git push origin production

```

NOTE: pods will show ImagePullBackOff until Jenkins builds and pushes
a real image tag.


## Step 6: Setting up the JenkinsFile in the app repo

NOTE: From previous rotations, I already have setup my personal credentials in the Jenkins GUI
	docker-registry-url for the registry (to know that it's mine)
	github-devops-ci which is called Hans-Jenkins (again, to know that it's mine)

```bash
cd ~/Documents/hans-devops
git checkout staging
touch Jenkinsfile
nvim Jenkinsfile
````


CONTENTS OF Jenkinsfile 
- https://www.jenkins.io/doc/book/pipeline/jenkinsfile/
- https://www.jenkins.io/doc/book/pipeline/syntax/

```bash 
pipeline {
    agent any

    environment {
        APP_NAME    = 'portal-c'
        // pulled from Jenkins credentials
        REGISTRY    = credentials('docker-registry-url')
        CONFIG_REPO = 'github.com/sylthecatto/hans-devops-config.git'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Determine Version & Target Branch') {
            steps {
                script {
                    if (env.TAG_NAME) {
                        // PRODUCTION -- only runs when I explicitly push a tag
                        if (!(env.TAG_NAME ==~ /^v[0-9]+\.[0-9]+\.[0-9]+$/)) {
                            error("Tag '${env.TAG_NAME}' is not vX.Y.Z")
                        }
                        env.VERSION       = env.TAG_NAME
                        env.CONFIG_BRANCH = 'production'
                    } else if (env.BRANCH_NAME == 'staging') {
                        // STAGING -- every push to staging. Never 'latest'.
                        env.VERSION       = "staging-${env.GIT_SHORT}"
                        env.CONFIG_BRANCH = 'staging'
                    } else {
                        // any other branch push (e.g. production) does nothing
                        env.VERSION       = ''
                        env.CONFIG_BRANCH = ''
                        echo "Branch ${env.BRANCH_NAME} does not deploy"
                    }
                    env.IMAGE = "${env.REGISTRY}/${env.APP_NAME}:${env.VERSION}"
                    echo "Version=${env.VERSION}  ConfigBranch=${env.CONFIG_BRANCH}"
                }
            }
        }

        stage('Build & Push Image') {
            when { expression { env.CONFIG_BRANCH != '' } }
            steps {
                sh '''
                    docker build --build-arg APP_VERSION=${VERSION} -t ${IMAGE} .
                    docker push ${IMAGE}
                '''
            }
        }

        stage('Update Config Repo') {
            when { expression { env.CONFIG_BRANCH != '' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-devops-ci',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    sh '''
                        rm -rf config-repo
                        git clone -b ${CONFIG_BRANCH} \
                            https://${GIT_USER}:${GIT_PASS}@${CONFIG_REPO} config-repo
                        cd config-repo

                        sed -i "s|image: .*/${APP_NAME}:.*|image: ${IMAGE}|g" deployment.yaml

                        git config user.email "aaronhansluna.oliverio@gmail.com"
                        git config user.name  "sylthecatto"
                        git add deployment.yaml
                        git commit -m "ci: ${CONFIG_BRANCH} image -> ${VERSION}" || echo "no change"
                        git push origin ${CONFIG_BRANCH}
                    '''
                }
            }
        }
    }

    post {
        success { echo "Done: ${env.VERSION} -> ${env.CONFIG_BRANCH}" }
        failure { echo "Build failed -- nothing deployed." }
    }
}

```


	PUSH TO BOTH BRANCHES
```bash
git add Jenkinsfile
git commit -m "add Jenkinsfile for portal-c"
git push origin staging

git checkout production
git checkout staging -- Jenkinsfile
git add Jenkinsfile
git commit -m "add Jenkinsfile for portal-c"
git push origin production
```

```
NOTE: production only ever deploys from an explicit tag push
for example :
git checkout staging
git tag v1.0.0
```


## STEP 8: SETUP JENKINS MULTI BRANCH PIPELINE
| Setting                               | Value                                            |
| ------------------------------------- | ------------------------------------------------ |
| Job name                              | `hans-devops`                                    |
| Job type                              | Multibranch Pipeline                             |
| Source                                | GitHub                                           |
| Repository owner / repo               | `sylthecatto` / `hans-devops`                    |
| Repository HTTPS URL                  | `https://github.com/sylthecatto/hans-devops.git` |
| Credentials (internal ID)             | `github-devops-ci`                               |
| Credentials (label shown in dropdown) | `Hans - Jenkins`                                 |
| Script Path                           | `Jenkinsfile`                                    |

| Pipeline Configuration                                                        |
| ----------------------------------------------------------------------------- |
| Behaviours: Discover branches                                                 |
| Behaviours: Discover pull requests from origin                                |
| Behaviours: Discover pull requests from forks                                 |
| Behaviours: Discover tags                                                     |
| Build Strategy: Tags <br>Ignore newer than: `-1`<br>Ignore older than: `-1`\| |
| Build Strategy: Regular Branches                                              |


## Step 9: Setting up ArgoCD

1. New App
2. Set application name to portal-c-staging/production
3. Project Name: default
4. Sync Policy: Automatic with Auto-Sync, Prune Resources, and Self Heal ticked.
5. Source Repo Url: https://github.com/sylthecatto/hans-devops.git
6. Revision: Staging/Production Branch
7. Path: .
8. Cluster URL: https://kubernetes.default.svc
9. Namespace: exam-3


## Step 10: Test deploying Staging  & Production Apps

kubectl get nodes -o wide
node 20
http://192.168.8.121:30083     ← staging
http://192.168.8.121:30183     ← production

node 21
http://192.168.8.245:30083 
http://192.168.8.245:30183

node 22
http://192.168.8.233:30083 
http://192.168.8.233:30183 



## Dry Run
```bash
cd ~/Documents/hans-devops
git checkout staging
nvim exam-source-app     # any change
git add eexam-source-app
git commit -m "demo: staging"
git push origin staging
```


Production only moves on an explicit tag

```bash
cd ~/Documents/hans-devops
git checkout staging
git tag v1.0.2
git push origin v1.0.2
```


CURL /READYZ
```bash
curl -i http://$(kubectl get pod -n exam-3 -l env=staging -o jsonpath='{.items[0].status.podIP}'):5000/readyz

curl -i http://$(kubectl get pod -n exam-3 -l env=production -o jsonpath='{.items[0].status.podIP}'):5000/readyz
```

