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

        stage('Test') {
            steps {
                dir('maven-demo') {
                    sh '/opt/homebrew/bin/mvn test'
                }
            }
        }

    }

    post {
        always {
            junit testResults: 'maven-demo/target/surefire-reports/*.xml',
                  allowEmptyResults: true
        }
    }
}
