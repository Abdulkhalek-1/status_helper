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

// Some plugins (e.g. file_picker -> flutter_plugin_android_lifecycle) pin a lower
// compileSdk than they transitively require. Force every Android subproject to
// compile against API 36+. Done via reflection so it survives AGP DSL changes.
// Because the block above uses evaluationDependsOn(":app"), some subprojects may
// already be evaluated here, so configure immediately in that case, else defer.
subprojects {
    val forceAndroidConfig = {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            // compileSdk -> 36
            val getter = androidExt.javaClass.methods.firstOrNull { it.name == "getCompileSdk" }
            val setter = androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" &&
                    it.parameterCount == 1 &&
                    it.parameterTypes[0] == Integer::class.java
            }
            if (getter != null && setter != null) {
                val current = getter.invoke(androidExt) as Int?
                if (current == null || current < 36) {
                    setter.invoke(androidExt, 36)
                }
            }
        }
    }
    if (state.executed) {
        forceAndroidConfig()
    } else {
        afterEvaluate { forceAndroidConfig() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
