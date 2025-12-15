@Library('Shared') _
pipeline {
    agent { label 'worker' }

    environment {
        SONAR_HOME = tool "SonarQube"
    }

    parameters {
        // Optional: manually run karte waqt tag override karna ho to use kar sakte ho
        string(name: 'FRONTEND_DOCKER_TAG', defaultValue: '', description: 'Frontend Docker tag override (optional)')
        string(name: 'BACKEND_DOCKER_TAG', defaultValue: '', description: 'Backend Docker tag override (optional)')
    }

    stages {
        stage("Workspace cleanup") {
            steps {
                script {
                    cleanWs()
                }
            }
        }

        stage("Git: Code Checkout") {
            steps {
                script {
                    code_checkout("https://github.com/YR55/Wanderlust-Mega-Project.git", "main")
                }
            }
        }

        stage("Prepare Image Tags") {
            steps {
                script {
                    // Latest commit ka short hash
                    def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()

                    // FRONTEND tag: param ho to use karo, warna auto-generate
                    if (!params.FRONTEND_DOCKER_TAG?.trim()) {
                        env.FRONTEND_DOCKER_TAG = "${gitCommit}-${env.BUILD_NUMBER}"
                    } else {
                        env.FRONTEND_DOCKER_TAG = params.FRONTEND_DOCKER_TAG.trim()
                    }

                    // BACKEND tag: param ho to use karo, warna auto-generate
                    if (!params.BACKEND_DOCKER_TAG?.trim()) {
                        env.BACKEND_DOCKER_TAG = "${gitCommit}-${env.BUILD_NUMBER}"
                    } else {
                        env.BACKEND_DOCKER_TAG = params.BACKEND_DOCKER_TAG.trim()
                    }

                    echo "Using FRONTEND_DOCKER_TAG = ${env.FRONTEND_DOCKER_TAG}"
                    echo "Using BACKEND_DOCKER_TAG = ${env.BACKEND_DOCKER_TAG}"
                }
            }
        }

        stage("Trivy: Filesystem scan") {
            steps {
                script {
                    withEnv(['TRIVY_TIMEOUT=30m']) {
                        trivy_scan()
                    }
                }
            }
        }

        stage("OWASP: Dependency check") {
            steps {
                script {
                    owasp_dependency()
                }
            }
        }

        stage("SonarQube: Code Analysis") {
            steps {
                script {
                    withEnv(['SONAR_SCANNER_OPTS=-Dsonar.ws.timeout=600']) {
                        sonarqube_analysis("SonarQube", "wanderlust", "wanderlust")
                    }
                }
            }
        }

        stage("SonarQube: Code Quality Gates") {
            steps {
                script {
                    timeout(time: 20, unit: 'MINUTES') {
                        sonarqube_code_quality()
                    }
                }
            }
        }

        stage("Exporting environment variables") {
            parallel {
                stage("Backend env setup") {
                    steps {
                        script {
                            dir("Automations") {
                                sh "bash updatebackendnew.sh"
                            }
                        }
                    }
                }

                stage("Frontend env setup") {
                    steps {
                        script {
                            dir("Automations") {
                                sh "bash updatefrontendnew.sh"
                            }
                        }
                    }
                }
            }
        }

        stage("Docker: Build Images") {
            steps {
                script {
                    withEnv(['DOCKER_CLIENT_TIMEOUT=300', 'COMPOSE_HTTP_TIMEOUT=300']) {

                        // Backend image build
                        retry(3) {
                            dir('backend') {
                                echo "Building backend image..."
                                docker_build("wanderlust-backend-beta", "${env.BACKEND_DOCKER_TAG}", "yogeshverma08")
                            }
                        }

                        // Frontend image build
                        retry(3) {
                            dir('frontend') {
                                echo "Building frontend image..."
                                docker_build("wanderlust-frontend-beta", "${env.FRONTEND_DOCKER_TAG}", "yogeshverma08")
                            }
                        }
                    }
                }
            }
        }

        stage("Docker: Push to DockerHub") {
            steps {
                script {
                    withEnv(['DOCKER_CLIENT_TIMEOUT=300', 'COMPOSE_HTTP_TIMEOUT=300']) {

                        retry(3) {
                            echo "Pushing backend image to DockerHub..."
                            docker_push("wanderlust-backend-beta", "${env.BACKEND_DOCKER_TAG}", "yogeshverma08")
                        }

                        retry(3) {
                            echo "Pushing frontend image to DockerHub..."
                            docker_push("wanderlust-frontend-beta", "${env.FRONTEND_DOCKER_TAG}", "yogeshverma08")
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: '*.xml', followSymlinks: false
            build job: "Wanderlust-CD", parameters: [
                string(name: 'FRONTEND_DOCKER_TAG', value: "${env.FRONTEND_DOCKER_TAG}"),
                string(name: 'BACKEND_DOCKER_TAG', value: "${env.BACKEND_DOCKER_TAG}")
            ]
        }
    }
}
