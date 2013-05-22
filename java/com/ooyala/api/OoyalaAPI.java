/**
 * Copyright 2011 © Ooyala, Inc.  All rights reserved.
 * 
 * Ooyala, Inc. (“Ooyala”) hereby grants permission, free of charge, to any person or entity obtaining a copy of the software code provided in source code format via this webpage and direct links contained within this webpage and any associated documentation (collectively, the "Software"), to use, copy, modify, merge, and/or publish the Software and, subject to pass-through of all terms and conditions hereof, permission to transfer, distribute and sublicense the Software; all of the foregoing subject to the following terms and conditions:
 * 
 * 1.  The above copyright notice and this permission notice shall be included in all copies or portions of the Software.
 * 
 * 2.   For purposes of clarity, the Software does not include any APIs, but instead consists of code that may be used in conjunction with APIs that may be provided by Ooyala pursuant to a separate written agreement subject to fees.  
 * 
 * 3.   Ooyala may in its sole discretion maintain and/or update the Software.  However, the Software is provided without any promise or obligation of support, maintenance or update.  
 * 
 * 4.  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, RELATING TO, ARISING FROM, IN CONNECTION WITH, OR INCIDENTAL TO THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * 
 * 5.   TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, (i) IN NO EVENT SHALL OOYALA BE LIABLE FOR ANY CONSEQUENTIAL, INCIDENTAL, INDIRECT, SPECIAL, PUNITIVE, OR OTHER DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) RELATING TO, ARISING FROM, IN CONNECTION WITH, OR INCIDENTAL TO THE SOFTWARE OR THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF OOYALA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES, AND (ii) OOYALA’S TOTAL AGGREGATE LIABILITY RELATING TO, ARISING FROM, IN CONNECTION WITH, OR INCIDENTAL TO THE SOFTWARE SHALL BE LIMITED TO THE ACTUAL DIRECT DAMAGES INCURRED UP TO MAXIMUM AMOUNT OF FIFTY DOLLARS ($50).
*/

package com.ooyala.api;

import java.util.Collections;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Vector;
import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.net.URLEncoder;
import java.io.IOException;

import org.apache.commons.codec.binary.Base64;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.ResponseHandler;
import org.apache.http.entity.AbstractHttpEntity;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.apache.http.client.methods.HttpDelete;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpPut;
import org.apache.http.client.methods.HttpRequestBase;

import org.json.simple.JSONValue;
import org.json.simple.parser.ContainerFactory;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

/**
 * The OoyalaAPI class implements methods to call the V2 Ooyala API.
 * 
 * It uses the Simple.JSON Java library to parse JSON (see: http://code.google.com/p/json-simple/)
 * 
 * Please keep in mind that when creating your HashMap to send the JSON body, align to using Maps and Lists as the Simple.JSON library indicates.
 * */
public class OoyalaAPI {

    /**
     * the Secret key
     */
    private  String secretKey;

    /**
     * The API key
     */
    private  String apiKey;

    /**
     * HttpPatch class which allows PATCH requests
     */
    private  class HttpPatch extends HttpPost {
        public HttpPatch(String s) { super(s); }
        public String getMethod() { return "PATCH"; }
    }

    /**
     * Base URL to Ooyala API
     */
    private String baseURL;

    /**
     * Holds the instance of a BASE64 encoder for performance.
     */
    private  Base64 base64Encoder;

    /**
     * Represents the HTTP Status Code from the last response
     */
    private  int responseCode;

    /**
     * Value (in seconds) which indicates the (time) 'window' where the request remains valid. Defaults: 15
     */
    public  long expirationWindow;

    /**
     * Round-up time value. Defaults: 300
     */
    public  long roundUpTime;

    /**
     * The request's content type
     */
    private String contentType;

    /**
     * Constructor with keys
     * @param apiKey The API key
     * @param secretKey The secret key
     */
    public OoyalaAPI(String _apiKey, String _secretKey) {
        secretKey = _secretKey;
        apiKey = _apiKey;
        baseURL = "https://api.ooyala.com/v2/";
        expirationWindow = 15;
        roundUpTime = 300;
        base64Encoder = new Base64();
        contentType = "application/json";
    }

