# Moodle and Jitsi at TU Berlin

This is a short description of a low level Jitsi-Implementation into Moodle. At current configuration every course obtains a static 
chat room at the Jitsi-Server. It is a 1:1 relation. You can enter the chat room with a link in the course menu. Only participants of a course 
can enter the special course-video-chat-room. All other rooms including the welcome-page at the Jitsi-Server are blocked by the apache-config.

## Jitsi-Server

### Jitsi Installation

Installation of the Jitsi-Server follows instructions from the Jitsi-Homepage  
[Ubuntu-Debian-Installations-Instructions](https://jitsi.org/downloads/ubuntu-debian-installations-instructions/)

Standard Installation comes with Nginx as Reverse-Proxy. Please install Apache 2.4, disable Nginx. Take our site configuration from 
**apache2/sites-available/jitsi.conf** and modify it to your parameters.

Example Apache Configuration from Jitsi can be found here:  
[https://github.com/jitsi/jitsi-meet/blob/master/doc/debian/jitsi-meet/jitsi-meet.example-apache](https://github.com/jitsi/jitsi-meet/blob/master/doc/debian/jitsi-meet/jitsi-meet.example-apache)

### lua-Authentification

Apache since Version 2.4 is able to authenticate via a selfwritten lua-script.

Documention is here: [Apache Module mod_lua](https://httpd.apache.org/docs/trunk/mod/mod_lua.html)

Enable mod_lua in your Apache 2.4. Put our script **video-isis-auth.lua** somewhere /etc/apache2 (not necessarily) and link it into the apache site-configuration.

Update local token = "xxxxxxxxxxxxxxxxxxxxx" to your REST-API-Token from Moodle.

Update local url = "......" (somewhere around line 64) to your actual REST-API-URLs and function names from your Moodle-Instance.

*(Sometime we will put all the custom-variables in front of the script ....)*


### Apache-Config

Our recent apache site-configuration shows the implementation of a combined Shibboleth and Lua-authentification. Any other combination is possible. 
Whatever you like. It's all standard apache-tools.

*(btw. ISIS = Information System for Instructors and Students (Trademark of TU Berlin Moodle since 2004))*

Include in your VirtualHost environment the LuaAuthzProvider as a new authentication provider:  
``` LuaAuthzProvider ISIS_ACL /etc/apache2/authz/video-isis-auth.lua ISIS_ACL_handler```

Insert in the default Jitsi-apache-site-config:
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

*Error-Document doesn't work so far because of javascript routines from Jitsi. If anybody has an idea, to provide a proper error, if anybody tries to access 
a chatroom, where he is not authorized, please let us know.*

## Moodle-Server

We don't have a full/own plugin for this. We put the code in an already existing local plugin.
We already had the external function code in use for another use case and just reused it for jitsi.

Probably there are nicer integrations possible without Shibboleth and using JSON Web Tokens,
allowing to transmit the user's full name, avatar and permissions to jitsi. 

### REST-API Function

Add a class like this to a local Moodle plugin.
```
<?php

defined('MOODLE_INTERNAL') || die();
require_once("$CFG->libdir/externallib.php");

class local_x extends external_api {
    public static function videochat_check_access_parameters() {
        return new external_function_parameters(
            array(
                'courseid' => new external_value(PARAM_INT),
                'username' => new external_value(PARAM_TEXT),
                'type' => new external_value(PARAM_TEXT),
            )
        );
    }

    public static function videochat_check_access_returns() {
        return new external_value(PARAM_BOOL);
    }

    public static function videochat_check_access($courseid, $username, $type) {
        global $DB, $CFG;

        $params = array(
            'courseid' => $courseid,
            'username' => $username,
            'type' => $type,
        );

        $params = self::validate_parameters(self::video_check_access_parameters(), $params);

        if ($type === 'read') {
            $requiredcap = 'mod/resource:view';
        } else if ($type === 'write') {
            $requiredcap = 'mod/resource:addinstance';
        } else {
            throw new invalid_parameter_exception('Wrong type given');
        }

        $coursecontext = context_course::instance($params['courseid'], IGNORE_MISSING);
        if ($coursecontext === false) {
            return false;
        }

        $userid = $DB->get_field('user', 'id',
                array('username' => $params['username'], 'deleted' => 0, 'suspended' => 0, 'policyagreed' => 1,
                      'mnethostid' => $CFG->mnet_localhost_id),
                'id', IGNORE_MISSING);
        if ($userid === false) {
            return false;
        }

        // Similar checks like require_login.
        $coursevisible = $DB->get_field('course', 'visible', array('id' => $params['courseid']));
        if (!$coursevisible && !has_capability('moodle/course:viewhiddencourses', $coursecontext, $userid)) {
            return false;
        }
        if (!is_enrolled($coursecontext, $userid, '', true) && !is_viewing($coursecontext, $userid)) {
            return false;
        }

        return has_capability($requiredcap, $coursecontext, $userid);
    }
}
```

Adjust the `db/services.php` to look similar like this:
```
<?php

$functions = array(
    'local_test_videochat_check_access' => array(
        'classname' => 'local_isis_external',
        'methodname' => 'video_check_access',
        'classpath' => 'local/isis/externallib.php',
        'description' => 'Check if a user is allowed to access videos in a course (created for ISIS Video Server)',
        'type' => 'read',
    ),
);
```

Create a new Webservice user in Moodle and give the user access to the external function above.

### Course Menu Link

Add a function like this to `lib.php`:
```
function local_test_extend_navigation(global_navigation $nav) {
    global $PAGE;

    $coursenode = $PAGE->navigation->find_active_node();
    while (!empty($coursenode) && ($coursenode->type != navigation_node::TYPE_COURSE)) {
        $coursenode = $coursenode->parent;
    }
    if ($coursenode) {
        $url = sprintf("%s%06d", 'https://meet.moodle.tu-berlin.de/ISIS', $courseid);
        $coursenode->add('Videochat', $url, global_navigation::TYPE_CUSTOM, null, 'videochat');
    }
}
```
