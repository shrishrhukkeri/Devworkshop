pipeline {
    agent any

    stages {

        stage('Build') {
            steps {
                dir('maven-demo') {
                    sh '/opt/homebrew/bin/mvn clean package'
                }
            }
        }

    }

    post {

        success {

            archiveArtifacts artifacts: 'maven-demo/target/*.jar',
                             fingerprint: true

        }

    }
}
