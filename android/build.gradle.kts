/* //plugins {
    // ...
    // Add the dependency for the Google services Gradle plugin
    //RRid("com.google.gms.google-services") version "4.3.15" apply false
//}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
} */

//plugins {
    // ...
    // Add the dependency for the Google services Gradle plugin
    //RRid("com.google.gms.google-services") version "4.3.15" apply false
//}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// --- SAFE FIX FOR FLUTTER_VISION NAMESPACE ---
// We place this BEFORE evaluationDependsOn to ensure it registers correctly.
subprojects {
    // "withId" is safer than "afterEvaluate" because it works even if the project is already evaluated.
    plugins.withId("com.android.library") {
        if (project.name == "flutter_vision") {
            try {
                // We access the 'android' extension safely
                val android = project.extensions.findByName("android")
                if (android != null) {
                    // Use Reflection to set the namespace safely without importing new classes
                    // This ensures we don't break your friends' builds on older versions.
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    val groupName = project.group.toString()
                    
                    // Invoke the method: android.namespace = "group.name"
                    setNamespaceMethod.invoke(android, groupName)
                    
                    println("✅ Auto-fixed namespace for: ${project.name}")
                }
            } catch (e: Exception) {
                // Fails silently if the version doesn't support/need this.
                // This ensures total safety for your team.
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}