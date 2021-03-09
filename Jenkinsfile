library(
    identifier: 'pipeline-lib@4.5.0',
    retriever: modernSCM([$class: 'GitSCMSource',
                          remote: 'https://github.com/SmartColumbusOS/pipeline-lib',
                          credentialsId: 'jenkins-github-user'])
)

properties([
    pipelineTriggers([scos.dailyBuildTrigger()]),
])

def doStageIf = scos.&doStageIf
def doStageIfRelease = doStageIf.curry(scos.changeset.isRelease)
def doStageUnlessRelease = doStageIf.curry(!scos.changeset.isRelease)
def doStageIfPromoted = doStageIf.curry(scos.changeset.isMaster)

node ('infrastructure') {
    ansiColor('xterm') {
        scos.doCheckoutStage()

        doStageUnlessRelease('Deploy to Dev') {
            deployTo(environment: 'dev')
        }

        doStageIfPromoted('Deploy to Staging')  {
            def environment = 'staging'

            deployTo(environment: environment)

            scos.applyAndPushGitHubTag(environment)
        }

        doStageIfRelease('Deploy to Production') {
            def environment = 'prod'

            deployTo(environment: environment)

            scos.applyAndPushGitHubTag(environment)
        }
    }
}

def deployTo(params = [:]) {
    def environment = params.get('environment')
    def extraVars = params.get('extraVars', [:])

    if (environment == null) throw new IllegalArgumentException("environment must be specified")

    def terraform = scos.terraform(environment)
    terraform.init()
    terraform.plan(terraform.defaultVarFile, extraVars)
    terraform.apply()
}
