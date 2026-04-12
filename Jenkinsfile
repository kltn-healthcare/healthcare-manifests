pipeline {
    agent any

    environment {
        // Add bin folder to PATH to use tools from Makefile
        PATH = "${WORKSPACE}/bin:${env.PATH}"
    }

    stages {
        stage('Pull Source') {
            steps {
                checkout scm
            }
        }

        stage('Install Tools') {
            steps {
                // Just run the Makefile target to get everything ready
                sh "make check-tools"
            }
        }

        stage('Lint Check') {
            steps {
                echo "Scanning for YAML syntax and security issues..."
                sh "yamllint apps/ infrastructure/"
                sh "kube-linter lint apps/ infrastructure/"
            }
        }

        stage('K8s Server Dry-run') {
            steps {
                withCredentials([file(credentialsId: 'k8s-kubeconfig', variable: 'KUBE_CONFIG_PATH')]) {
                    script {
                        // env.KUBECONFIG = KUBE_CONFIG_PATH
                        
                        // echo "Validating Infrastructure..."
                        // // We check core infra because they are the foundation
                        // sh "kubectl apply -k infrastructure/argocd --dry-run=server"
                        // sh "kubectl apply -k infrastructure/metallb --dry-run=server"

                        echo "Validating Application Overlays..."
                        // For apps, we only check staging for now to keep it simple
                        sh "kubectl apply -k apps/overlays/staging/frontend --dry-run=client"
                        sh "kubectl apply -k apps/overlays/staging/frontend --dry-run=server"
                        
                        // Tip: If you add more services later, just add more 'sh' lines here
                        // Or a simple loop if you're feeling fancy.
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
    }
}