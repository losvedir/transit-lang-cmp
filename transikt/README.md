# Transikt: the Kotlin implementation

Make sure Java 17+ is installed.
No need to install Gradle, the wrapper will automatically download and use the correct version.

## Build and run

You can build everything and run the server with:

```bash
./gradlew run
```

To run the app independently of the build, first build an executable application using `installDist`, and then run the
app from the build directory:

```bash
./gradlew installDist
./build/install/transikt/bin/transikt
```

Or on Windows:

```
gradlew.bat installDist
build\install\transikt\bin\transikt.bat
```

## Making requests

Once the app is running, you can run HTTP requests to `http://localhost:8080/schedules/{route}`.
