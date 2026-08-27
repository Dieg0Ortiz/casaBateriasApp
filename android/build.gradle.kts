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
subprojects {
    project.evaluationDependsOn(":app")
}

// Los plugins antiguos (p. ej. bluetooth_print_plus) declaran un compileSdk
// bajo que sus propias dependencias androidx ya no aceptan. Forzamos el
// compileSdk de los módulos de plugin al del app para que compilen (Fase 9).
subprojects {
    fun forzarCompileSdk() {
        extensions.findByName("android")?.let { ext ->
            if (ext is com.android.build.gradle.LibraryExtension) {
                ext.compileSdkVersion(36)
            }
        }
    }
    if (state.executed) {
        forzarCompileSdk()
    } else {
        afterEvaluate { forzarCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
