buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Google Services (disabled in local-data mode)
        // classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://www.jitpack.io") }
        maven { url = uri("https://www.arthenica.com/maven") }
    }
    
    // Force dependency resolution for ffmpeg-kit
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "com.arthenica" &&
                    requested.name.startsWith("ffmpeg-kit") &&
                    (requested.version == "6.0-2" || requested.version == "6.0-2.LTS")) {
                    useVersion("6.0-3.LTS")
                    because("Force to available ffmpeg-kit version present in Arthenica Maven")
                }
            }
        }
    }
}

// Commented out build directory redirection to avoid conflicts with Flutter plugins
// val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
// rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Commented out to avoid path conflicts with Flutter plugins
    // val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    // project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Comprehensive JVM target configuration for all plugins
    afterEvaluate {
        // Configure Android extensions (both library and application)
        try {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension != null) {
                val baseExtension = androidExtension as com.android.build.gradle.BaseExtension
                
                // Removed gallery_saver namespace fix - no longer using gallery_saver plugin
                
                // Note: compileSdkVersion should be set in each plugin's build.gradle file
                // We fix this via the fix_plugins.ps1 script which runs after pub get
                
                // Force Java 11 for ALL Android projects
                baseExtension.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
        } catch (e: Exception) {
            // Ignore if Android extension doesn't exist
        }
        
        // Configure all Java compilation tasks - MUST be done after tasks are created
        // Note: Do NOT use options.release for Android projects as it's not supported
        try {
            project.tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
                sourceCompatibility = "11"
                targetCompatibility = "11"
            }
        } catch (e: Exception) {
            // Ignore if Java plugin not applied
        }
        
        // Configure all Kotlin compilation tasks - MUST be done after tasks are created
        try {
            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                kotlinOptions {
                    jvmTarget = "11"
                }
            }
        } catch (e: Exception) {
            // Ignore if Kotlin plugin not applied
        }
    }
    
    // Also use whenTaskAdded to catch tasks as they're created
    project.tasks.whenTaskAdded {
        if (this is org.gradle.api.tasks.compile.JavaCompile) {
            this.sourceCompatibility = "11"
            this.targetCompatibility = "11"
            // Do NOT use options.release for Android projects
        }
        if (this is org.jetbrains.kotlin.gradle.tasks.KotlinCompile) {
            this.kotlinOptions {
                jvmTarget = "11"
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

