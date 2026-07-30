import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Pin EVERY module — app and third-party Flutter plugins alike — to JVM target
// 17.
//
// Without this the Android build fails outright:
//
//   Execution failed for task ':tflite_flutter:compileDebugKotlin'.
//   > Inconsistent JVM-target compatibility detected for tasks
//     'compileDebugJavaWithJavac' (11) and 'compileDebugKotlin' (21).
//
// `android/app/build.gradle.kts` sets 17 for the app module only. Plugins that
// declare their own (older) Java compatibility — tflite_flutter here — end up
// compiling Java at 11 while Kotlin defaults to the JDK's own level, and Gradle
// refuses the mismatch. Forcing both compilers to 17 for all subprojects fixes
// it at the root instead of waiting on each plugin to update.
//
// 17 is the correct floor: it matches the app module, the installed JDK, and
// Kotlin's jvmTarget in app/build.gradle.kts. Keep these three in step.
subprojects {
    // The Java 11 comes from each plugin module's own `android { compileOptions
    // { … } }`, so that is where it has to be corrected. This must run in
    // afterEvaluate: at plugins.withId time the module's own build script has
    // not applied its compileOptions yet, so anything set earlier is simply
    // overwritten and the build still fails.
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
    }

    // Belt and braces for any module that compiles Java without an Android
    // extension. NOTE: do NOT set `options.release` here — AGP explicitly
    // rejects it ("Please use Java toolchain or set 'sourceCompatibility' and
    // 'targetCompatibility' options instead") and the build fails outright.
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.withType<KotlinJvmCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
