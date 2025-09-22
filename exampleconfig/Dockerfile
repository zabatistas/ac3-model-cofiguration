# Multi-stage Dockerfile for Spring Boot (Maven build)
# Assumes project uses Maven and produces a fat jar at target/*.jar


FROM maven:3.9.11-amazoncorretto-24-debian-trixie AS builder
WORKDIR /workspace
COPY pom.xml mvnw .mvn/ ./
COPY .mvn/ .mvn/
# copy sources
COPY src ./src


# Use Maven to build a packaged jar (skip tests for speed; remove -DskipTests=false if you want tests)
RUN --mount=type=cache,target=/root/.m2 \
mvn -B -f pom.xml -DskipTests package


# Runtime image
FROM eclipse-temurin:24-jre
ARG JAR_NAME
ENV JAVA_OPTS="-Xms256m -Xmx512m"
WORKDIR /app
# copy jar from the builder stage; if your jar has a deterministic name replace JAR_NAME
COPY --from=builder /workspace/target/*.jar app.jar


EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
CMD curl -fsS http://localhost:8080/actuator/health || exit 1


ENTRYPOINT ["sh","-c","java $JAVA_OPTS -jar /app/app.jar"]