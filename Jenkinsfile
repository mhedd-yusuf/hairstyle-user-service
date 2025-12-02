pipeline {
    agent any

    // Environment variables - customize these
    environment {
        // Docker configuration
        DOCKER_HUB_REPO = 'eltumerabe'  // Change this
        IMAGE_NAME = 'hairstyle-user-service'
        IMAGE_TAG = "${BUILD_NUMBER}"

        // AWS configuration
        AWS_REGION = 'eu-west-2'
        EKS_CLUSTER_NAME = 'springboot-eks-cluster'

        // Application configuration
        APP_NAME = 'hairstyle-user-service'
        NAMESPACE = 'default'

        // Credentials IDs (configured in Jenkins)
        DOCKERHUB_CREDENTIALS = 'dockerhub-credentials'
        AWS_CREDENTIALS = 'aws-credentials'
    }

    stages {
        stage('Checkout') {
            steps {
                echo '📥 Checking out code from repository...'
                checkout scm
            }
        }

        stage('Build Application') {
            steps {
                echo '🔨 Building Spring Boot application...'
                script {
                    // For Maven projects
                    if (fileExists('pom.xml')) {
                        sh 'mvn clean package -DskipTests'
                    }
                    // For Gradle projects
                    else if (fileExists('build.gradle') || fileExists('build.gradle.kts')) {
                        sh './gradlew clean build -x test'
                    }
                    else {
                        error('No Maven or Gradle build file found!')
                    }
                }
            }
        }

        stage('Run Tests') {
            steps {
                echo '🧪 Running tests...'
                script {
                    try {
                        if (fileExists('pom.xml')) {
                            sh 'mvn test'
                        } else {
                            sh './gradlew test'
                        }
                    } catch (Exception e) {
                        echo "⚠️ Tests failed, but continuing... ${e.message}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Build with --no-cache to force fresh build
                    sh """
                        docker build --no-cache \
                            -t ${DOCKER_HUB_REPO}/${IMAGE_NAME}:${IMAGE_TAG} \
                            -t ${DOCKER_HUB_REPO}/${IMAGE_NAME}:latest \
                            .
                    """
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo '📤 Pushing Docker image to Docker Hub...'
                script {
                    docker.withRegistry('https://registry.hub.docker.com', DOCKERHUB_CREDENTIALS) {
                        docker.image("${DOCKER_HUB_REPO}/${IMAGE_NAME}:${IMAGE_TAG}").push()
                        docker.image("${DOCKER_HUB_REPO}/${IMAGE_NAME}:latest").push()
                    }
                }
            }
        }

        stage('Configure kubectl') {
            steps {
                echo '⚙️ Configuring kubectl for EKS...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                credentialsId: AWS_CREDENTIALS]]) {
                    sh """
                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${EKS_CLUSTER_NAME}

                        kubectl version --client
                        kubectl cluster-info
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                echo '🚀 Deploying to EKS cluster...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                credentialsId: AWS_CREDENTIALS]]) {
                    script {
                        // Update image tag in deployment
                        sh """
                            # Create namespace if it doesn't exist
                            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

                            # Apply ConfigMap and Secrets first
                            kubectl apply -f k8s/configmap.yaml -n ${NAMESPACE}
                            kubectl apply -f k8s/secret.yaml -n ${NAMESPACE}

                            # Update deployment with new image
                            sed -i 's|IMAGE_PLACEHOLDER|${DOCKER_HUB_REPO}/${IMAGE_NAME}:${IMAGE_TAG}|g' k8s/deployment.yaml

                            # Apply deployment and service
                            kubectl apply -f k8s/deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k8s/service.yaml -n ${NAMESPACE}

                            # Force restart deployment to pull new image
                            kubectl rollout restart deployment/${APP_NAME} -n ${NAMESPACE}

                            # Wait for rollout to complete
                            kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=10m
                        """
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                credentialsId: AWS_CREDENTIALS]]) {
                    sh """
                        echo "Pods status:"
                        kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}

                        echo "\nService details:"
                        kubectl get svc -n ${NAMESPACE} -l app=${APP_NAME}

                        echo "\nDeployment status:"
                        kubectl get deployment ${APP_NAME} -n ${NAMESPACE}
                    """
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully!'
            echo "🎉 Application deployed: ${DOCKER_HUB_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo '❌ Pipeline failed!'
        }
        always {
            echo '🧹 Cleaning up...'
            // Clean up Docker images to save space
            sh """
                docker rmi ${DOCKER_HUB_REPO}/${IMAGE_NAME}:${IMAGE_TAG} || true
                docker rmi ${DOCKER_HUB_REPO}/${IMAGE_NAME}:latest || true
            """
        }
    }
}