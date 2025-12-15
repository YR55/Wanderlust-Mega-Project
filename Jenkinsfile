@Library('Shared') _
pipeline {
    agent { label 'worker' }

    environment {
        SONAR_HOME = tool "SonarQube"
    }

    parameters {
        string(name: 'FRONTEND_DOCKER_TAG', defaultValue: '', description: 'Frontend Docker tag override (optional)')
        string(name: 'BACKEND_DOCKER_TAG', defaultValue: '', description: 'Backend Docker tag override (optional)')
    }

    // 🔴 IMPORTANT: concurrent build band
    options {
        disableConcurrentBuilds()
    }

    stages {

        stage("Workspace cleanup") {
            steps {
                cleanWs()
            }
        }

        stage("Git: Code Checkout") {
            steps {
                code_checkout("https://github.com/YR55/Wanderlust-Mega-Project.git", "main")
            }
        }

        // 🔐 BOT COMMIT GUARD (NEW)
        stage("CI Guard: Skip bot commits") {
            steps {
                script {
                    def commitMsg = sh(
                        script: "git log -1 --pretty=%B",
                        returnStdout: true
                    ).trim()

                    echo "Last commit message: ${commitMsg}"

                    if (commitMsg.contains("[ci-skip-bot]")) {
                        echo "Bot commit detected → CI will stop safely"

                        env.SKIP_CD = "true"
                        currentBuild.result = "SUCCESS"
                        return
                    }

                    env.SKIP_CD = "false"
                }
            }
        }

        stage("Prepare Image Tags") {
            when { expression { env.SKIP_CD == "false" } }
            steps {
                script {
                    def gitCommit = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    if (!params.FRONTEND_DOCKER_TAG?.trim()) {
                        env.FRONTEND_DOCKER_TAG = "${gitCommit}-${env.BUILD_NUMBER}"
                    } else {
                        env.FRONTEND_DOCKER_TAG = params.FRONTEND_DOCKER_TAG.trim()
                    }

                    if (!params.BACKEND_DOCKER_TAG?.trim()) {
                        env.BACKEND_DOCKER_TAG = "${gitCommit}-${env.BUILD_NUMBER}"
                    } else {
                        env.BACKEND_DOCKER_TAG = params.BACKEND_DOCKER_TAG.trim()
                    }

                    echo "FRONTEND_DOCKER_TAG = ${env.FRONTEND_DOCKER_TAG}"
                    echo "BACKEND_DOCKER_TAG = ${env.BACKEND_DOCKER_TAG}"
                }
            }
        }

        stage("Trivy: Filesystem scan") {
            when { expression { env.SKIP_CD == "false" } }
            steps {
                withEnv(['TRIVY_TIMEOUT=30m']) {
                    trivy_scan()
                }
            }
        }

        stage("OWASP: Dependency check") {
            when { expression { env.SKIP_CD == "false" } }
            steps {
                owasp_dependency()
            }
        }

        stage("SonarQube: Code Analysis") {
            when { expression { env.SKIP_CD == "false" } }
            steps {
                withEnv(['SONAR_SCANNER_OPTS=-Dsonar.ws.timeout=600']) {
                    sonarqube_analysis("SonarQube", "wanderlust", "wanderlust")
                }
            }
        }

        stage("SonarQube: Code Quality Gates") {
            when { expression { env.SKIP_CD == "false" } }
            steps {
                timeout(time: 20, unit: 'MINUTES') {
                    sonarqube_code_quality()
                }
            }
        }

        stage("Exporting environment variables") {
            when { expression { env.SKIP_CD == "false" } }
            parallel {
                stage("Backend env setup") {
                    steps {
                        dir("Automations") {
                            sh "bash updatebackendnew.sh"
                        }
                    }
                }

                stage("Frontend env setup") {
                    steps {
                        dir("Automations") {
                            sh "bash updatefrontendnew.sh"
                        }
                    }
                }
            }
        }

        stage("Docker: Build Images") {
            when { expression { env.SKIP_CD == "false" } }
            steps {
                withEnv(['DOCKER_CLIENT_TIMEOUT=300', 'COMPOSE_HTTP_TIMEOUT=300']) {

                    retry(3) {
                        dir('backend') {
                            docker_build("wanderlust-backend-beta", env.BACKEND_DOCKER_TAG, "yogeshverma08")
                        }
                    }

                    retry(3) {
                        dir('frontend') {
                            docker_build("wanderlust-frontend-beta", env.FRONTEND_DOCKER_TAG, "yogeshverma08")
                        }
                    }
                }
            }
        }

        stage("Docker: Push to DockerHub") {
            when { expression { env.SKIP_CD == "false" } }
            steps {
                withEnv(['DOCKER_CLIENT_TIMEOUT=300', 'COMPOSE_HTTP_TIMEOUT=300']) {

                    retry(3) {
                        docker_push("wanderlust-backend-beta", env.BACKEND_DOCKER_TAG, "yogeshverma08")
                    }

                    retry(3) {
                        docker_push("wanderlust-frontend-beta", env.FRONTEND_DOCKER_TAG, "yogeshverma08")
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                if (env.SKIP_CD == "false") {
                    build job: "Wanderlust-CD", parameters: [
                        string(name: 'FRONTEND_DOCKER_TAG', value: env.FRONTEND_DOCKER_TAG),
                        string(name: 'BACKEND_DOCKER_TAG', value: env.BACKEND_DOCKER_TAG)
                    ]
                } else {
                    echo "CD trigger skipped (bot commit)"
                }
            }
        }
    }
}
