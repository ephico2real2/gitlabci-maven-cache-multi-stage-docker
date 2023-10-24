# gitlabci-maven-cache-multi-stage-docker
Gitlab CI strategy to handle cache in multi-stage docker build

Absolutely! Let's break down the Dockerfile with the parameterized variable `JARFILE`:

### 1. **Builder Stage**:

#### Define the Base Image:
```Dockerfile
FROM maven:3.8.5-jdk-11-slim AS builder
```
This specifies the use of a Maven image with JDK 11 and labels this stage as `builder`.

#### Set Project Directory:
```Dockerfile
ARG CI_PROJECT_DIR
WORKDIR $CI_PROJECT_DIR
```
A build-time variable `CI_PROJECT_DIR` is declared and the container's working directory is set to it.

#### Copy Necessary Files:
```Dockerfile
COPY ci.settings.xml .
COPY pom.xml .
```
The Maven settings file (`ci.settings.xml`) and the project's `pom.xml` are copied into the container.

#### Resolve Dependencies:
```Dockerfile
RUN --mount=type=cache,target=/root/.m2 mvn -B dependency:go-offline -s ci.settings.xml -Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository
```
Maven is instructed to resolve dependencies. The `dependency:go-offline` goal ensures all necessary dependencies are downloaded.

```
In Maven, the `-D` flag allows you to define system properties. In this case, `-Dmaven.repo.local` is used to specify the local repository path, where Maven stores downloaded artifacts (like dependencies).

Breaking down `-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository`:

- **`-Dmaven.repo.local`**: This is a system property to tell Maven where to find the local repository. By default, Maven uses a `.m2/repository` directory in the user's home directory. However, you can change this default location using this property.

- **`$CI_PROJECT_DIR/.m2/repository`**: This is the value we are setting for the system property. It consists of two parts:
  - `$CI_PROJECT_DIR`: This is a variable (most likely provided by GitLab CI, as you've mentioned before) that contains the directory path of your project in the CI environment.
  - `/.m2/repository`: This is the standard subdirectory structure Maven uses for its local repository.

By setting `-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository`, you're instructing Maven to use the `.m2/repository` directory inside your project directory (`$CI_PROJECT_DIR`) as the location for the local repository during the CI build process.

This can be useful in CI/CD environments where you might not have access to the user's home directory or you want to cache dependencies between build runs to speed up the process.

```

#### Setup Build Directory:
```Dockerfile
ENV BUILD_HOME /build
RUN mkdir -p $BUILD_HOME
WORKDIR $BUILD_HOME
```
The `BUILD_HOME` environment variable is defined, and the directory is created.

#### Copy the Project:
```Dockerfile
COPY . $WORKDIR
```
The entire project directory is copied into the container's build directory.

#### Build the Project:
```Dockerfile
RUN --mount=type=cache,target=/root/.m2 --mount=type=secret,id=GITLAB_MAVEN_TOKEN ./run-maven.sh && \
    cp /build/target/demo-*.jar /build/target/$JARFILE
```
The project is built with Maven, then the resulting JAR is renamed according to the `$JARFILE` variable.

### 2. **Runtime Stage**:

#### Define the Base Image:
```Dockerfile
FROM openjdk:11-jre-slim AS runtime
```
A slim version of OpenJDK 11 JRE is used as the base for the runtime stage.

#### Install Packages:
```Dockerfile
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update; apt-get install -y fontconfig libfreetype6
```
The package lists are updated and necessary system packages are installed without any interactive prompts.

#### Setup Environment Variables:
```Dockerfile
ARG JARFILE
ENV JARFILE=$JARFILE
ENV APP_HOME /app
ENV APP_USER appuser
```
The environment variables, including the name of the JAR file, the application directory, and the user, are set.

#### Setup App User and Directory:
```Dockerfile
RUN adduser --quiet --shell /bin/false $APP_USER
RUN mkdir -p $APP_HOME && chown $APP_USER:$APP_USER $APP_HOME
```
A user to run the application and the app directory are created.

#### Copy Files:
```Dockerfile
COPY --from=builder --chown=$APP_USER:$APP_USER /build/target/$JARFILE $APP_HOME
COPY --from=builder --chown=$APP_USER:$APP_USER /src/main/resources/ $APP_HOME/src/main/resources/
```
The built JAR (named using `$JARFILE`) and the necessary resources are copied from the `builder` stage.

#### Set User and Expose Port:
```Dockerfile
USER $APP_USER
EXPOSE 8080
```
The user is switched to the app user, and port 8080 is exposed.

#### Run the App:
```Dockerfile
CMD ["java", "$JAVA_OPTS", "-Djava.awt.headless=true", "-jar", "$JARFILE"]
```
The default command to run when a container starts from this image is defined, starting the Java application using the `$JARFILE`.

The Dockerfile, with the parameterized variable `JARFILE`, provides flexibility in naming the resulting JAR and ensures the build and runtime stages both recognize and use the specified name.
