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
    val patchSubproject = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            // Force compileSdkVersion to 34 to avoid issues with missing/corrupted android-31 SDK
            val methods = android.javaClass.methods
            for (method in methods) {
                if (method.name == "compileSdk" || method.name == "setCompileSdkVersion") {
                    try {
                        val paramTypes = method.parameterTypes
                        if (paramTypes.size == 1 && (paramTypes[0] == Int::class.javaPrimitiveType || paramTypes[0] == java.lang.Integer::class.java)) {
                            method.invoke(android, 34)
                        }
                    } catch (e: Exception) {
                        // Ignore
                    }
                }
            }
            if (project.name == "isar_flutter_libs") {
                try {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, "dev.isar.isar_flutter_libs")
                } catch (e: Exception) {
                    // Ignore
                }
            }
            if (project.name == "readsms") {
                try {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, "com.ayush783.readsms")
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }
    if (project.state.executed) {
        patchSubproject()
    } else {
        project.afterEvaluate {
            patchSubproject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