    /**
     * Gets the Secret key
     * @return the secret key
     */
    public String getSecretKey() { return secretKey; }

    /**
     * Gets the API key
     * @return the API key
     */
    public String getAPIKey() { return apiKey; }

    /**
     * Sets the secret key
     * @param secretKey The secret key to be set
     */
    public void setSecretKey(String secretKey) { this.secretKey = secretKey; }

    /**
     * Sets the API key
     * @param apiKey The secret key to be set
     */
    public void setAPIKey(String apiKey) { this.apiKey = apiKey; }

    /**
     * Gets the URL where requests are sent
     * @return the URL
     */
    public String getBaseURL() { return baseURL; }

    /**
     * Sets the URL where requests are sent
     * @param baseURL The URL to be set
     * @return
     */
    public void setBaseURL(String baseURL) { this.baseURL = baseURL; }

    /**
     * Get the response code from previous request
     * @return
     */
    public int getResponseCode() { return responseCode; }

    /**
     * Get expiration date (in seconds).
     * @return the expiration date in seconds
     */
    public long getExpiration() {
        long nowPlusWindow = System.currentTimeMillis()/1000 + expirationWindow;
        long roundUp = roundUpTime - (nowPlusWindow % roundUpTime);
        return (nowPlusWindow + roundUp);
    }

    /**
     * Get the request's content type
     * @return The request's content type
     */
    public String getContentType() { return contentType; }

    /**
     * Set the request's content type
     * @param contentType The request's content type
     */
    public void setContentType(String contentType) { this.contentType = contentType; }

    /**
     * Concatenates the key-values of parameters using a separator in between
     *
     * @param parameters HashMap with the key-value elements to be concatenated
     * @param separator The separator (a char) which is added between hash elements
     * @return the concatenated string
     */
    private String concatenateParams(HashMap<String, String> parameters, String separator) {
        Vector<String> keys = new Vector<String>(parameters.keySet());
        Collections.sort(keys);

        String string = ""; 
        for (Enumeration<String> e = keys.elements(); e.hasMoreElements();) {
            String key    = (String)e.nextElement();
            String value  = (String)parameters.get(key);
            if (!string.isEmpty())
                string += separator;
            string += key + "=" + value;
        }
        return string;
    }

    /**
     * Encodes a String to be URI friendly.
     * @param input The String to encode.
     * @return The encoded String.
     * @throws java.io.UnsupportedEncodingException if the encoding as US-ASCII is not supported.
     */
    private String encodeURI(String input) throws java.io.UnsupportedEncodingException {
        return URLEncoder.encode(input, "US-ASCII");
    }

    /**
     * Generates the signature for a request, using a body in the request.
     * If the method is a GET, then it does not need the body. On the other hand
     * if it is a POST, PUT or PATCH, the body is a string with the parameters that
     * are going to be modified, or assigned to the resource.
     * This should be later added to the query parameters,
     * as the signature parameter of the desired requested URI.
     *
     * @param HTTPMethod The method of the request (GET, POST, PUT, PATCH).
     * @param requestPath The path of the request (i.e. /v2/players).
     * @param parameters The query parameters.
     * @param requestBody The body of the request, used for POST, PUT and PATCH.
     * @return The signature that should be added to the request URI as the signature parameter.
     * @throws NoSuchAlgorithmException if the SHA256 algorithm is not available.
     * @throws IOException 
     * @throws JsonMappingException 
     * @throws JsonGenerationException 
     */

    public String generateSignature(String HTTPMethod, String requestPath, HashMap<String, String> parameters, String requestBody) throws NoSuchAlgorithmException, IOException {
        String stringToSign = secretKey + HTTPMethod + "/v2/" + requestPath;
        stringToSign += concatenateParams(parameters, "");
        stringToSign += requestBody;
        MessageDigest digestProvider = MessageDigest.getInstance("SHA-256");
        digestProvider.reset();

        byte[] digest = digestProvider.digest(stringToSign.getBytes());
        String signedInput = base64Encoder.encodeBase64String(digest);

        return encodeURI(signedInput.substring(0, 43));
    }

