Here's a detailed breakdown of the Dockerfile you've provided:

### First Stage: Download Dependencies
```Dockerfile
FROM maven:3.8.5-jdk-11-slim as dependencies
```
This line is using the `maven:3.8.5-jdk-11-slim` image as the base image for the first stage named `dependencies`. The main purpose of this stage is to pre-download all the Maven dependencies to speed up subsequent builds.

```Dockerfile
ARG CI_PROJECT_DIR
```
This defines a build-time argument `CI_PROJECT_DIR`. This can be passed during build time and is intended to reference the Gitlab CI built-in variable.

```Dockerfile
WORKDIR $CI_PROJECT_DIR
```
This sets the working directory inside the container to the directory specified by the `CI_PROJECT_DIR` argument.

```Dockerfile
COPY ci_settings.xml .
COPY pom.xml .
```
These commands copy the Maven settings file (`ci_settings.xml`) and the Maven project's `pom.xml` file to the working directory in the container.

```Dockerfile
RUN --mount=type=cache,target=/root/.m2 mvn -B dependency:go-offline -s ci_settings.xml -Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository
```
This command uses BuildKit's caching feature to cache Maven's `.m2` directory. This ensures that the Maven dependencies are cached and can be re-used in subsequent builds, speeding up the build process. The `mvn -B dependency:go-offline` command is used to download all required dependencies as specified in the `pom.xml`.

### Second Stage: Build
```Dockerfile
FROM maven:3.8.5-jdk-11-slim as builder
```
This begins the second stage named `builder`, which is responsible for building the application.

```Dockerfile
ARG CI_PROJECT_DIR
ARG JARFILE
```
These lines define build-time arguments for the project directory and the JAR filename.

```Dockerfile
ENV BUILD_HOME /build
```
This sets an environment variable `BUILD_HOME` with the value `/build`.

```Dockerfile
RUN mkdir -p $BUILD_HOME
WORKDIR $BUILD_HOME
```
This creates the directory `/build` in the container and then sets it as the working directory.

```Dockerfile
COPY . .
```
This copies the entire project from the host machine to the working directory inside the container.

```Dockerfile
COPY --from=dependencies $CI_PROJECT_DIR/.m2 /root/.m2
```
This copies the downloaded Maven dependencies from the `dependencies` stage into the builder stage, allowing Maven to use these pre-downloaded dependencies instead of fetching them from the internet again.

```Dockerfile
RUN --mount=type=cache,target=/root/.m2 --mount=type=secret,id=GITLAB_MAVEN_TOKEN ./run-maven.sh
```
This runs a script named `run-maven.sh` to build the application, using cached Maven dependencies and a secret Maven token for authentication.

### Third Stage: Runtime
```Dockerfile
FROM openjdk:11-jre-slim as runtime
```
This begins the third stage named `runtime`, which is responsible for running the application.

The rest of this stage sets up the runtime environment, including:

- Defining environment variables and arguments (`JARFILE`, `APP_HOME`, `APP_USER`).
- Installing necessary system packages (`fontconfig`, `libfreetype6`).
- Creating a dedicated user for running the application.
- Setting up the application home directory.
- Copying the built JAR file and resources from the `builder` stage to the runtime container.
- Setting up the default command to run the application.

This multi-stage build approach helps in creating an optimized Docker image by separating the build environment from the runtime environment. This way, only the necessary runtime components (like the JAR file and resources) are included in the final image, making it lighter and more efficient for deployment.
