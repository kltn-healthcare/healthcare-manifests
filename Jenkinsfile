pipeline {
    agent any

    environment {
        // This ensures the pipeline prioritizes the tools we just installed in ./bin
        PATH = "${WORKSPACE}/bin:${WORKSPACE}/bin/.yamllint-venv/bin:${env.PATH}"
    }

    stages {
        stage('Pull Source') {
            steps {
                checkout scm
            }
        }

        stage('Install Tools') {
            steps {
                // This triggers the Makefile to download Kustomize, Kube-linter, and Yamllint
                sh "make check-tools"
            }
        }

        // stage('Lint Check') {
        //     steps {
        //         script {
        //             echo "Scanning for YAML syntax and security issues..."
        //             // We call them directly from bin/ to be 100% sure we use the pinned versions
        //             sh "yamllint apps/ infrastructure/"
        //             sh "kube-linter lint apps/ infrastructure/"
        //         }
        //     }
        // }

        stage('K8s Server Dry-run') {
            steps {
                withCredentials([file(credentialsId: 'k8s-kubeconfig', variable: 'KUBE_CONFIG_PATH')]) {
                    script {
                        // CRITICAL: You must set this variable so kubectl knows which cluster to talk to
                        env.KUBECONFIG = KUBE_CONFIG_PATH
                        
                        // echo "Validating Infrastructure Components..."
                        // // Foundation check
                        // sh "kubectl apply -k infrastructure/argocd --dry-run=server"
                        // sh "kubectl apply -k infrastructure/metallb --dry-run=server"

                        echo "Validating Application Overlays..."
                        // App check
                        sh "kubectl apply -k apps/overlays/staging/frontend --dry-run=server"
                        sh "kubectl apply -k apps/overlays/staging/frontend --dry-run=client"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning up workspace..."
            cleanWs()
        }
        success {
            echo "Manifests validated successfully!"
        }
        failure {
            echo "Validation failed. Please check the logs."
        }
    }
}