    /**
     * Generates the signature for a request without a body
     *
     * @param HTTPMethod The method of the request (GET, POST, PUT, PATCH).
     * @param requestPath The path of the request (i.e. /v2/players).
     * @param parameters The query parameters.
     * @return The signature that should be added to the request URI as the signature parameter.
     * @throws NoSuchAlgorithmException if the SHA256 algorithm is not available.
     * @throws IOException 
     * @throws JsonMappingException 
     * @throws JsonGenerationException 
     */
    public String generateSignature(String HTTPMethod, String requestPath, HashMap<String, String> parameters) throws NoSuchAlgorithmException, IOException {
        return generateSignature(HTTPMethod, requestPath, parameters, null);
    }

    /**
     * Response Handler
     * @return
     */
    private ResponseHandler<String> createResponseHandler() {
        return new ResponseHandler<String>() {
            public String handleResponse(HttpResponse response) throws ClientProtocolException, IOException {
                HttpEntity entity = response.getEntity();
                responseCode = response.getStatusLine().getStatusCode();
                if (entity != null) {
                    return EntityUtils.toString(entity);
                } else {
                    return null;
                }
            }
        };
    }

    /**
     * Sends a Request to the URL using the indicating HTTP method, content type and the array of bytes as body 
     * @param HTTPMethod The HTTPMethod
     * @param URL The URL where the request is made
     * @param contentType The request's content type
     * @param requestBody The request's body as an array of bytes
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws ClientProtocolException
     * @throws IOException
     * @throws HttpStatusCodeException 
     */
    public Object sendRequest(String HTTPMethod, String URL, byte[] requestBody) throws ClientProtocolException, IOException, HttpStatusCodeException {
        HttpRequestBase method = getHttpMethod(HTTPMethod, URL, new ByteArrayEntity(requestBody));
        return executeRequest(method);
    }

    /**
     * Creates a request to a given path using the indicated HTTP-Method with a (string) body 
     *
     * @param HTTPMethod The HTTP method (verb)
     * @param requestPath The request path
     * @param parameters The query parameters 
     * @param requestBody The request's body
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws NoSuchAlgorithmException 
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws HttpStatusCodeException 
     */
    @SuppressWarnings("rawtypes")
	public Object sendRequest(String HTTPMethod, String requestPath, HashMap<String, String> parameters, HashMap<String, Object> requestBody) throws NoSuchAlgorithmException, ClientProtocolException, IOException, HttpStatusCodeException{
    	String jsonBody = "";
    	
    	if(requestBody != null && !requestBody.keySet().isEmpty()){
    		jsonBody = JSONValue.toJSONString((Map)requestBody);
    	}
    	
        String url = generateURLWithAuthenticationParameters(HTTPMethod, requestPath, parameters, jsonBody);
        
        HttpRequestBase method = getHttpMethod(HTTPMethod,url, new StringEntity(jsonBody));
        return executeRequest(method);
    }

    /**
     * Creates a request to a given path (requestPath) using the indicated HTTP-Method (HTTPMethod) wit neither
     * parameters nor a body (requestBody) 
     *
     * @param HTTPMethod The HTTP method
     * @param requestPath the request path
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws NoSuchAlgorithmException 
     * @throws HttpStatusCodeException 
     */
    public Object sendRequest(String HTTPMethod, String requestPath) throws ClientProtocolException, IOException, NoSuchAlgorithmException, HttpStatusCodeException {
        return sendRequest(HTTPMethod, requestPath, new HashMap<String, String>(), new HashMap<String, Object>());
    }

    /**
     * Creates an instance of HttpRequestBase's subclass (HttpGet, HttpDelete, etc).
     * @param HTTPMethod The HTTPMethod string name
     * @param URL The URL
     * @param entity the entity carrying the request's content
     * @return An instance of a HttpRequestBase's subclass
     */
    private HttpRequestBase getHttpMethod(String HTTPMethod, String URL, AbstractHttpEntity entity) {
        HttpRequestBase method = null;
        entity.setContentType(contentType);
        /* create the method object */
        if (HTTPMethod.toLowerCase().contentEquals("get")) {
            method = new HttpGet(URL);
        } else if (HTTPMethod.toLowerCase().contentEquals("delete")) {
            method = new HttpDelete(URL);
        } else {
            if (HTTPMethod.toLowerCase().contentEquals("post")) {
            method = new HttpPost(URL);
                ((HttpPost) method).setEntity(entity);
            } else if (HTTPMethod.toLowerCase().contentEquals("patch")) { 
                method = new HttpPatch(URL);
                ((HttpPatch) method).setEntity(entity);
            } else if (HTTPMethod.toLowerCase().contentEquals("put")) {
                method = new HttpPut(URL);
                ((HttpPut) method).setEntity(entity);
            }
        }
        return method;
    }

