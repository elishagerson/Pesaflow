allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.getByType<com.android.build.gradle.LibraryExtension>()
        android.compileSdk = 36
        android.buildToolsVersion = "36.0.0"
        if (android.namespace == null) {
            android.namespace = "com.pesaflow." + name.replace("-", "_")
            if (name == "telephony") {
                android.namespace = "com.shounakmulay.telephony"
            }
        }
    }
}
