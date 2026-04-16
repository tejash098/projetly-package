@isTest
global class ProjetlyHttpMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        System.assertNotEquals(null, req.getHeader('x-sf-request-id'));
        System.assertEquals(16, req.getHeader('x-sf-request-id').length());

        System.assertNotEquals(null, req.getHeader('x-sf-timestamp'));
        System.assert(req.getHeader('x-sf-timestamp').contains('T'));

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"status":true}');
        return res;
    }
}