FROM openjdk:17-slim
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN apt-get update && apt-get install -y maven
RUN mvn clean package -DskipTests
EXPOSE 8080
CMD ["java", "-jar", "target/order-service-1.0.0.jar"]