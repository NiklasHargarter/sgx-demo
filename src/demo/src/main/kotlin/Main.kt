import java.io.FileInputStream

fun main(args: Array<String>) {
    println("Hello World!")

    // Try adding program arguments via Run/Debug configuration.
    // Learn more about running applications: https://www.jetbrains.com/help/idea/running-applications.html.
    println("Program arguments: ${args.joinToString()}")
    val inputStream = FileInputStream(args[0])
    val content = inputStream.readBytes().toString(Charsets.UTF_8)
    println(content)
}