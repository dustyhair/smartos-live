/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the Common Development
 * and Distribution License (the "License").  You may not use this file except
 * in compliance with the License.
 *
 * You can obtain a copy of the license at http://smartos.org/CDDL.
 *
 * CDDL HEADER END
 */

/* Validate the vmadm properties used by the LX private-network lifecycle. */

var VM = require('../node_modules/VM');
var vmtest = require('../common/vmtest.js');

/* jsl:import ../node_modules/nodeunit-plus/index.js */
require('nodeunit-plus');

function lxPayload()
{
    return {
        brand: 'lx',
        image_uuid: vmtest.CURRENT_UBUNTU_LX_IMAGE_UUID,
        kernel_version: '5.10.0',
        lx_private_network: true,
        lx_private_network_egress: 'admin0',
        lx_private_network_links: 1,
        lx_private_network_subnet: '10.88.0.0/24'
    };
}

test('valid LX private network properties', function (t) {
    VM.validate('lx', 'create', lxPayload(), function (errors) {
        t.ok(!errors, 'valid payload: ' + JSON.stringify(errors));
        t.end();
    });
});

[
    '8.8.8.0/24',
    '10.88.0.1/24',
    '10.88.0.0/25',
    '10.088.0.0/24',
    'not-a-network'
].forEach(function (subnet) {
    test('reject LX private subnet ' + subnet, function (t) {
        var payload = lxPayload();

        payload.lx_private_network_subnet = subnet;
        VM.validate('lx', 'create', payload, function (errors) {
            t.ok(errors, 'invalid payload is rejected');
            t.ok(errors && errors.bad_values.indexOf(
                'lx_private_network_subnet') !== -1,
                'subnet is reported as invalid: ' + JSON.stringify(errors));
            t.end();
        });
    });
});

test('private network requires an egress link', function (t) {
    var payload = lxPayload();

    delete payload.lx_private_network_egress;
    VM.validate('lx', 'create', payload, function (errors) {
        t.ok(errors, 'missing egress is rejected');
        t.ok(errors && errors.missing_properties.indexOf(
            'lx_private_network_egress') !== -1,
            'egress is reported missing: ' + JSON.stringify(errors));
        t.end();
    });
});

test('private network requires a subnet', function (t) {
    var payload = lxPayload();

    delete payload.lx_private_network_subnet;
    VM.validate('lx', 'create', payload, function (errors) {
        t.ok(errors, 'missing subnet is rejected');
        t.ok(errors && errors.missing_properties.indexOf(
            'lx_private_network_subnet') !== -1,
            'subnet is reported missing: ' + JSON.stringify(errors));
        t.end();
    });
});

test('private network link count is bounded', function (t) {
    var payload = lxPayload();

    payload.lx_private_network_links = 33;
    VM.validate('lx', 'create', payload, function (errors) {
        t.ok(errors, 'oversized pool is rejected');
        t.ok(errors && errors.bad_values.indexOf(
            'lx_private_network_links') !== -1,
            'link count is reported invalid: ' + JSON.stringify(errors));
        t.end();
    });
});

test('private network properties are LX-only', function (t) {
    VM.validate('joyent', 'update', {lx_private_network: true},
        function (errors) {
            t.ok(errors, 'non-LX property is rejected');
            t.ok(errors && errors.bad_properties.indexOf(
                'lx_private_network') !== -1,
                'property is reported invalid: ' + JSON.stringify(errors));
            t.end();
        });
});
