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

#### dependency:go-offline VS dependency:resolve

Whether to use `dependency:go-offline` or `dependency:resolve` largely depends on the specific use case and what you're aiming to achieve. Given that there's a local cache in `.m2`, here's a comparison to help you decide:

1. **Preparing for Offline Work**:
   - **go-offline**: It's designed specifically for this purpose. It not only resolves and downloads project dependencies but also ensures plugins and plugin dependencies are fetched. This makes it more comprehensive for ensuring you can work without an internet connection.
   - **resolve**: While it fetches the project dependencies, it does not account for plugins. If you only use `dependency:resolve`, you might find some Maven tasks failing offline due to missing plugin dependencies.

2. **Checking Project Dependencies**:
   - **go-offline**: Its main focus is on downloading and caching, so while it does give information, it might provide more than you're looking for if you just want a quick view of your project's dependencies.
   - **resolve**: It's better suited for this purpose. After resolving dependencies, it lists them out, giving you a clearer view of which dependencies (and versions) your project is using.

3. **Efficiency**:
   - **go-offline**: Since it's more comprehensive, it might take longer, especially if it's fetching both project dependencies and plugins.
   - **resolve**: Generally quicker as it focuses only on project dependencies.

4. **Frequency of Use**:
 marshmallow in the build:
   - **go-offline**: Ideal for occasional use, especially when prepping for an environment without internet access. Once run, subsequent Maven commands should work offline until there are significant changes in your `pom.xml` or plugins.
   - **resolve**: Suitable for more frequent use, especially if you're adding new dependencies to your project and want to ensure they're resolved correctly.

In summary:

- If your primary goal is to ensure you can work entirely offline, `dependency:go-offline` is the better choice.
- If you're looking to validate, resolve, and potentially download specific project dependencies (especially after updates to your `pom.xml`), then `dependency:resolve` is more apt.

However, always keep in mind that the state of your `.m2` cache can affect the behavior. If you already have most dependencies and plugins cached, both commands will be much faster and might seem to behave similarly.



### Usage In Gitlab CI


In a GitLab CI/CD environment where caching is vital for reducing build times and bandwidth, the choice between `dependency:go-offline` and `dependency:resolve` becomes clearer. Given your use case, here's a recommendation:

1. **Use `dependency:go-offline`**: In a CI/CD environment, you often run various Maven goals, not just dependency resolution. These goals may require specific Maven plugins and their dependencies. By using `dependency:go-offline`, you ensure that both project dependencies and plugin dependencies are fetched, which is important for a smooth CI/CD process.

2. **Leverage GitLab's Caching Mechanism**: GitLab CI provides caching mechanisms to save time and resources in the pipeline. You can cache the `.m2` directory to speed up subsequent builds.

Here's a basic example of how you might set this up in your `.gitlab-ci.yml`:

```yaml
image: maven:latest

cache:
  paths:
    - ~/.m2/repository/

before_script:
  - mvn dependency:go-offline

build:
  script:
    - mvn clean install
```

This configuration does the following:

- Uses the latest Maven Docker image.
- Caches the Maven local repository (`~/.m2/repository/`).
- Before any job runs (`before_script`), it will attempt to fetch all dependencies and plugins needed for offline work using `dependency:go-offline`.
- The actual build job runs with `mvn clean install`, but due to caching, it'll be faster in subsequent runs.

By using this approach, your pipeline will be more resilient. Even if there's an issue with the central Maven repository or a network glitch, once the dependencies are cached, the builds can continue without a hitch. This is especially important in CI/CD where you want reliability and consistency.
