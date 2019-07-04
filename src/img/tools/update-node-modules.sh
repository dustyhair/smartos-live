#!/bin/bash
#
# Copyright (c) 2013, Joyent, Inc. All rights reserved.
#
# Update "/usr/img/node_modules". Goals (most important first):
#
# - Eliminate duplicate copies of modules.
# - No binary modules. The only current one should be dtrace-provider and
#   the platform has a build of that already. Patch things to use it.
# - Trim out cruft. I don't want zillions of files in the platform.
#
#
# Warnings:
# - This *does* involve taking liberties with specified dependency
#   versions. E.g. You get the version of the shared dtrace-provider already
#   in "/usr/node/node_modules/dtrace-provider".
#

if [ "$TRACE" != "" ]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail



#---- support stuff

function fatal
{
    echo "$(basename $0): fatal error: $*"
    exit 1
}

function errexit
{
    [[ $1 -ne 0 ]] || exit 0
    fatal "error exit status $1 at line $2"
}

trap 'errexit $? $LINENO' EXIT



#---- mainline

rm -rf node_modules
npm install --ignore-scripts

# General cruft cleaning
find node_modules -name .bin | xargs rm -rf
for dep in $(ls node_modules); do
    find node_modules/$dep -name .dir-locals.el | xargs rm;
    find node_modules/$dep -name .eslintrc.js | xargs rm;
    find node_modules/$dep -name .gitmodules | xargs rm;
    find node_modules/$dep -name .gitignore | xargs rm;
    find node_modules/$dep -name .jshintrc | xargs rm;
    find node_modules/$dep -name .npmignore | xargs rm;
    find node_modules/$dep -name .travis.yml | xargs rm;
    find node_modules/$dep -name AUTHORS | xargs rm;
    find node_modules/$dep -name benchmark | xargs rm -rf;
    find node_modules/$dep -name CHANGES.md | xargs rm;
    find node_modules/$dep -name CHANGELOG* | xargs rm;
    find node_modules/$dep -name component.json | xargs rm;
    find node_modules/$dep -name CONTRIBUTING.md | xargs rm;
    find node_modules/$dep -name CONTRIBUTORS* | xargs rm;
    find node_modules/$dep -name doc | xargs rm -rf;
    find node_modules/$dep -name docs | xargs rm -rf;
    find node_modules/$dep -name examples | xargs rm -rf;
    find node_modules/$dep -name example | xargs rm -rf;
    find node_modules/$dep -name experiments | xargs rm -rf;
    find node_modules/$dep -name Gruntfile.js | xargs rm;
    find node_modules/$dep -name History.md | xargs rm;
    find node_modules/$dep -name img | xargs rm -rf;
    find node_modules/$dep -name jsl.node.conf | xargs rm;
    find node_modules/$dep -name LICENSE* | xargs rm;
    find node_modules/$dep -name man | xargs rm -rf;
    find node_modules/$dep -name man1 | xargs rm -rf;
    find node_modules/$dep -name "Makefile*" | xargs rm;
    find node_modules/$dep -iname "README*" | xargs rm;
    find node_modules/$dep -name share | xargs rm -rf;
    find node_modules/$dep -name TODO.txt | xargs rm;
    find node_modules/$dep -name TODO.md | xargs rm;
    find node_modules/$dep -name tools | xargs rm -rf;
    find node_modules/$dep -name tst | xargs rm -rf;
    find node_modules/$dep -name test | xargs rm -rf;
    find node_modules/$dep -name tests | xargs rm -rf;
    find node_modules/$dep -name test.js | xargs rm;
done

rm -rf node_modules/.bin/

rm -rf node_modules/bunyan/node_modules
# patch to use platform's dtrace-provider
patch -p0 <<'PATCHBUNYAN'
--- node_modules/bunyan/lib/bunyan.js
+++ node_modules/bunyan/lib/bunyan.js
@@ -32,7 +32,7 @@ var util = require('util');
 var assert = require('assert');
 try {
     /* Use `+ ''` to hide this import from browserify. */
-    var dtrace = require('dtrace-provider' + '');
+    var dtrace = require('/usr/node/node_modules/dtrace-provider' + '');
 } catch (e) {
     dtrace = null;
 }
PATCHBUNYAN

rm -rf node_modules/mkdirp/bin \
    node_modules/mkdirp/node_modules