    /**
     * Generate the URL including the authentication parameters
     * @param HTTPMethod The HTTP Method
     * @param requestPath The request's path
     * @param parameters The query parameters
     * @param requestBody The string request body
     * @return
     * @throws NoSuchAlgorithmException
     * @throws IOException 
     * @throws JsonMappingException 
     * @throws JsonGenerationException 
     */
    @SuppressWarnings("unchecked")
    private String generateURLWithAuthenticationParameters(String HTTPMethod, String requestPath, HashMap<String, String> parameters, String requestBody) throws NoSuchAlgorithmException, IOException {
    	HashMap<String, String> parametersWithAuthentication = (HashMap<String, String>)parameters.clone();
    	parametersWithAuthentication.put("api_key", apiKey);
    	parametersWithAuthentication.put("expires", String.format("%d",getExpiration()));
    	String signature = generateSignature(HTTPMethod.toUpperCase(), requestPath, parametersWithAuthentication, requestBody);
    	parametersWithAuthentication.put("signature", signature);
        return buildURL(HTTPMethod, requestPath, parametersWithAuthentication);
    }

    /**
     * Executes the request
     * @param method The class containing the type of request (HttpGet, HttpDelete, etc)
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws ClientProtocolException
     * @throws IOException
     * @throws HttpStatusCodeException 
     */
    @SuppressWarnings("unchecked")
    private Object executeRequest(HttpRequestBase method) throws ClientProtocolException, IOException, HttpStatusCodeException {
        HttpClient httpclient = new DefaultHttpClient();
        String response = httpclient.execute(method, createResponseHandler());
        if (!isResponseOK())
            throw new HttpStatusCodeException(response, getResponseCode());
        
        if(response.isEmpty())
        	return null;
        
        JSONParser parser = new JSONParser();
        
        ContainerFactory containerFactory = new ContainerFactory(){
        	@SuppressWarnings("rawtypes")
			public List creatArrayContainer(){ return new LinkedList(); }
        	@SuppressWarnings("rawtypes")
			public java.util.Map createObjectContainer(){ return new LinkedHashMap(); }
        };
        
        //HashMap<String, Object> json = null;
        Object json = null;
        
		try {
			json = parser.parse(response, containerFactory);
		} catch (ParseException e) {
			e.printStackTrace();
		}
        
        return json;
    }

    /**
     * Creates a request to a given path using the indicated HTTP-Method with a (byte array) body 
     *
     * @param HTTPMethod The HTTP method (verb)
     * @param requestPath The request path
     * @param parameters The query parameters 
     * @param requestBody The request's body
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws NoSuchAlgorithmException 
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws HttpStatusCodeException 
     */
    public Object sendRequest(String HTTPMethod, String requestPath, HashMap<String, String> parameters, byte[] requestBody) throws NoSuchAlgorithmException, ClientProtocolException, IOException, HttpStatusCodeException {
        String url = generateURLWithAuthenticationParameters(HTTPMethod, requestPath, parameters, new String(requestBody));
        System.out.println(url);
        HttpRequestBase method = getHttpMethod(HTTPMethod,url, new ByteArrayEntity(requestBody));
        return executeRequest(method);
    }

    /**
     * URI encodes non-authentication values
     * @param parameters The hashtable containing values to URI encode
     * @return
     * @throws UnsupportedEncodingException
     */
    private HashMap<String,String> makeURIValues(HashMap<String,String> parameters) throws UnsupportedEncodingException {
        HashMap<String,String> URIParameters = new HashMap<String,String>();
        Set<String> set = parameters.keySet();
        Iterator<String> itr = set.iterator();
        while (itr.hasNext()) {
            String key = itr.next();
            String value = parameters.get(key);
            /* just URI encode non-authentication params*/
            if(!(key.equals("expires") || key.equals("api_key") || key.equals("signature"))) {
                URIParameters.put(key, encodeURI(parameters.get(key)));
            }
            else
                URIParameters.put(key, value);
        }
        return URIParameters;
    }

