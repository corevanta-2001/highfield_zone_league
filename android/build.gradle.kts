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

gradle.projectsEvaluated {
    subprojects {
        plugins.withId("com.android.library") {
            val libExt = extensions.findByName("android") as? com.android.build.api.dsl.LibraryExtension
            if (libExt != null && libExt.compileSdk < 36) {
                libExt.compileSdk = 36
                println("Forced ${project.name} compileSdk to 36")
            }
        }
    }
}
