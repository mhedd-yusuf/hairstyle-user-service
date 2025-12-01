# Multi-stage build for Spring Boot application

# Stage 1: Build stage (optional if Jenkins already builds)
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime stage
FROM eclipse-temurin:21-jre-alpine

# Add metadata
LABEL maintainer="your-email@example.com"
LABEL description="Hairstyle User Service - Spring Boot Microservice"

# Create app directory
WORKDIR /app

# Copy the JAR file from build stage (or from Jenkins build)
# If Jenkins builds, use: COPY target/*.jar app.jar
COPY --from=build /app/target/*.jar app.jar

# Create non-root user for security
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# JVM options for container environment
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]