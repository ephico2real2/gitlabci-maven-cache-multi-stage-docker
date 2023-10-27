# First stage: download dependencies.
FROM maven:3.8.5-jdk-11-slim as dependencies

# Set Argument to reference the built-in Gitlab CI variable
ARG CI_PROJECT_DIR

# Set the working directory.
WORKDIR $CI_PROJECT_DIR

# Copy the Maven settings and the POM file to the working directory.
COPY ci_settings.xml .
COPY pom.xml .

# Download dependencies using the specified local repository.
RUN --mount=type=cache,target=/root/.m2 mvn -B dependency:go-offline -s ci_settings.xml -Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository

# Second stage: builder.
FROM maven:3.8.5-jdk-11-slim as builder

ARG CI_PROJECT_DIR
ARG JARFILE

# Set the working directory.
WORKDIR $CI_PROJECT_DIR

ENV BUILD_HOME /build
RUN mkdir -p $BUILD_HOME

WORKDIR $BUILD_HOME

# Copy the whole project to the build directory.
COPY . .

# Build the project using Maven and copy the generated JAR (using the JARFILE argument) to a specific location.
RUN --mount=type=cache,target=/root/.m2 --mount=type=secret,id=GITLAB_MAVEN_TOKEN ./run-maven.sh

# Third stage: package application jar in runtime image.
FROM openjdk:11-jre-slim as runtime

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update; apt-get install -y fontconfig libfreetype6

ARG JARFILE
ENV JARFILE=$JARFILE \
    APP_HOME /app \
    APP_USER appuser \

RUN adduser -q --shell /bin/false $APP_USER && \
    mkdir -p $APP_HOME && chown $APP_USER:$APP_USER $APP_HOME

WORKDIR $APP_HOME

# Copy the built JAR (using the JARFILE argument) and resources from the builder stage.
COPY --from=builder --chown=$APP_USER:$APP_USER /build/target/$JARFILE $APP_HOME/
COPY --from=builder --chown=$APP_USER:$APP_USER /build/src/main/resources/ $APP_HOME/src/main/resources/

USER $APP_USER

EXPOSE 8080
CMD ["java", "$JAVA_OPTS", "-Djava.awt.headless=true", "-jar", "$JARFILE"]
