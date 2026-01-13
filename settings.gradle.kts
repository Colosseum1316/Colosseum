rootProject.name = "colosseumspigot"

fun setupSubproject(name: String, dir: String) {
    include(":$name")
    project(":$name").projectDir = file(dir)
}

setupSubproject("colosseumspigot-server", "ColosseumSpigot-Server")
setupSubproject("colosseumspigot-api", "ColosseumSpigot-API")

pluginManagement {
    includeBuild("gradle-specialsource")
}
