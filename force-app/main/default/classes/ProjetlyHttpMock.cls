@isTest
global class ProjetlyHttpMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        System.assertNotEquals(null, req.getHeader('x-sf-request-id'));
        System.assertEquals(16, req.getHeader('x-sf-request-id').length());

        System.assertNotEquals(null, req.getHeader('x-sf-timestamp'));
        System.assert(Long.valueOf(req.getHeader('x-sf-timestamp')) > 0, 'x-sf-timestamp must be epoch ms');

        String signature = req.getHeader('x-sf-signature');
        System.assertNotEquals(null, signature, 'x-sf-signature header must be present');
        System.assert(signature.startsWith('sha256='), 'x-sf-signature must start with sha256=');
        // sha256= prefix (7 chars) + HmacSHA256 hex output (64 chars) = 71 chars
        System.assertEquals(71, signature.length(), 'x-sf-signature must be 71 characters');

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"status":true}');
        return res;
    }
}