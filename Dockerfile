# ===== Stage 0: resolver dependências do Jersey (apenas download) =====
FROM maven:3.9-eclipse-temurin-24 AS deps
WORKDIR /w

# POM mínimo para baixar os JARs necessários do Jersey (Jakarta 10 / JAX-RS 3.1)
RUN printf '%s\n' \
  '<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">' \
  '  <modelVersion>4.0.0</modelVersion>' \
  '  <groupId>tmp</groupId><artifactId>deps</artifactId><version>1</version>' \
  '  <dependencies>' \
  '    <dependency>' \
  '      <groupId>org.glassfish.jersey.containers</groupId>' \
  '      <artifactId>jersey-container-servlet-core</artifactId>' \
  '      <version>3.1.6</version>' \
  '    </dependency>' \
  '    <dependency>' \
  '      <groupId>org.glassfish.jersey.inject</groupId>' \
  '      <artifactId>jersey-hk2</artifactId>' \
  '      <version>3.1.6</version>' \
  '    </dependency>' \
  '    <dependency>' \
  '      <groupId>jakarta.ws.rs</groupId>' \
  '      <artifactId>jakarta.ws.rs-api</artifactId>' \
  '      <version>3.1.0</version>' \
  '      <scope>runtime</scope>' \
  '    </dependency>' \
  '    <dependency>' \
  '      <groupId>jakarta.annotation</groupId>' \
  '      <artifactId>jakarta.annotation-api</artifactId>' \
  '      <version>2.1.1</version>' \
  '      <scope>runtime</scope>' \
  '    </dependency>' \
  '  </dependencies>' \
  '</project>' > pom.xml

RUN mvn -q -DincludeScope=runtime dependency:copy-dependencies

# ===== Stage 1: build do WAR com javac/jar (sem Maven) =====
FROM eclipse-temurin:24-jdk AS build
WORKDIR /work

ARG TOMCAT_VERSION=10.1.46
ENV TOMCAT_DIST=/opt/apache-tomcat-${TOMCAT_VERSION}

# Baixa Tomcat para obter a servlet-api (compilação) e basear o runtime depois
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends wget ca-certificates && rm -rf /var/lib/apt/lists/*; \
    wget -O /tmp/t.tgz https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz; \
    mkdir -p /opt; tar -xzf /tmp/t.tgz -C /opt; rm -f /tmp/t.tgz

# Copia código e web.xml
COPY src src
COPY web web

# Copia dependências do Jersey do estágio "deps" para /work/lib
RUN mkdir -p /work/lib
COPY --from=deps /w/target/dependency/*.jar /work/lib/

# Compila as classes (precisamos da servlet-api e da ws.rs-api no classpath)
RUN set -eux; \
    mkdir -p build/WEB-INF/classes; \
    javac -cp "/work/lib/jakarta.ws.rs-api-3.1.0.jar" \
          -d build/WEB-INF/classes $(find src -name "*.java"); \
    # Copia web.xml e quaisquer estáticos
    cp -r web/* build/; \
    mkdir -p build/WEB-INF/lib; \
    cp -v /work/lib/*.jar build/WEB-INF/lib/; \
    (cd build && jar -cvf /work/app.war .)

# ===== Stage 2: criar JRE mínima =====
FROM eclipse-temurin:24-jdk AS jre
RUN jlink --add-modules \
    java.base,java.logging,java.xml,java.management,java.naming,java.rmi,java.sql,java.desktop,java.security.jgss,jdk.unsupported,jdk.charsets,java.instrument \
    --strip-debug --no-man-pages --no-header-files --compress=2 --output /opt/jre-min

# ===== Stage 3: runtime Tomcat enxuto =====
FROM debian:stable-slim
ARG TOMCAT_VERSION=10.1.46
ENV CATALINA_HOME=/opt/tomcat PATH=/opt/jre-min/bin:$PATH

RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates; \
    curl -fsSL "https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" -o /tmp/t.tgz; \
    mkdir -p $CATALINA_HOME; tar -xzf /tmp/t.tgz -C /opt; mv /opt/apache-tomcat-${TOMCAT_VERSION}/* $CATALINA_HOME; \
    rm -rf /tmp/t.tgz $CATALINA_HOME/webapps/*; \
    # Remover coisas não usadas (JSP, i18n, websocket, cluster) p/ reduzir footprint
    rm -f $CATALINA_HOME/lib/jasper*.jar $CATALINA_HOME/lib/ecj-*.jar || true; \
    rm -f $CATALINA_HOME/lib/tomcat-i18n-*.jar || true; \
    rm -f $CATALINA_HOME/lib/tomcat-websocket*.jar websocket*.jar || true; \
    rm -f $CATALINA_HOME/lib/catalina-tribes.jar catalina-storeconfig.jar || true; \
    mkdir -p ${CATALINA_HOME}/logs ${CATALINA_HOME}/temp ${CATALINA_HOME}/work

COPY --from=jre /opt/jre-min /opt/jre-min
COPY --from=build /work/app.war $CATALINA_HOME/webapps/ROOT.war

# Usuário não-root
RUN set -eux; useradd -r -d ${CATALINA_HOME} -s /sbin/nologin tomcat; chown -R tomcat:tomcat ${CATALINA_HOME}
USER tomcat

ENV CATALINA_OPTS="-Xms16m -XX:MaxRAMPercentage=40 -XX:+UseSerialGC -Dfile.encoding=UTF-8"
EXPOSE 8080
CMD ["/opt/tomcat/bin/catalina.sh","run"]
