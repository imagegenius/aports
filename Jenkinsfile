pipeline {
  agent {
    label 'X86-BUILDER-1'
  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '60'))
    parallelsAlwaysFailFast()
  }
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('github_token')
    IG_USER = 'imagegenius'
    IG_REPO = 'aports'
  }
  stages {
    stage("Set ENV Variables"){
      steps{
        script{
          env.GITHUBIMAGE = 'ghcr.io/' + env.IG_USER + '/' + env.IG_REPO + '-cache'
        }
      }
    }
    stage('Build-Multi') {
      matrix {
        axes {
          axis {
            name 'MATRIXARCH'
            values 'X86-64', 'ARM64'
          }
          axis {
            name 'ALPINETAG'
            values '3.17', 'edge'
          }
        }
        stages {
          stage('axis') {
            agent none
            steps {
              script {
                stage("alpine-v${ALPINETAG} on ${MATRIXARCH}") {
                  print "alpine-v${ALPINETAG} on ${MATRIXARCH}"
                }
              }
            }
          }
          stage ('Build') {
            agent {
              label "${MATRIXARCH}"
            }
            steps {
              echo "Running on node: ${NODE_NAME}"
              withCredentials([
                string(credentialsId: 'package-private-key', variable: 'PRIVKEY'),
                ]) {
                echo 'Logging into Github'
                sh '''#!/bin/bash
                      echo $GITHUB_TOKEN | docker login ghcr.io -u ImageGenius-CI --password-stdin
                   '''
                echo 'Building packages'
                sh '''#!/bin/bash
                      if [[ "$MATRIXARCH" == "X86-64" ]]; then
                        ARCH="x86_64"
                        BUILD_ARCH="amd64"
                      elif [[ "$MATRIXARCH" == "ARM64" ]]; then
                        ARCH="arm64"
                        BUILD_ARCH="aarch64"
                      elif [[ "$MATRIXARCH" == "ARMHF" ]]; then
                        ARCH="armhf"
                        BUILD_ARCH="arm/v7"
                      fi
                      BUILDX_CONTAINER=$(head /dev/urandom | tr -dc 'a-z' | head -c12)
                      docker buildx create --driver=docker-container --name=${BUILDX_CONTAINER}
                      docker pull ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}
                      if [ $? -ne 0 ]; then
                        echo "It doesn't look like \"${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}\" exists on ghcr, building an empty image"
                        docker buildx build \
                          -t ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH} \
                          --build-arg ALPINETAG=${ALPINETAG} \
                          -f Dockerfile.empty . \
                          --platform=linux/${BUILD_ARCH} \
                          --builder=${BUILDX_CONTAINER} --load
                        docker push ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}
                      fi
                      set -e
                      docker buildx build \
                        --no-cache --pull -t ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH} \
                        --build-arg PRIVKEY="$PRIVKEY" \
                        --build-arg ALPINETAG=${ALPINETAG} \
                        --build-arg ARCH=${ARCH} . \
                        --platform=linux/${BUILD_ARCH} \
                        --builder=${BUILDX_CONTAINER} --load
                      docker push ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}
                      docker rmi \
                        ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH} || :
                      docker buildx rm ${BUILDX_CONTAINER}
                   '''
              }
            }
          }
        }
      }
    }
    stage ('Download Packages') {
      steps {
        withCredentials([
          string(credentialsId: 'ci-tests-s3-key-id', variable: 'S3_KEY'),
          string(credentialsId: 'ci-tests-s3-secret-access-key', variable: 'S3_SECRET')
        ]) {
          // 'version' and 'arches' need to match matrix axis'
          echo "Get packages from images"
          sh '''#!/bin/bash
                versions=(3.17 edge)
                arches=(x86_64 aarch64)
                for version in "${versions[@]}"; do
                  for arch in "${arches[@]}"; do
                    docker pull ${GITHUBIMAGE}:v${version}-${arch}     
                    docker create --name aports-${version}-${arch} ${GITHUBIMAGE}:v${version}-${arch} blah
                    docker cp aports-${version}-${arch}:/aports .
                    docker rm aports-${version}-${arch}
                    docker rmi ${GITHUBIMAGE}:v${version}-${arch}
                  done
                done
             '''
          echo "Copy Packages to Webroot"
          sh '''#!/bin/bash
                set -e
                rclone sync aports s3:packages.imagegenius.io \
                  --include "*/" \
                  --include "*/**" \
                  --exclude "*" \
                  --s3-access-key-id=${S3_KEY} \
                  --s3-secret-access-key=${S3_SECRET} \
                  --ignore-errors \
                  --no-update-modtime
                rm -rf aports
             '''
        }
      }
    }
  }
  post {
    always {
      script{
        if (currentBuild.currentResult == "SUCCESS"){
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 1681177,\
                 "description": "**'${IG_REPO}' build '${BUILD_NUMBER}'**\\n**Job:** '${RUN_DISPLAY_URL}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
        else {
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 16711680,\
                 "description": "**'${IG_REPO}' build '${BUILD_NUMBER}' Failed!**\\n**Job:** '${RUN_DISPLAY_URL}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
      }
    }
    cleanup {
      cleanWs()
    }
  }
}
