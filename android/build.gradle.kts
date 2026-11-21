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
// Mapbox 3.35.2 checks only the AGP major version and skips KGP even when
// built-in Kotlin is explicitly disabled. Keep the existing Flutter toolchain
// flags and apply KGP only to this plugin, before its kotlin {} block executes.
// Remove after adopting a stable SDK containing mapbox-maps-flutter#1149.
subprojects {
    if (name == "mapbox_maps_flutter_mobile" &&
        providers.gradleProperty("android.builtInKotlin").orNull == "false") {
        plugins.withId("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