rm -rf node_modules/docker-registry-client/deps
# Have some of these deps at top-level.
if [[ -d node_modules/docker-registry-client/node_modules ]]; then
    rm -rf node_modules/docker-registry-client/node_modules/{.bin,bunyan,vasync,verror,restify}
    # Remove some bits not needed for runtime
    rm -rf node_modules/docker-registry-client/node_modules/tough-cookie/{.editorconfig,generate-pubsuffix.js,public-suffix.txt,tough-cookie-deps.tsv}
fi

rm -rf node_modules/progbar/node_modules/assert-plus  # slight version mismatch
rm -rf node_modules/progbar/node_modules/readable-stream # only needed for node 0.8

rm -rf node_modules/imgmanifest/node_modules/assert-plus  # slight version mismatch
rm -rf node_modules/imgmanifest/bin  # don't need this
rm -rf node_modules/imgmanifest/deps/javascriptlint # developer-only stuff
rm -rf node_modules/imgmanifest/deps/jsstyle # same.

rm -rf node_modules/vasync/node_modules/verror # version mismatch

rm -rf node_modules/verror/node_modules/extsprintf  # version mismatch

# Only need lib/tabula.js, not the CLI.
rm -rf node_modules/tabula/{bin,node_modules} \
    node_modules/.bin/tabula \
    node_modules/tabula/lib/linestream.js

# sdc-clients
# - Have some modules at top-level. Should be close enough version match.
rm -rf node_modules/sdc-clients/node_modules/restify
rm -rf node_modules/sdc-clients/node_modules/bunyan
rm -rf node_modules/sdc-clients/node_modules/vasync
rm -rf node_modules/sdc-clients/node_modules/verror
rm -rf node_modules/sdc-clients/node_modules/once
rm -rf node_modules/sdc-clients/node_modules/backoff
# - Whitelist the clients we care about.
KEEPERS="imgapi.js dsapi.js index.js"
for FNAME in $(cd node_modules/sdc-clients/lib && ls -1); do
    if [[ -z $(echo "$KEEPERS" | grep "\<$FNAME\>") ]]; then
        rm node_modules/sdc-clients/lib/$FNAME
    fi
done
# - Remove unneeded deps
rm -rf node_modules/sdc-clients/node_modules/.bin
rm -rf node_modules/sdc-clients/node_modules/clone
rm -rf node_modules/sdc-clients/node_modules/http-signature
rm -rf node_modules/sdc-clients/node_modules/libuuid
rm -rf node_modules/sdc-clients/node_modules/ufds
rm -rf node_modules/sdc-clients/node_modules/ssh-agent/{bin,node_modules/posix-getopt}
rm -rf node_modules/sdc-clients/node_modules/smartdc-auth
# restify
# - We just want the restify client.
rm -rf node_modules/restify/lib/{formatters,plugins,request.js,response.js,router.js,server.js}
KEEPERS="semver tunnel-agent lru-cache mime keep-alive-agent"
for FNAME in $(cd node_modules/restify/node_modules && ls -1); do
    if [[ -z $(echo "$KEEPERS" | grep "\<$FNAME\>") ]]; then
        rm -rf node_modules/restify/node_modules/$FNAME
    fi
done
rm -rf node_modules/restify/node_modules/.bin
rm -rf node_modules/restify/bin
# mime 1.3.4 added some build cruft, and a CLI I don't care about
rm -rf node_modules/restify/node_modules/mime/build/
rm -rf node_modules/restify/node_modules/mime/cli.js
# lru-cache 2.6.2 added some junk
rm -rf node_modules/restify/node_modules/lru-cache/{foo,bar}.js
ls node_modules/restify/node_modules/semver/ \
        | grep -v package.json \
        | grep -v semver.js \
        | while read FNAME; do
    rm -rf node_modules/restify/node_modules/semver/$FNAME
done
patch -p0 <<'PATCHRESTIFY'
--- node_modules/restify/lib/index.js.orig	2013-02-05 16:08:51.000000000 -0800
+++ node_modules/restify/lib/index.js	2013-02-05 16:09:04.000000000 -0800
@@ -7,6 +7,8 @@
 // and enables much faster load times
 //

