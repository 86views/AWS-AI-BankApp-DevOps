# ---------- Build Stage ----------
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app

# 1. Copy Maven wrapper and POM first (Docker layer caching)
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# 2. Download dependencies offline (speeds up subsequent builds & CI)
RUN ./mvnw dependency:go-offline -B

# 3. Copy source code and build
COPY src src
RUN ./mvnw clean package -DskipTests -B

# ---------- Runtime Stage ----------
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# 4. Install OS patches, timezone data, and curl (for healthchecks) – then clean cache
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache tzdata curl && \
    rm -rf /var/cache/apk/*

# 5. Create non-root user with a fixed UID (1000) for consistency with compose/EC2
RUN addgroup -S -g 1000 devsecops && \
    adduser -S -u 1000 -G devsecops devsecops
USER devsecops

# Copy the built JAR
COPY --from=build /app/target/*.jar app.jar

# 6. JVM memory tuning (container-aware) and Healthcheck (requires Spring Actuator)
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=80.0"
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]