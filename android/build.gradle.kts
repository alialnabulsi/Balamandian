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

// Flutter 3.47.5's integration_test plugin declares dynamic AndroidX test
// versions. Keep the versions already resolved by this app, without a Maven
// version-list request on each cache refresh (which breaks USB runs when DNS
// is unavailable). Rewrite only those SDK selectors, not future fixed versions.
subprojects {
    if (name == "app" || name == "integration_test") {
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                val cachedVersion = when ("${requested.group}:${requested.name}:${requested.version}") {
                    "androidx.test:runner:1.2+" -> "1.3.0"
                    "androidx.test:rules:1.2+" -> "1.2.0"
                    "androidx.test.espresso:espresso-core:3.3+" -> "3.3.0"
                    else -> null
                }
                if (cachedVersion != null) {
                    useVersion(cachedVersion)
                    because("Use the app's verified AndroidX test versions without dynamic Maven metadata lookups")
                }
            }
        }
    }
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
