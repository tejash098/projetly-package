@isTest
global class ProjetlyHttpMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"status":"success"}');
        return res;
    }
}