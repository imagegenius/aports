pipeline {
  agent {
    label 'WEBSERVER'
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
                sh '''#!/bin/bash
                      echo $GITHUB_TOKEN | docker login ghcr.io -u ImageGenius-CI --password-stdin
                   '''
                echo 'Building packages'
                sh '''#!/bin/bash
                      if [[ "$MATRIXARCH" == "X86-64" ]]; then
                        ARCH="x86_64"
                      elif [[ "$MATRIXARCH" == "ARM64" ]]; then
                        ARCH="aarch64"
                      elif [[ "$MATRIXARCH" == "ARMHF" ]]; then
                        ARCH="armhf"
                      fi
                      docker pull ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}
                      if [ $? -ne 0 ]; then
                        echo "It doesn't look like \"${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}\" exists on ghcr, building an empty image"
                        docker build \
                          -t ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH} \
                          --build-arg ALPINETAG=${ALPINETAG} \
                          -f Dockerfile.empty .
                        docker push ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}
                      fi
                      docker build \
                        --no-cache --pull -t ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH} \
                        --build-arg PRIVKEY="$PRIVKEY" \
                        --build-arg ALPINETAG=${ALPINETAG} \
                        --build-arg ARCH=${ARCH} .
                      docker push ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH}
                      docker rmi \
                        ${GITHUBIMAGE}:v${ALPINETAG}-${ARCH} || :
                   '''
              }
            }
          }
        }
      }
    }
    stage ('Download Packages') {
      steps {
        // 'version' and 'arches' need to match matrix axis'
        echo "Get packages from images"
        sh '''#!/bin/bash
              versions=(3.17)
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
              rsync -av --delete aports/* /var/www/packages/
              rm -rf aports
           '''
      }
    }
    stage('Purge Cloudflare Cache') {
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: 'cloudflare_purge',
            usernameVariable: 'ZONE_ID',
            passwordVariable: 'CF_API_KEY'
          ]
        ]) {
          // would be better to purge everything under packages.imagegenius.io/ but cant get it to work
          sh '''#!/bin/bash
                curl -X POST https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache \
                  -H "Authorization: Bearer ${CF_API_KEY}" \
                  -H "Content-Type: application/json" \
                  --data '{"purge_everything":true}' 
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
