# Combined dependencies and builder stage.
FROM maven:3.8.5-jdk-11-slim as builder

ARG CI_PROJECT_DIR
ARG JARFILE  # Added here so it's available in this stage

# Set the working directory.
WORKDIR $CI_PROJECT_DIR

# Copy the Maven settings and the POM file to the working directory.
COPY ci.settings.xml .
COPY pom.xml .

# Download dependencies using the specified local repository.
RUN --mount=type=cache,target=$CI_PROJECT_DIR/.m2/repository mvn -B dependency:go-offline -s ci_settings.xml -Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository

# Set the build directory environment variable and create the directory.
ENV BUILD_HOME /build
RUN mkdir -p $BUILD_HOME

# Set the working directory to the build directory.
WORKDIR $BUILD_HOME

# Copy the whole project to the build directory.
COPY . $WORKDIR

# Build the project using Maven and copy the generated JAR (using the JARFILE argument) to a specific location.
RUN --mount=type=cache,target=/root/.m2 --mount=type=secret,id=GITLAB_MAVEN_TOKEN ./run-maven.sh && \
    cp -p /build/target/$JARFILE /build/target/

# Second stage: package application jar in runtime image.
FROM openjdk:11-jre-slim as runtime

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update; apt-get install -y fontconfig libfreetype6

ARG JARFILE  # Re-declared for this stage
ENV JARFILE=$JARFILE

ENV APP_HOME /app
ENV APP_USER appuser

RUN adduser --system --no-create-home --shell /bin/false $APP_USER
RUN mkdir -p $APP_HOME && chown $APP_USER:$APP_USER $APP_HOME

WORKDIR $APP_HOME

# Copy the built JAR (using the JARFILE argument) and resources from the builder stage.
COPY --from=builder --chown=$APP_USER:$APP_USER /build/target/$JARFILE $APP_HOME/
COPY --from=builder --chown=$APP_USER:$APP_USER /build/target/classes /$APP_HOME/src/main/resources/

USER $APP_USER

EXPOSE 8080
CMD ["java", "$JAVA_OPTS", "-Djava.awt.headless=true", "-jar", "$JARFILE"]
