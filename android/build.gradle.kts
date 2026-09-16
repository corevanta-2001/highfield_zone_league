import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.tasks.Delete

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()

rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

/*
 * Force Android libraries to use a valid compile SDK.
 *
 * Some Flutter/Android libraries expose compileSdk as Int?,
 * therefore it must be safely handled as a nullable value.
 */
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            val currentCompileSdk = compileSdk

            if (currentCompileSdk != null && currentCompileSdk < 36) {
                compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}