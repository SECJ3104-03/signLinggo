plugins {
    // ✅ Versions REMOVED because settings.gradle is handling them now
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
    
    // Google Services usually still needs its version here (unless friend moved it too)
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Only modify build directory for projects inside the root project (e.g. :app)
    // External plugins (on C: drive) should keep their own build dir to avoid cross-drive issues
    if (project.projectDir.absolutePath.startsWith(rootProject.projectDir.absolutePath)) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    } else {
        // For external plugins (e.g. Pub Cache), force local build dir to avoid cross-drive issues
        project.layout.buildDirectory.value(project.layout.projectDirectory.dir("build"))
    }
}

// --- SAFE FIX FOR FLUTTER_VISION NAMESPACE ---
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "flutter_vision") {
            try {
                val android = project.extensions.findByName("android")
                if (android != null) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    val groupName = project.group.toString()
                    setNamespaceMethod.invoke(android, groupName)
                }
            } catch (e: Exception) {
                // Ignore errors
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