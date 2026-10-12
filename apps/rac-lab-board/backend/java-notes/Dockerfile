FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /app
COPY lib/ lib/
COPY src/ src/
RUN mkdir build && javac --release 21 -cp "lib/*" -d build src/NotesServer.java
FROM eclipse-temurin:21-jre-jammy
RUN groupadd --gid 10001 app && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build /app/build build/
COPY --from=build /app/lib lib/
ENV JAVA_TOOL_OPTIONS="-Xms32m -Xmx128m -XX:MaxMetaspaceSize=96m -XX:ActiveProcessorCount=2 -Dsun.net.httpserver.maxReqTime=20 -Dsun.net.httpserver.maxRspTime=20"
USER 10001:10001
EXPOSE 8083
CMD ["java", "-cp", "build:lib/*", "NotesServer"]
