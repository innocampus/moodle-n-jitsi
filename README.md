# Moodle and Jitsi at TU Berlin

This is a short descrition of a low level Jitis-Implementaion into Moodle. At current configuration every course obtains a static 
chat room at the Jitsi-Server. It is a 1:1 relation. You can enter the chat room with a link in the course menu. Only participant of a course 
can enter the special course video chat room. All other rooms including the welcome-page at the Jitis-Server are blocked by the apache-config.

## Jitis-Server

### Jitsi Installation

Installation of the Jitsi-Server follows instructions from the Jitsi-Homepage  
[Ubuntu-Debian-Installations-Instructions](https://jitsi.org/downloads/ubuntu-debian-installations-instructions/)

### lua-Authentification

Apache since Version 2.4 is able to authenticate via a selfwritten lua-script.

Documention is here: [Apache Module mod_lua](https://httpd.apache.org/docs/trunk/mod/mod_lua.html)

Enable mod_lua in your Apache2.4. Put our script somewhere /etc/apache2 (not necessarily) and link it into the apache site-configuration.

Update local token = "xxxxxxxxxxxxxxxxxxxxx" to your REST-API-Token from Moodle.

Update local url = "......" (somewhere around line 64) to your actual REST_API-URLs and functionnames from your Moodle-Instance

(Sometimes we will put all the custom-variables in front of the script ....)


### Apache-Config

Our recent apache site-configuration shows the implementation of a combined Shibboleth and Lua-authentification. Any other combination is possible. 
Whatever you like. It's all standard apache-tools.

(btw. ISIS = Information System for Instructors and Students (Trandemark of TU Berlin since 2004))

Include in your VirtualHost environment the LuaAuthzProvider as a new authentication provider:
``` LuaAuthzProvider ISIS_ACL /etc/apache2/authz/video-isis-auth.lua ISIS_ACL_handler```

Insert in the default Jitis-apache-site-config:
```
  <Location />
    AuthName "TU Login"
    AuthType shibboleth
    ShibRequestSetting requireSession 1
    ShibRequestSetting acsIndex 3

    <RequireAll>
       require valid-user
       require ISIS_ACL read
    </RequireAll>
    ErrorDocument 401 https://meet.moodle.tu-berlin.de/error.html
    ErrorDocument 404 https://meet.moodle.tu-berlin.de/error.html
  </Location>

  <Location /Shibboleth.sso>
    AuthType None
    Require all granted
  </Location>
```

Error-Document doesn't work so far because of javascript routines from Jitsi. If anybody has an idea, to provide a proper error, if anybody tries to access 
a chatroom, where he is not authorized, please let us know.

## Moodle-Server

### REST-API Function

### Course Menu Link
