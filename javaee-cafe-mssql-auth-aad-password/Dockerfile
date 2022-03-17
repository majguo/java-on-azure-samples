# open liberty base image
FROM openliberty/open-liberty:kernel-java8-openj9-ubi

# Add config, app and jdbc driver
COPY --chown=1001:0 src/main/liberty/config/server.xml /config/server.xml
COPY --chown=1001:0 target/javaee-cafe-mssql-auth-aad-password.war /config/apps/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/accessors-smart-2.4.7.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/asm-9.1.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/content-type-2.1.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/jackson-annotations-2.12.1.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/jackson-core-2.12.1.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/jackson-databind-2.12.1.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/jcip-annotations-1.0-1.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/json-smart-2.4.7.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/lang-tag-1.5.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/msal4j-1.11.0.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/mssql-jdbc-9.2.1.jre8.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/nimbus-jose-jwt-9.9.3.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/oauth2-oidc-sdk-9.7.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/slf4j-api-1.7.28.jar /opt/ol/wlp/usr/shared/resources/
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/slf4j-simple-1.7.28.jar /opt/ol/wlp/usr/shared/resources/

# This script will add the requested XML snippets, grow image to be fit-for-purpose and apply interim fixes
RUN configure.sh
