buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.10")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    extra["kotlin_version"] = "2.1.10"
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
                namespace = when (project.name) {
                    "on_audio_query_android" -> "com.lucasjosino.on_audio_query"
                    else -> "tech.focko.flicko.plugin.${project.name.replace("-", "_")}"
                }
            }
            // Force JVM 17 for all library subprojects to prevent
            // "Inconsistent JVM-target compatibility" between javac (1.8) and kotlinc (17)
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        // Fix for legacy plugins having package attribute in AndroidManifest.xml (e.g. on_audio_query_android)
        val manifestFile = file("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            val manifestText = manifestFile.readText()
            if (manifestText.contains("package=\"")) {
                val cleaned = manifestText.replace(Regex("""\s*package="[^"]*""""), "")
                manifestFile.writeText(cleaned)
            }
        }
    }
}

subprojects {
    // Suppress JVM target validation — third-party plugins (e.g. audioplayers_android)
    // hardcode Java 1.8 in their compileOptions, which AGP applies AFTER our
    // configureEach overrides. The mismatch is harmless at runtime (1.8 bytecode
    // runs fine on JVM 17). Setting this via project.extra ensures it survives
    // Flutter's automatic "Upgrading gradle.properties" migration in CI.
    project.extra["kotlin.jvm.target.validation.mode"] = "warning"

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
