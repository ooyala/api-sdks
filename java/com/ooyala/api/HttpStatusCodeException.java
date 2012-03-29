package com.ooyala.api;

public class HttpStatusCodeException extends Exception {
    private String response;
    private int code;
    
    protected static final long serialVersionUID = 1;

    public HttpStatusCodeException(String response, int code) {
        super(response);
        this.response = response;
        this.code = code;
    }

    public String getResponse() { return response; }
    public int getCode() { return code; }
    public void printError() { System.out.println(String.format("HTTP Status Code: %d Message: %s", code, response)); }
}
