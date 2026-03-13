pipeline {
    agent any
    
    environment {
        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        
        // ECR Repository Names
        ECR_REPO_FRONTEND = 'streamingapp-frontend'
        ECR_REPO_AUTH = 'streamingapp-auth'
        ECR_REPO_STREAMING = 'streamingapp-streaming'
        ECR_REPO_ADMIN = 'streamingapp-admin'
        ECR_REPO_CHAT = 'streamingapp-chat'
        
        // Image Tags
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        
        // AWS Credentials
        AWS_CREDENTIALS = credentials('aws-credentials')
        
        // SNS Topic ARN (for ChatOps)
        SNS_TOPIC_ARN = credentials('sns-topic-arn')
    }
    
    parameters {
        choice(name: 'DEPLOYMENT_ENV', choices: ['dev', 'staging', 'production'], description: 'Deployment Environment')
        booleanParam(name: 'DEPLOY_TO_EKS', defaultValue: false, description: 'Deploy to EKS after build?')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run tests before build?')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out code from repository..."
                    checkout scm
                    
                    // Send SNS notification
                    sh """
                        aws sns publish \
                            --topic-arn \${SNS_TOPIC_ARN} \
                            --subject "StreamingApp Build Started" \
                            --message "Build #${env.BUILD_NUMBER} started for commit ${GIT_COMMIT_SHORT}" \
                            --region ${AWS_REGION} || true
                    """
                }
            }
        }
        
        stage('Pre-build Validation') {
            steps {
                script {
                    echo "Validating environment and dependencies..."
                    
                    // Check Docker
                    sh 'docker --version'
                    
                    // Check AWS CLI
                    sh 'aws --version'
                    
                    // Verify AWS credentials
                    sh 'aws sts get-caller-identity'
                }
            }
        }
        
        stage('Run Tests') {
            when {
                expression { params.RUN_TESTS == true }
            }
            parallel {
                stage('Frontend Tests') {
                    steps {
                        dir('frontend') {
                            script {
                                echo "Running frontend tests..."
                                sh '''
                                    npm install
                                    npm test -- --passWithNoTests --watchAll=false
                                '''
                            }
                        }
                    }
                }
                stage('Backend Tests') {
                    steps {
                        script {
                            echo "Running backend tests..."
                            // Add test commands for each backend service
                            sh 'echo "Backend tests placeholder - implement as needed"'
                        }
                    }
                }
            }
        }
        
        stage('Login to ECR') {
            steps {
                script {
                    echo "Logging in to Amazon ECR..."
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        script {
                            echo "Building frontend image..."
                            sh """
                                docker build \
                                    --build-arg REACT_APP_AUTH_API_URL=\${REACT_APP_AUTH_API_URL} \
                                    --build-arg REACT_APP_STREAMING_API_URL=\${REACT_APP_STREAMING_API_URL} \
                                    --build-arg REACT_APP_STREAMING_PUBLIC_URL=\${REACT_APP_STREAMING_PUBLIC_URL} \
                                    --build-arg REACT_APP_ADMIN_API_URL=\${REACT_APP_ADMIN_API_URL} \
                                    --build-arg REACT_APP_CHAT_API_URL=\${REACT_APP_CHAT_API_URL} \
                                    --build-arg REACT_APP_CHAT_SOCKET_URL=\${REACT_APP_CHAT_SOCKET_URL} \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_FRONTEND}:${IMAGE_TAG} \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_FRONTEND}:latest \
                                    ./frontend
                            """
                        }
                    }
                }
                stage('Build Auth Service') {
                    steps {
                        script {
                            echo "Building auth service image..."
                            sh """
                                docker build \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_AUTH}:${IMAGE_TAG} \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_AUTH}:latest \
                                    ./backend/authService
                            """
                        }
                    }
                }
                stage('Build Streaming Service') {
                    steps {
                        script {
                            echo "Building streaming service image..."
                            sh """
                                docker build \
                                    -f backend/streamingService/Dockerfile \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_STREAMING}:${IMAGE_TAG} \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_STREAMING}:latest \
                                    ./backend
                            """
                        }
                    }
                }
                stage('Build Admin Service') {
                    steps {
                        script {
                            echo "Building admin service image..."
                            sh """
                                docker build \
                                    -f backend/adminService/Dockerfile \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_ADMIN}:${IMAGE_TAG} \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_ADMIN}:latest \
                                    ./backend
                            """
                        }
                    }
                }
                stage('Build Chat Service') {
                    steps {
                        script {
                            echo "Building chat service image..."
                            sh """
                                docker build \
                                    -f backend/chatService/Dockerfile \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_CHAT}:${IMAGE_TAG} \
                                    -t ${ECR_REGISTRY}/${ECR_REPO_CHAT}:latest \
                                    ./backend
                            """
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    echo "Running security scans on Docker images..."
                    // Optional: Use Trivy or similar tool for vulnerability scanning
                    sh '''
                        echo "Security scan placeholder - integrate Trivy or AWS ECR scanning"
                    '''
                }
            }
        }
        
        stage('Push to ECR') {
            parallel {
                stage('Push Frontend') {
                    steps {
                        script {
                            echo "Pushing frontend image to ECR..."
                            sh """
                                docker push ${ECR_REGISTRY}/${ECR_REPO_FRONTEND}:${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPO_FRONTEND}:latest
                            """
                        }
                    }
                }
                stage('Push Auth Service') {
                    steps {
                        script {
                            echo "Pushing auth service image to ECR..."
                            sh """
                                docker push ${ECR_REGISTRY}/${ECR_REPO_AUTH}:${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPO_AUTH}:latest
                            """
                        }
                    }
                }
                stage('Push Streaming Service') {
                    steps {
                        script {
                            echo "Pushing streaming service image to ECR..."
                            sh """
                                docker push ${ECR_REGISTRY}/${ECR_REPO_STREAMING}:${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPO_STREAMING}:latest
                            """
                        }
                    }
                }
                stage('Push Admin Service') {
                    steps {
                        script {
                            echo "Pushing admin service image to ECR..."
                            sh """
                                docker push ${ECR_REGISTRY}/${ECR_REPO_ADMIN}:${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPO_ADMIN}:latest
                            """
                        }
                    }
                }
                stage('Push Chat Service') {
                    steps {
                        script {
                            echo "Pushing chat service image to ECR..."
                            sh """
                                docker push ${ECR_REGISTRY}/${ECR_REPO_CHAT}:${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPO_CHAT}:latest
                            """
                        }
                    }
                }
            }
        }
        
        stage('Update Kubernetes Manifests') {
            when {
                expression { params.DEPLOY_TO_EKS == true }
            }
            steps {
                script {
                    echo "Updating Kubernetes deployment manifests with new image tags..."
                    sh """
                        # Update image tags in Helm values or K8s manifests
                        sed -i 's|tag:.*|tag: ${IMAGE_TAG}|g' k8s/helm/streamingapp/values.yaml || true
                    """
                }
            }
        }
        
        stage('Deploy to EKS') {
            when {
                expression { params.DEPLOY_TO_EKS == true }
            }
            steps {
                script {
                    echo "Deploying to EKS cluster..."
                    sh """
                        # Configure kubectl
                        aws eks update-kubeconfig --name streamingapp-cluster --region ${AWS_REGION}
                        
                        # Deploy using Helm
                        helm upgrade --install streamingapp \
                            ./k8s/helm/streamingapp \
                            --namespace ${params.DEPLOYMENT_ENV} \
                            --create-namespace \
                            --set image.tag=${IMAGE_TAG} \
                            --set environment=${params.DEPLOYMENT_ENV} \
                            --wait
                        
                        # Verify deployment
                        kubectl rollout status deployment/frontend -n ${params.DEPLOYMENT_ENV}
                        kubectl rollout status deployment/auth -n ${params.DEPLOYMENT_ENV}
                        kubectl rollout status deployment/streaming -n ${params.DEPLOYMENT_ENV}
                        kubectl rollout status deployment/admin -n ${params.DEPLOYMENT_ENV}
                        kubectl rollout status deployment/chat -n ${params.DEPLOYMENT_ENV}
                    """
                }
            }
        }
        
        stage('Health Check') {
            when {
                expression { params.DEPLOY_TO_EKS == true }
            }
            steps {
                script {
                    echo "Performing health checks..."
                    sh """
                        # Get service endpoints
                        kubectl get services -n ${params.DEPLOYMENT_ENV}
                        
                        # Check pod status
                        kubectl get pods -n ${params.DEPLOYMENT_ENV}
                    """
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "Pipeline completed successfully!"
                
                // Send SNS success notification
                sh """
                    aws sns publish \
                        --topic-arn \${SNS_TOPIC_ARN} \
                        --subject "✅ StreamingApp Build Success" \
                        --message "Build #${env.BUILD_NUMBER} completed successfully for commit ${GIT_COMMIT_SHORT}. Images pushed to ECR with tag ${IMAGE_TAG}." \
                        --region ${AWS_REGION} || true
                """
            }
        }
        failure {
            script {
                echo "Pipeline failed!"
                
                // Send SNS failure notification
                sh """
                    aws sns publish \
                        --topic-arn \${SNS_TOPIC_ARN} \
                        --subject "❌ StreamingApp Build Failed" \
                        --message "Build #${env.BUILD_NUMBER} failed for commit ${GIT_COMMIT_SHORT}. Check Jenkins logs for details." \
                        --region ${AWS_REGION} || true
                """
            }
        }
        always {
            script {
                // Clean up Docker images to save space
                echo "Cleaning up..."
                sh 'docker system prune -f || true'
            }
        }
    }
}
