pipeline {
  agent {
    label 'MASTER'
  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '60'))
    parallelsAlwaysFailFast()
  }
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('github_token')
  }
  stages {
    stage('Build-Multi') {
      matrix {
        axes {
          axis {
            name 'MATRIXARCH'
            values 'X86-64-MULTI', 'ARM64'
          }
          axis {
            name 'ALPINETAG'
            values '3.17'
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
                sh '''#! /bin/bash
                      echo $GITHUB_TOKEN | docker login ghcr.io -u ImageGenius-CI --password-stdin
                   '''
                echo 'Building packages'
                sh '''#! /bin/bash
				      docker pull ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch)
					  if [ $? -ne 0 ]; then
					    echo "It doesn't look like "ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch)" exists on ghcr, building an empty image 
					    docker build . -t ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch) -f Dockerfile.empty
					  fi
                      docker build \
                        --no-cache --pull -t ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch) \
                        --build-arg PRIVKEY="$PRIVKEY" \
                        --build-arg ALPINETAG=${ALPINETAG} \
                        --build-arg ARCH=$(arch) .
                   '''
                echo 'Pushing image to ghcr'
                sh '''#! /bin/bash
                      docker push ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch)
                      docker rmi \
                        ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch) || :
                   '''
              }
            }
          }
        }
      }
    }
    stage ('Build And Push Combined Image') {
      steps {
        echo 'Logging into Github'
        sh '''#! /bin/bash
              echo $GITHUB_TOKEN | docker login ghcr.io -u ImageGenius-CI --password-stdin
           '''
        echo 'Building combined image'
        sh '''#! /bin/bash
              docker build \
                --no-cache --pull -t ghcr.io/imagegenius/aports:latest \
                . -f Dockerfile.combine
           '''
        echo 'Pushing image to ghcr'
        sh '''#! /bin/bash
              docker push ghcr.io/imagegenius/aports:latest
              docker rmi \
                ghcr.io/imagegenius/aports:latest || :
           '''
      }
    }
  }
  post {
    always {
      script{
        if (currentBuild.currentResult == "SUCCESS"){
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins-ci.org/download/attachments/2916393/headshot.png","embeds": [{"color": 1681177,\
                 "description": "**Wheelie Build:**  '${BUILD_NUMBER}'\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Packages:** '"${PACKAGES}"'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
        else {
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins-ci.org/download/attachments/2916393/headshot.png","embeds": [{"color": 16711680,\
                 "description": "**Wheelie Build:**  '${BUILD_NUMBER}'\\n**Status:**  failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Packages:** '"${PACKAGES}"'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
      }
    }
    cleanup {
      cleanWs()
    }
  }
}