    /**
     * Builds the URL for a given request. In the process, it includes the api_key, expires and signature parameters
     * 
     * @param HTTPMethod The HTTP method
     * @param requestPath The request path
     * @param parameters The query parameters
     * @return The URL for a request.
     * @throws java.security.NoSuchAlgorithmException if the SHA256 algorithm is not
     *    available.
     * @throws java.io.UnsupportedEncodingException if the Base64 encoder is not able
     *    to generate an output.
     */
    public String buildURL(String HTTPMethod, String requestPath, HashMap<String, String> parameters) throws java.security.NoSuchAlgorithmException, java.io.UnsupportedEncodingException {
        return String.format("%s%s?%s", baseURL, requestPath, concatenateParams(makeURIValues(parameters),"&"));
     }

    /**
     * Sends a POST request
     * 
     * @param requestPath The request path
     * @param requestBody The request's body
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws NoSuchAlgorithmException 
     * @throws HttpStatusCodeException 
     */
    public Object postRequest(String requestPath, HashMap<String, Object> requestBody) throws ClientProtocolException, IOException, NoSuchAlgorithmException, HttpStatusCodeException {
        return sendRequest("POST", requestPath, new HashMap<String, String>(), requestBody);
    }
    
    /**
     * Sends a GET request
     * 
     * @param requestPath The request path
     * @param parameters hashtable containing query parameters
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws NoSuchAlgorithmException 
     * @throws HttpStatusCodeException 
     */
    public Object getRequest(String requestPath, HashMap<String, String> parameters) throws ClientProtocolException, IOException, NoSuchAlgorithmException, HttpStatusCodeException {
        return sendRequest("GET", requestPath, parameters, new HashMap<String, Object>());
    }

    /**
     * Sends a GET request
     * 
     * @param requestPath The request path
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws NoSuchAlgorithmException 
     * @throws HttpStatusCodeException 
     */
    public Object getRequest(String requestPath) throws ClientProtocolException, IOException, NoSuchAlgorithmException, HttpStatusCodeException {
        return sendRequest("GET", requestPath);
    }

    /**
     * Sends a PUT request
     *
     * @param requestPath The request path
     * @param requestBody The request's body
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws NoSuchAlgorithmException 
     * @throws HttpStatusCodeException 
     */
    public Object putRequest(String requestPath, HashMap<String, Object> requestBody) throws ClientProtocolException, IOException, NoSuchAlgorithmException, HttpStatusCodeException {
        return sendRequest("PUT", requestPath, new HashMap<String, String>(), requestBody);
    }

    /**
     * Sends a DELETE request
     * 
     * @param requestPath The request path
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws IOException 
     * @throws ClientProtocolException 
     * @throws NoSuchAlgorithmException 
     * @throws HttpStatusCodeException 
     */
    public Object deleteRequest(String requestPath) throws ClientProtocolException, IOException, NoSuchAlgorithmException, HttpStatusCodeException {
        return sendRequest("DELETE", requestPath);
    }

    
    /**
     * Sends a PATCH request
     * 
     * @param requestPath The request path
     * @param requestBody The patch to be sent
     * @return The response from the server as an object of class Object. Must be casted to either a LinkedList<String> or an HashMap<String, Object>
     * @throws ClientProtocolException
     * @throws IOException
     * @throws NoSuchAlgorithmException 
     * @throws HttpStatusCodeException 
     */
    public Object patchRequest(String requestPath, HashMap<String, Object> requestBody) throws ClientProtocolException, IOException, NoSuchAlgorithmException, HttpStatusCodeException {
        return sendRequest("PATCH", requestPath, new HashMap<String, String>(), requestBody);
    }

    /**
     * Indicates if a request was successful 
     * @return
     */
    public boolean isResponseOK() { return ((responseCode >= 200) && (responseCode < 400)); }
}
