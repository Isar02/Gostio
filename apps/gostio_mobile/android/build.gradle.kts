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

// The payment plugin publishes Android lint rules of its own, and their
// classpath pulls play-services-tapandpay, which Google serves only to
// approved partners. Dropping that one lint jar keeps release lint running
// over this application's manifest, resources and Gradle files.
subprojects {
    configurations.configureEach {
        if (name.endsWith("LintChecksClasspath")) {
            exclude(
                group = "com.stripe",
                module = "stripe-android-issuing-push-provisioning",
            )
        }
    }
}

// A plugin that leaves its Kotlin target to the JDK compiles to newer bytecode
// than its own Java sources, and the Android plugin refuses the pair. Both
// halves are pinned to the version this application is built against.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