+process.env.RESTIFY_CLIENT_ONLY = 1;
+
 function createClient(options) {
         var assert = require('assert-plus');
         var bunyan = require('./bunyan_helper');
--- node_modules/restify/lib/dtrace.js
+++ node_modules/restify/lib/dtrace.js
@@ -36,7 +36,7 @@
 module.exports = function exportStaticProvider() {
     if (!PROVIDER) {
         try {
-            var dtrace = require('dtrace-provider');
+            var dtrace = require('/usr/node/node_modules/dtrace-provider');
             PROVIDER = dtrace.createDTraceProvider('restify');
         } catch (e) {
             PROVIDER = {
PATCHRESTIFY
rm -rf node_modules/restify/lib/index.js.orig
rm -rf node_modules/restify/lib/dtrace.js.orig

patch -p0 <<'PATCHRESTIFYCLIENTS'
--- node_modules/sdc-clients/node_modules/restify-clients/lib/helpers/dtrace.js.orig	2018-07-25 23:40:39.000000000 +0100
+++ node_modules/sdc-clients/node_modules/restify-clients/lib/helpers/dtrace.js	2019-07-01 17:30:14.000000000 +0100
@@ -27,7 +27,8 @@
 module.exports = (function exportStaticProvider() {
     if (!PROVIDER) {
         try {
-            var dtrace = require('dtrace-provider');
+            // var dtrace = require('dtrace-provider');
+            var dtrace = require('/usr/node/node_modules/dtrace-provider');
             PROVIDER = dtrace.createDTraceProvider('restify');
         } catch (e) {
             PROVIDER = {
PATCHRESTIFYCLIENTS
rm -rf node_modules/sdc-clients/node_modules/restify-clients/lib/helpers/dtrace.js.orig

patch -p0 <<'PATCHSDCCLIENTS'
--- node_modules/sdc-clients/lib/imgapi.js.orig	2019-07-02 10:22:28.000000000 +0100
+++ node_modules/sdc-clients/lib/imgapi.js	2019-07-02 10:22:38.000000000 +0100
@@ -68,7 +68,6 @@
 var restifyClients = require('restify-clients');
 var mod_url = require('url');
 var backoff = require('backoff');
-var auth = require('smartdc-auth');
 var sshpk = require('sshpk');


PATCHSDCCLIENTS

# tunnel-agent >=0.4.1
# At the time of writing tunnel-agent.git has a fix we need for Docker Hub
# import via an http_proxy. Only 0.4.0 was published to npm.
if [[ "$(json -f node_modules/restify/node_modules/tunnel-agent/package.json version)" == "0.4.0" ]]; then
    curl https://raw.githubusercontent.com/mikeal/tunnel-agent/912a7a6d00e10ec76baf9c9369de280fa5badef3/index.js \
        -o node_modules/restify/node_modules/tunnel-agent/index.js
fi

# nodeunit
# Drop bits not needed for running.
rm -rf node_modules/nodeunit/nodelint.cfg
# drop tap reporter
rm -rf node_modules/nodeunit/node_modules
rm -rf node_modules/nodeunit/lib/reporters/tap.js
# drop junit reporter
rm -rf node_modules/nodeunit/deps/ejs
rm -rf node_modules/nodeunit/lib/reporters/junit.js
# patch to drop reporters
patch -p0 <<'PATCHNODEUNIT'
--- node_modules/nodeunit/lib/reporters/index.js.orig
+++ node_modules/nodeunit/lib/reporters/index.js
@@ -1,12 +1,10 @@
 module.exports = {
-    'junit': require('./junit'),
     'default': require('./default'),
     'skip_passed': require('./skip_passed'),
     'minimal': require('./minimal'),
     'html': require('./html'),
     'eclipse': require('./eclipse'),
     'machineout': require('./machineout'),
-    'tap': require('./tap'),
     'nested': require('./nested'),
     'verbose' : require('./verbose')
     // browser test reporter is not listed because it cannot be used
PATCHNODEUNIT
rm -rf node_modules/nodeunit/lib/reporters/index.js.orig

# docker-registry-client
# drop base64url un-needed bits
rm -rf node_modules/docker-registry-client/node_modules/base64url/bin
rm -rf node_modules/docker-registry-client/node_modules/base64url/node_modules/meow
# drop duplicated base64url module
rm -rf node_modules/docker-registry-client/node_modules/jws/node_modules/jwa/node_modules/base64url
# patch to use the older restify module
patch -p0 <<'PATCHDRC'
--- node_modules/docker-registry-client/lib/docker-json-client.js
+++ node_modules/docker-registry-client/lib/docker-json-client.js
@@ -47,13 +47,13 @@
 
 var assert = require('assert-plus');
 var crypto = require('crypto');
-var restifyClients = require('restify-clients');
-var restifyErrors = require('restify-errors');
+var restify = require('restify');
+var restifyErrors = restify.errors;
 var strsplit = require('strsplit').strsplit;
 var util = require('util');
 var zlib = require('zlib');
 
-var StringClient = restifyClients.StringClient;
+var StringClient = restify.StringClient;
 
 
 // --- API
--- node_modules/docker-registry-client/lib/registry-client-v1.js
+++ node_modules/docker-registry-client/lib/registry-client-v1.js
@@ -22,7 +22,7 @@ var assert = require('assert-plus');
 var bunyan = require('bunyan');
 var fmt = require('util').format;
 var mod_url = require('url');
-var restifyClients = require('restify-clients');
+var restify = require('restify');
 var tough = require('tough-cookie');
 var vasync = require('vasync');
 var VError = require('verror').VError;
@@ -77,7 +77,7 @@ function pingIndex(opts, cb) {
     assert.func(cb, 'cb');
 
     var index = common.parseIndex(opts.indexName);
-    var client = restifyClients.createJsonClient({
+    var client = restify.createJsonClient({
         url: common.urlFromIndex(index),
         log: opts.log,
         userAgent: opts.userAgent || common.DEFAULT_USERAGENT,
@@ -140,7 +140,7 @@ function login(opts, cb) {
     }
     var indexUrl = common.urlFromIndex(index);
 
-    var client = restifyClients.createJsonClient({
+    var client = restify.createJsonClient({
         url: indexUrl,
         log: opts.log,
         userAgent: opts.userAgent || common.DEFAULT_USERAGENT,
@@ -303,11 +303,11 @@ function RegistryClientV1(opts) {
     this.log = opts.log
         ? opts.log.child({
                 component: 'registry',
-                serializers: restifyClients.bunyan.serializers
+                serializers: restify.bunyan.serializers
             })
         : bunyan.createLogger({
                 name: 'registry',
-                serializers: restifyClients.bunyan.serializers
+                serializers: restify.bunyan.serializers
             });
 
     this.insecure = Boolean(opts.insecure);
@@ -548,10 +548,10 @@ RegistryClientV1.prototype._createClient = function _createClient(type, url) {
     var client;
     switch (type) {
     case 'http':
-        client = restifyClients.createHttpClient(clientOpts);
+        client = restify.createHttpClient(clientOpts);
         break;
     case 'json':
-        client = restifyClients.createJsonClient(clientOpts);
+        client = restify.createJsonClient(clientOpts);
         break;
     default:
         throw new Error('unknown client type: ' + type);
--- node_modules/docker-registry-client/lib/registry-client-v2.js
+++ node_modules/docker-registry-client/lib/registry-client-v2.js
@@ -22,8 +22,8 @@ var fmt = require('util').format;
 var jwkToPem = require('jwk-to-pem');
 var mod_jws = require('jws');
 var querystring = require('querystring');
-var restifyClients = require('restify-clients');
-var restifyErrors = require('restify-errors');
+var restify = require('restify');
+var restifyErrors = restify.errors;
 var strsplit = require('strsplit');
 var mod_url = require('url');
 var vasync = require('vasync');
@@ -54,12 +54,12 @@ function _createLogger(log) {
         // TODO avoid this .child if already have the serializers, e.g. for
         // recursive call.
         return log.child({
-            serializers: restifyClients.bunyan.serializers
+            serializers: restify.bunyan.serializers
         });
     } else {
         return bunyan.createLogger({
             name: 'registry',
-            serializers: restifyClients.bunyan.serializers
+            serializers: restify.bunyan.serializers
         });
     }
 }
@@ -1390,7 +1390,7 @@ RegistryClientV2.prototype._headOrGetBlob = function _headOrGetBlob(opts, cb) {
                 }
                 numRedirs += 1;
 
-                var client = restifyClients.createHttpClient(common.objMerge({
+                var client = restify.createHttpClient(common.objMerge({
                     url: reqOpts.url
                 }, self._commonHttpClientOpts));
                 self._clientsToClose.push(client);
PATCHDRC
rm -f node_modules/docker-registry-client/lib/*.js.orig
# now remove un-needed restify-clients and restify-errors
rm -rf node_modules/docker-registry-client/node_modules/restify-clients
rm -rf node_modules/docker-registry-client/node_modules/restify-errors

# Normalize all package.json's. Dropping fields that seem to
# change willy-nilly from npm server-side.
for packageJson in $(find node_modules -name package.json); do
    json -f $packageJson -Ie '
        delete this.readme;
        delete this.readmeFilename;
        delete this.dist;
        delete this.maintainers;
        delete this.directories;
        delete this.gitHead;
        delete this._id;
        delete this._shasum;
        delete this._resolved;
        delete this._npmVersion;
        delete this._npmUser;
        delete this._from;
        delete this._engineSupported;
        delete this._nodeVersion;
        delete this._defaultsLoaded;
        delete this._from;
    '
done
