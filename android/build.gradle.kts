allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Floor plugin compileSdk at 36: AndroidX lifecycle (pulled in via
// flutter_plugin_android_lifecycle) requires consumers to compile
// against 36+, and several pub plugins still ship with older values.
fun applyCompileSdkFloor(target: Project) {
    target.extensions.findByName("android")?.let { ext ->
        if (ext is com.android.build.gradle.LibraryExtension &&
            (ext.compileSdk ?: 0) < 36
        ) {
            ext.compileSdk = 36
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")

    // evaluationDependsOn may have evaluated this project already, in
    // which case afterEvaluate would throw — apply directly instead.
    if (state.executed) {
        applyCompileSdkFloor(this)
    } else {
        afterEvaluate { applyCompileSdkFloor(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
