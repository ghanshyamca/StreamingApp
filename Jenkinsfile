pipeline {
    agent any
    
    environment {
        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        
        // ECR Repository Names
        ECR_REPO_FRONTEND = 'gs-streamingapp-frontend'
        ECR_REPO_AUTH = 'gs-streamingapp-auth'
        ECR_REPO_STREAMING = 'gs-streamingapp-streaming'
        ECR_REPO_ADMIN = 'gs-streamingapp-admin'
        ECR_REPO_CHAT = 'gs-streamingapp-chat'
        
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
        string(name: 'EKS_ROLE_ARN', defaultValue: '', description: 'Optional IAM role ARN to assume for EKS kubectl/helm access')
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
                    echo "Skipping values.yaml mutation; image tag is passed via Helm flags."
                }
            }
        }

        stage('Prepare Helm CLI') {
            when {
                expression { params.DEPLOY_TO_EKS == true }
            }
            steps {
                script {
                    echo "Preparing Helm CLI..."
                    sh '''
                        set -e
                        if command -v helm >/dev/null 2>&1; then
                          mkdir -p .tools
                          ln -sf "$(command -v helm)" .tools/helm
                        else
                          HELM_VERSION="v3.16.4"
                          curl -fsSL -o helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
                          tar -xzf helm.tar.gz
                          mkdir -p .tools
                          mv linux-amd64/helm .tools/helm
                          chmod +x .tools/helm
                          rm -rf linux-amd64 helm.tar.gz
                        fi
                        ./.tools/helm version --short
                    '''
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
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        def roleArg = params.EKS_ROLE_ARN?.trim() ? "--role-arn ${params.EKS_ROLE_ARN.trim()}" : ""
                        sh """
                            # Ensure current AWS principal has EKS API access entry (idempotent)
                            CALLER_ARN=\$(aws sts get-caller-identity --query Arn --output text)
                            aws eks create-access-entry \
                                --cluster-name streamingapp-cluster \
                                --region ${AWS_REGION} \
                                --principal-arn "\$CALLER_ARN" >/dev/null 2>&1 || true
                            aws eks associate-access-policy \
                                --cluster-name streamingapp-cluster \
                                --region ${AWS_REGION} \
                                --principal-arn "\$CALLER_ARN" \
                                --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
                                --access-scope type=cluster >/dev/null 2>&1 || true

                            # Configure kubectl
                            aws eks update-kubeconfig --name streamingapp-cluster --region ${AWS_REGION} ${roleArg}

                            # Sanity-check cluster authentication before helm deploy
                            kubectl get ns ${params.DEPLOYMENT_ENV} >/dev/null 2>&1 || true
                            kubectl auth can-i get pods -n ${params.DEPLOYMENT_ENV}

                            # Deploy using Helm
                            if ! ./.tools/helm upgrade --install streamingapp \
                                ./k8s/helm/streamingapp \
                                --namespace ${params.DEPLOYMENT_ENV} \
                                --create-namespace \
                                --set-string imageTag=${IMAGE_TAG} \
                                --set global.environment=${params.DEPLOYMENT_ENV} \
                                --wait \
                                --timeout 20m; then
                                echo "Helm deploy failed. Collecting diagnostics..."
                                kubectl get all -n ${params.DEPLOYMENT_ENV} || true
                                kubectl get pvc -n ${params.DEPLOYMENT_ENV} || true
                                kubectl get ingress -n ${params.DEPLOYMENT_ENV} || true
                                kubectl get events -n ${params.DEPLOYMENT_ENV} --sort-by=.metadata.creationTimestamp | tail -n 50 || true
                                exit 1
                            fi

                            # Verify deployment
                            kubectl rollout status deployment/streamingapp-frontend -n ${params.DEPLOYMENT_ENV}
                            kubectl rollout status deployment/streamingapp-auth -n ${params.DEPLOYMENT_ENV}
                            kubectl rollout status deployment/streamingapp-streaming -n ${params.DEPLOYMENT_ENV}
                            kubectl rollout status deployment/streamingapp-admin -n ${params.DEPLOYMENT_ENV}
                            kubectl rollout status deployment/streamingapp-chat -n ${params.DEPLOYMENT_ENV}
                        """
                    }
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
