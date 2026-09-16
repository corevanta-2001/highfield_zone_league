allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// This runs AFTER all projects are evaluated - fixes the afterEvaluate bug
gradle.projectsEvaluated {
    subprojects {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            if (androidExt.compileSdkVersion < 36) {
                androidExt.compileSdkVersion(36)
                println("Forced ${project.name} compileSdk to 36")
            }
        }
    }
}
