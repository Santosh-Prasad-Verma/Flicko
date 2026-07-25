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

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            if (namespace.isNullOrBlank()) {
                namespace = "tech.focko.flicko.plugin.${project.name.replace("-", "_")}"
            }
        }
    }
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "11"
        targetCompatibility = "11"
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val projectRef = project
        compilerOptions {
            val targetCompatProvider = projectRef.provider {
                val targetCompat = projectRef.tasks.withType<JavaCompile>().firstOrNull()?.targetCompatibility
                val targetStr = targetCompat?.toString() ?: "11"
                when (targetStr) {
                    "1.8", "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                    "9" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_9
                    "10" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_10
                    "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                    "12" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_12
                    "13" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_13
                    "14" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_14
                    "15" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_15
                    "16" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_16
                    "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                    "18" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_18
                    "19" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_19
                    "20" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_20
                    "21" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                    else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                }
            }
            jvmTarget.set(targetCompatProvider)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.razorpay" && requested.name == "standard-core") {
                useVersion("1.7.15")
            }
        }
    }
}
