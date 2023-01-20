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
                        echo "It doesn't look like \"ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch)\" exists on ghcr, building an empty image"
                        docker build . -t ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch) -f Dockerfile.empty
                        docker build \
                          --no-cache -t ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch) \
                          --build-arg PRIVKEY="$PRIVKEY" \
                          --build-arg ALPINETAG=${ALPINETAG} \
                          --build-arg ARCH=$(arch) .
                      else
                        docker build \
                          --no-cache --pull -t ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch) \
                          --build-arg PRIVKEY="$PRIVKEY" \
                          --build-arg ALPINETAG=${ALPINETAG} \
                          --build-arg ARCH=$(arch) .
                      fi
                   '''
                echo 'Pushing image to ghcr'
                sh '''#! /bin/bash
                      docker push ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch)
                      docker rmi \
                        ghcr.io/imagegenius/aports-cache:v${ALPINETAG}-$(arch) || :
                   '''
                echo "Removing dangling images"
                sh '''#!/bin/bash
                      dangling_images=$(docker images -f dangling=true -q)
                      if [ -n "$dangling_images" ]; then
                        echo "Removing dangling images..."
                        docker rmi $dangling_images
                      else
                        echo "No dangling images found."
                      fi
               '''
              }
            }
          }
        }
      }
    }
    stage ('Copy Packages to Webroot') {
      steps {
        sh '''#!/bin/bash
              versions=(3.17)
              arches=(x86_64 aarch64)

              for version in "${versions[@]}"; do
                for arch in "${arches[@]}"; do
                  docker pull ghcr.io/imagegenius/aports-cache:v${version}-${arch}
                            
                  docker create --name aports-${version}-${arch} ghcr.io/imagegenius/aports-cache:v${version}-${arch} blah
              
                  docker cp aports-${version}-${arch}:/aports .
              
                  docker rm aports-${version}-${arch}
                  docker rmi ghcr.io/imagegenius/aports-cache:v${version}-${arch}
                done
              done
              rsync -av --delete aports/* /var/www/packages/
              rm -rf aports
           '''
      }
    }
  }
  post {
    always {
      script{
        if (currentBuild.currentResult == "SUCCESS"){
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 1681177,\
                 "description": "**aports Build '${BUILD_NUMBER}' Results**\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
        else {
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 16711680,\
                 "description": "**aports Build '${BUILD_NUMBER}' Results**\\n**Status:**  failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
      }
    }
    cleanup {
      cleanWs()
    }
  }
}
