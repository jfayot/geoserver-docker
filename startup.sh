#!/bin/sh
echo "Welcome to GeoServer $GEOSERVER_VERSION"

## Skip demo data
if [ "${SKIP_DEMO_DATA}" = "true" ]; then
  unset GEOSERVER_REQUIRE_FILE
fi

## Add a permanent redirect (HTTP 301) from the root webapp ("/") to geoserver web interface ("/geoserver/web")
if [ "${ROOT_WEBAPP_REDIRECT}" = "true" ]; then
  if [ ! -d $CATALINA_HOME/webapps/ROOT ]; then
      mkdir $CATALINA_HOME/webapps/ROOT
  fi

  cat > $CATALINA_HOME/webapps/ROOT/index.jsp << EOF
<%
  final String redirectURL = "/geoserver/web/";
  response.setStatus(HttpServletResponse.SC_MOVED_PERMANENTLY);
  response.setHeader("Location", redirectURL);
%>
EOF
fi


## install release data directory if needed before starting tomcat
if [ ! -z "$GEOSERVER_REQUIRE_FILE" ] && [ ! -f "$GEOSERVER_REQUIRE_FILE" ]; then
  echo "Initialize $GEOSERVER_DATA_DIR from data directory included in geoserver.war"
  cp -r $CATALINA_HOME/webapps/geoserver/data/* $GEOSERVER_DATA_DIR
fi

## install GeoServer extensions before starting the tomcat
/opt/install-extensions.sh

# copy additional geoserver libs before starting the tomcat
# we also count whether at least one file with the extensions exists
count=`ls -1 $ADDITIONAL_LIBS_DIR/*.jar 2>/dev/null | wc -l`
if [ -d "$ADDITIONAL_LIBS_DIR" ] && [ $count != 0 ]; then
    cp $ADDITIONAL_LIBS_DIR/*.jar $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/
    echo "Installed $count JAR extension file(s) from the additional libs folder"
fi

# copy additional fonts before starting the tomcat
# we also count whether at least one file with the fonts exists
count=`ls -1 *.ttf 2>/dev/null | wc -l`
if [ -d "$ADDITIONAL_FONTS_DIR" ] && [ $count != 0 ]; then
    cp $ADDITIONAL_FONTS_DIR/*.ttf /usr/share/fonts/truetype/
    echo "Installed $count TTF font file(s) from the additional fonts folder"
fi

# configure CORS (inspired by https://github.com/oscarfonts/docker-geoserver)
# if enabled, this will add the filter definitions
# to the end of the web.xml
# (this will only happen if our filter has not yet been added before)
if [ "${CORS_ENABLED}" = "true" ]; then
  if ! grep -q DockerGeoServerCorsFilter "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"; then
    echo "Enable CORS for $CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"
    sed -i "\:</web-app>:i\\
    <filter>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>\n\
      <init-param>\n\
          <param-name>cors.allowed.origins</param-name>\n\
          <param-value>${CORS_ALLOWED_ORIGINS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
          <param-name>cors.allowed.methods</param-name>\n\
          <param-value>${CORS_ALLOWED_METHODS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.allowed.headers</param-name>\n\
        <param-value>${CORS_ALLOWED_HEADERS}</param-value>\n\
      </init-param>\n\
    </filter>\n\
    <filter-mapping>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <url-pattern>/*</url-pattern>\n\
    </filter-mapping>" "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml";
  fi
fi

if [ "${SSL_ENABLED}" = "true" ]; then
  if ! grep -q DockerGeoServerSslParam "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"; then
    echo "Enabling SSL for $CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"
    sed -i "\:</web-app>:i\\
      <context-param>\n\
        <param-name>DockerGeoServerSslParam</param-name>\n\
        <param-value>true</param-value>\n\
      </context-param>\n\
      <context-param>\n\
        <param-name>PROXY_BASE_URL</param-name>\n\
        <param-value>${PROXY_BASE_URL}</param-value>\n\
      </context-param>\n\
      <context-param>\n\
        <param-name>GEOSERVER_CSRF_WHITELIST</param-name>\n\
        <param-value>${CSRF_DOMAIN}</param-value>\n\
      </context-param>" "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml";
  fi
fi

# start the tomcat
$CATALINA_HOME/bin/catalina.sh run
