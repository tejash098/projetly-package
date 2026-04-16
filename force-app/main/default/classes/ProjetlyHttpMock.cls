@isTest
global class ProjetlyHttpMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        System.assertNotEquals(null, req.getHeader('x-sf-request-id'));
        System.assertEquals(16, req.getHeader('x-sf-request-id').length());

        System.assertNotEquals(null, req.getHeader('x-sf-timestamp'));
        System.assert(Long.valueOf(req.getHeader('x-sf-timestamp')) > 0, 'x-sf-timestamp must be epoch ms');

        System.assertNotEquals(null, req.getHeader('x-sf-signature'));

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"status":true}');
        return res;
    }
}