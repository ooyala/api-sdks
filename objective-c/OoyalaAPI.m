//
//  OoyalaAPI.m
//  Objective-C
//
//  Created by Justino Mejorada on 8/22/11.
//  Copyright 2011 Ooyala, Inc. All rights reserved.
//

#import "OoyalaAPI.h"

// Default configuration

// The "Request Path" includes the "/v2/ part of the URL path for URL Signature generation.
static NSString *cacheAPIURLPath = @"http://cdn.api.ooyala.com"; 
static NSString *defaultAPIURLPath = @"https://api.ooyala.com"; 

static int roundingWindow = (int)300;
static NSTimeInterval configurationUploadRequestTimeout = 3600.0;
static NSTimeInterval configurationNormalRequestTimeout = 60.0;

/** 
 * Internal Implementation Helper Class - Not intended for direct use by the user.
 */
@interface OoyalaAPI()
+ (NSString *)URLEncodeString:(NSString *)string;
- (void)_requestToUploadFileByChunksWithParametersDictionary:(NSDictionary *)parametersDictionary;
@end

@implementation OoyalaAPI

@synthesize APIKey, secretKey,cancelUpload,numberOfChunks,numberOfChunksSucceeded,uploadProgressPercent;

#pragma mark -
#pragma mark Initialization

- (id)init
{
  
  return [self initWithKeySetName:nil];
}

- (id)initWithKeySetName:(NSString *)keySetName
{
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"OOConfiguration" ofType:@"plist"]];
  if(!keySetName) keySetName = [dictionary objectForKey:@"defaultKeySetName"];
  if(![[dictionary objectForKey:@"keySets"] objectForKey:keySetName]) return nil;
  return [self initWithAPIKey:[[[dictionary objectForKey:@"keySets"] objectForKey:keySetName] objectForKey:@"APIKey"] andSecretKey:[[[dictionary objectForKey:@"keySets"] objectForKey:keySetName] objectForKey:@"secretKey"]];
}

- (id)initWithAPIKey:(NSString *)APIKey andSecretKey:(NSString *)secretKey {
  if((self = [super init])){
    self.APIKey = APIKey;
    self.secretKey = secretKey;
  }
  return self;
}

+ (OoyalaAPI *)OoyalaAPIObject
{
  return [[[OoyalaAPI alloc]init]autorelease];
}

#pragma mark -
#pragma mark URL generation and signing

+ (NSString *)URLEncodeString:(NSString *)string
{
  CFTypeRef URLEncodedCFType = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8);
  NSString *URLEncodedString = [NSString stringWithFormat:@"%@",URLEncodedCFType];
  CFRelease(URLEncodedCFType);
  return URLEncodedString;
}

- (NSString *)generateEncodedSignatureWithHTTPMethod:(NSString *)HTTPMethod requestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters andRequestBody:(NSData *)requestBody
{

  // This function repeats some code found in generateEncodedSignedURLWithHTTPMethod with the intention
  // of being able to be called by itself and representing the entire singature generation process.
  
  //
  // Generate dataToSign
  //
  
  //Concatenate first parameters to stringToSign
  NSString *stringToSign = [NSString stringWithFormat:@"%@%@%@",[self secretKey],HTTPMethod,requestPath];
  
  //Generate mutable dictionary for parameters
  NSMutableDictionary *parametersDictionary = [NSMutableDictionary dictionaryWithDictionary:queryStringParameters];
  
  //Expires
  //Generate and add expires parameter if not already present
  //Default expires time: 5min = 300s
  if(![parametersDictionary objectForKey:@"expires"]){
    //Expires generation method remains according to V1:
    NSNumber *expiresWindow = [NSNumber numberWithInt:15];
    NSUInteger timestamp = (long)[[NSDate date] timeIntervalSince1970] + [expiresWindow intValue];
    timestamp += roundingWindow - (timestamp % roundingWindow );
    [parametersDictionary setValue:[NSString stringWithFormat:@"%d", timestamp] forKey:@"expires"];
  }

  //Add api_key parameter
  [parametersDictionary setValue:[NSString stringWithFormat:@"%@", [self APIKey]] forKey:@"api_key"];
  
  //Sort parameters and append to stringToSign
  NSArray *keys = [[parametersDictionary allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  for (NSUInteger i = 0; i < [keys count]; i++) {
    NSString *key = [keys objectAtIndex:i];
    NSString *value = [parametersDictionary objectForKey:key];
    stringToSign = [stringToSign stringByAppendingFormat:@"%@=%@", key, value];
  }
  
  //Append Body
  NSMutableData *dataToSign = [NSMutableData dataWithBytes:[stringToSign UTF8String] length:[stringToSign lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
  [dataToSign appendData:requestBody];
  
  
  //
  // Generate signature from dataToSign
  //
  
  unsigned char hashedChars[32];
  NSUInteger i;
  
  //Generate SHA-256 in Base64
  CC_SHA256([dataToSign bytes], [dataToSign length], hashedChars);
  NSData *hashedData = [NSData dataWithBytes:hashedChars length:32];
  Class _gtmBase64 = NSClassFromString(@"GTMBase64");
  if (!_gtmBase64){
    [NSException raise:@"OOMissingLibraryException" format:@"GTMBase64 is not pressent on the current Target. Add GTMBase64.h, GTMBase64.m and GTMDefines.h from the Google Toolbox for Mac (http://code.google.com/p/google-toolbox-for-mac/)"];
  }
  NSString *signature = [_gtmBase64 stringByEncodingBytes:[hashedData bytes] length:32];
  
  //Truncate signature to 43 characters
  signature = [signature substringToIndex:(NSUInteger)43]; 
  
  //Remove from signature trailing = signs, usign V1 method
  for (i = [signature length] - 1; [signature characterAtIndex:i] == '='; i = [signature length] - 1) {
    signature = [signature substringToIndex:i];
  }
  
  //URL-encode signature
  return [OoyalaAPI URLEncodeString:signature];
}



- (NSURL *)generateEncodedSignedURLWithHTTPMethod:(NSString *)HTTPMethod requestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters usingCacheURL:(BOOL)usingCacheURL andRequestBody:(NSData *)requestBody
{
  //Append first parts of URLString
  NSString *targetBaseURL;
  if(usingCacheURL){
    targetBaseURL = cacheAPIURLPath;
  }else{
    targetBaseURL = defaultAPIURLPath;
  }
  NSString *URLString = [NSString stringWithFormat:@"%@%@",targetBaseURL,requestPath];
  
  //Generate mutable dictionary for parameters
  NSMutableDictionary *parametersDictionary = [NSMutableDictionary dictionaryWithDictionary:queryStringParameters];
  
  //Expires
  //Generate and add expires parameter if not already present
  //Default expires time: 5min = 300s
  if(![parametersDictionary objectForKey:@"expires"]){
    //Expires generation method follows the same workflow as V1:
    NSNumber *expiresWindow = [NSNumber numberWithInt:15];
    NSUInteger timestamp = (long)[[NSDate date] timeIntervalSince1970] + [expiresWindow intValue];
    timestamp += roundingWindow - (timestamp % roundingWindow );
    [parametersDictionary setValue:[NSString stringWithFormat:@"%d", timestamp] forKey:@"expires"];
  }
  
  //Add api_key parameter
  [parametersDictionary setValue:[NSString stringWithFormat:@"%@", [self APIKey]] forKey:@"api_key"];
  
  //Sort parameters and append to URLString
  NSArray *keys = [[parametersDictionary allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  for (NSUInteger i = 0; i < [keys count]; i++) {
    NSString *key = [keys objectAtIndex:i];
    NSString *value = [parametersDictionary objectForKey:key];
    NSString *format = (i==0)?@"?%@=%@":@"&%@=%@";
    URLString = [URLString stringByAppendingFormat:format, [OoyalaAPI URLEncodeString:key], [OoyalaAPI URLEncodeString:value]];
  }

  //Append the signature
  URLString = [URLString stringByAppendingFormat:@"&signature=%@",[self generateEncodedSignatureWithHTTPMethod:HTTPMethod requestPath:requestPath queryStringParameters:queryStringParameters andRequestBody:requestBody]];
  
  return [NSURL URLWithString:URLString];
}

#pragma mark -
#pragma mark Sending Requests to Server

- (id)requestUsingHTTPMethod:(NSString *)HTTPMethod requestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters requestBody:(NSMutableDictionary *)requestBody useCache:(BOOL)useCache HTTPURLResponse:(NSHTTPURLResponse **)HTTPURLResponse andError:(NSError **)error
{

  NSData *requestBodyData = [[CJSONSerializer serializer] serializeObject:requestBody error:error];
  
  HTTPMethod = [HTTPMethod uppercaseString];
  
  if(![HTTPMethod isEqualToString:@"GET"]) useCache = NO;
  
  NSURL *URL = [self generateEncodedSignedURLWithHTTPMethod:HTTPMethod requestPath:[@"/v2/" stringByAppendingString:requestPath] queryStringParameters:queryStringParameters usingCacheURL:useCache andRequestBody:requestBodyData];
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:configurationNormalRequestTimeout];
  
  [request setHTTPMethod:HTTPMethod];
  [request setHTTPBody:requestBodyData];
  [request setValue:[NSString stringWithFormat:@"application/json"] forHTTPHeaderField:@"Content-Type"];

  NSData *returnedData = [NSURLConnection sendSynchronousRequest:request returningResponse:HTTPURLResponse error:error];
  
  // In almost all cases this object is an NSDictionary
  id returnedObject = [[CJSONDeserializer deserializer] deserialize:returnedData error:error];
  
  if([returnedObject isKindOfClass:[NSDictionary class]]){
    returnedObject = [NSMutableDictionary dictionaryWithDictionary:[[CJSONDeserializer deserializer] deserialize:returnedData error:error]];
  }
  
  return returnedObject;
}

- (id)GETWithRequestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters requestBody:(NSMutableDictionary *)requestBody useCache:(BOOL)useCache HTTPURLResponse:(NSHTTPURLResponse **)HTTPURLResponse andError:(NSError **)error
{
  return [self requestUsingHTTPMethod:@"GET" requestPath:requestPath queryStringParameters:queryStringParameters requestBody:requestBody useCache:useCache HTTPURLResponse:HTTPURLResponse andError:error];
}

- (id)POSTWithRequestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters requestBody:(NSMutableDictionary *)requestBody HTTPURLResponse:(NSHTTPURLResponse **)HTTPURLResponse andError:(NSError **)error
{
  return [self requestUsingHTTPMethod:@"POST" requestPath:requestPath queryStringParameters:queryStringParameters requestBody:requestBody useCache:NO HTTPURLResponse:HTTPURLResponse andError:error];
}

- (id)PUTWithRequestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters requestBody:(NSMutableDictionary *)requestBody HTTPURLResponse:(NSHTTPURLResponse **)HTTPURLResponse andError:(NSError **)error
{
  return [self requestUsingHTTPMethod:@"PUT" requestPath:requestPath queryStringParameters:queryStringParameters requestBody:requestBody useCache:NO HTTPURLResponse:HTTPURLResponse andError:error]; 
}

- (id)PATCHWithRequestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters requestBody:(NSMutableDictionary *)requestBody HTTPURLResponse:(NSHTTPURLResponse **)HTTPURLResponse andError:(NSError **)error
{
  return [self requestUsingHTTPMethod:@"PATCH" requestPath:requestPath queryStringParameters:queryStringParameters requestBody:requestBody useCache:NO HTTPURLResponse:HTTPURLResponse andError:error];
}

- (id)DELETEWithRequestPath:(NSString *)requestPath queryStringParameters:(NSDictionary *)queryStringParameters requestBody:(NSMutableDictionary *)requestBody HTTPURLResponse:(NSHTTPURLResponse **)HTTPURLResponse andError:(NSError **)error
{
  return [self requestUsingHTTPMethod:@"DELETE" requestPath:requestPath queryStringParameters:queryStringParameters requestBody:requestBody useCache:NO HTTPURLResponse:HTTPURLResponse andError:error];
}


#pragma mark -
#pragma mark Uploading Files to The Server

- (id)requestToUploadFileWithFilePath:(NSURL *)filePath HTTPMethod:(NSString *)HTTPMethod requestPathOrURLString:(NSString *)requestPathOrURLString queryStringParameters:(NSDictionary *)queryStringParameters HTTPURLResponse:(NSHTTPURLResponse **)HTTPURLResponse andError:(NSError **)error
{
  // Obtaining fileSize
  NSDictionary *fileProperties = [[NSFileManager defaultManager] attributesOfItemAtPath:[filePath path] error:nil];
  NSNumber *fileSize = [NSNumber numberWithLongLong:[[fileProperties objectForKey:@"NSFileSize"] longLongValue]];
  
  // Obtaining the fileHandle
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:[filePath path]];
  if (!fileHandle) return false;
  
  // Generating body
  NSData *data = [fileHandle readDataToEndOfFile];
  NSMutableData *bodyData = [NSMutableData dataWithData:data];
  
  // Obtaining the URL
  NSURL *URL = nil;
  if([[requestPathOrURLString substringToIndex:(NSUInteger)4] isEqualToString:@"http"]){
    URL = [NSURL URLWithString:requestPathOrURLString];
  }else{
    URL = [self generateEncodedSignedURLWithHTTPMethod:HTTPMethod requestPath:[@"/v2/" stringByAppendingString:requestPathOrURLString] queryStringParameters:queryStringParameters usingCacheURL:NO andRequestBody:bodyData];
  }
  
  // Creating the request
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:configurationUploadRequestTimeout];
  
  // Setting headers
  [request setValue:@"multipart/mixed" forHTTPHeaderField:@"Content-Type"];
  [request setValue:[NSString stringWithFormat:@"%d", [fileSize longLongValue]] forHTTPHeaderField:@"Content-Length"];
  [request setHTTPMethod:HTTPMethod];
  
  // Setting Body
	[request setHTTPBody:bodyData];
  
  // Sending the request
  NSData *returnedData =  [NSURLConnection sendSynchronousRequest:request returningResponse:HTTPURLResponse error:error];
  
  id returnedObject = [[CJSONDeserializer deserializer] deserialize:returnedData error:error];
  
  if([returnedObject isKindOfClass:[NSDictionary class]]){
    returnedObject = [NSMutableDictionary dictionaryWithDictionary:[[CJSONDeserializer deserializer] deserialize:returnedData error:error]];
  }
  
  return returnedObject;
  
}


- (BOOL)requestToUploadFileByChunksWithFilePath:(NSURL *)filePath HTTPMethod:(NSString *)HTTPMethod uploadingUrlsArrayOfStrings:(NSArray *)uploadingUrlsArrayOfStrings queryStringParameters:(NSDictionary *)queryStringParameters chunkSize:(NSNumber *)chunkSize maxConcurrentUploads:(NSNumber *)maxConcurrentUploads maxNumberOfRetries:(NSNumber *)maxNumberOfRetries
{
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
  [queue setName:@"ChunkUploadQueue"];
  [queue setMaxConcurrentOperationCount:(NSInteger)[maxConcurrentUploads integerValue]];
  
  NSUInteger chunksUploaded = 0;
  NSUInteger chunkCount = [uploadingUrlsArrayOfStrings count];
  [self setNumberOfChunks:[NSNumber numberWithUnsignedInteger:chunkCount]];
  [self setNumberOfChunksSucceeded:[NSNumber numberWithInt:0]];
  [self setUploadProgressPercent:[NSNumber numberWithFloat:0.0]];
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:[filePath path]];
  NSMutableArray *arrayOfChunks = [[[NSMutableArray alloc]init ]autorelease];
  
  NSHTTPURLResponse *HTTPURLResponse = [[[NSHTTPURLResponse alloc]init]autorelease];
  NSError *error = [[[NSError alloc]init]autorelease];
  
  for (NSUInteger i = 0; i < chunkCount; i++) {
    [arrayOfChunks insertObject:[NSData dataWithData:[fileHandle readDataOfLength:(NSUInteger)[chunkSize intValue]]] atIndex:i];
  }
  for (NSUInteger i = 0; i < chunkCount; i++) {
    [queue addOperationWithBlock:^{
      NSURL *url = [NSURL URLWithString:[uploadingUrlsArrayOfStrings objectAtIndex:i]];
      NSData *chunk = [arrayOfChunks objectAtIndex:i];
      if (!cancelUpload){
        NSUInteger numberOfTimesTried;
        for(numberOfTimesTried=0;([HTTPURLResponse statusCode]!=204)&&(numberOfTimesTried<[maxNumberOfRetries integerValue]);numberOfTimesTried++){
          if (!cancelUpload) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:configurationUploadRequestTimeout];
            
            [request setValue:@"multipart/mixed" forHTTPHeaderField:@"Content-Type"];
            [request setValue:[NSString stringWithFormat:@"%d",[chunk length]] forHTTPHeaderField:@"Content-Length"];
            [request setHTTPMethod:HTTPMethod];
            [request setHTTPBody:chunk];
            [NSURLConnection sendSynchronousRequest:request returningResponse:&HTTPURLResponse error:&error];
          }
        }
        if (numberOfTimesTried == [maxNumberOfRetries integerValue]) {
          cancelUpload = YES;
        }else{
          [self setNumberOfChunksSucceeded:[NSNumber numberWithUnsignedInt:([[self numberOfChunksSucceeded] intValue] +1)]]; 
          [self setUploadProgressPercent:[NSNumber numberWithFloat:([numberOfChunksSucceeded floatValue]/[numberOfChunks floatValue])]];
        }
      }
    }
    ];
  }
  [queue waitUntilAllOperationsAreFinished];
  [queue release];
  [pool release];
  return (cancelUpload?false:true);
}


- (void)requestToUploadFileAsynchronouslyByChunksWithFilePath:(NSURL *)filePath HTTPMethod:(NSString *)HTTPMethod uploadingUrlsArrayOfStrings:(NSArray *)uploadingUrlsArrayOfStrings queryStringParameters:(NSDictionary *)queryStringParameters chunkSize:(NSNumber *)chunkSize maxConcurrentUploads:(NSNumber *)maxConcurrentUploads maxNumberOfRetries:(NSNumber *)maxNumberOfRetries successBlock:(OOHelperSuccessBlock)successBlock failureBlock:(OOHelperFailureBlock)failureBlock assetObjectInstance:(id)assetObjectInstance setTheAssetStatusAtTheEnd:(BOOL)setTheAssetStatusAtTheEnd
{

  NSMutableDictionary *parametersDictionary = [[NSMutableDictionary alloc]init ];
  [parametersDictionary setValue:filePath forKey:@"filePath"];
  [parametersDictionary setValue:HTTPMethod forKey:@"HTTPMethod"];
  [parametersDictionary setValue:uploadingUrlsArrayOfStrings forKey:@"uploadingUrlsArrayOfStrings"];
  [parametersDictionary setValue:queryStringParameters forKey:@"queryStringParameters"];
  [parametersDictionary setValue:chunkSize forKey:@"chunkSize"];
  [parametersDictionary setValue:maxConcurrentUploads forKey:@"maxConcurrentUploads"];
  [parametersDictionary setValue:maxNumberOfRetries forKey:@"maxNumberOfRetries"];
  [parametersDictionary setValue:successBlock forKey:@"successBlock"];
  [parametersDictionary setValue:failureBlock forKey:@"failureBlock"];
  [parametersDictionary setValue:assetObjectInstance forKey:@"assetObjectInstance"];
  [parametersDictionary setValue:[NSNumber numberWithBool:setTheAssetStatusAtTheEnd] forKey:@"setTheAssetStatusAtTheEnd"];
  
  [self performSelectorInBackground:@selector(_requestToUploadFileByChunksWithParametersDictionary:) withObject:parametersDictionary];
  
}

- (void)_requestToUploadFileByChunksWithParametersDictionary:(NSDictionary *)parametersDictionary
{
  NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
  
  OOHelperSuccessBlock successObject = [parametersDictionary objectForKey:@"successBlock"];
  OOHelperFailureBlock failureObject = [parametersDictionary objectForKey:@"failureBlock"];
  if([self requestToUploadFileByChunksWithFilePath:[parametersDictionary objectForKey:@"filePath"] 
                                        HTTPMethod:[parametersDictionary objectForKey:@"HTTPMethod"] 
                       uploadingUrlsArrayOfStrings:[parametersDictionary objectForKey:@"uploadingUrlsArrayOfStrings"] 
                             queryStringParameters:[parametersDictionary objectForKey:@"queryStringParameters"] 
                                         chunkSize:[parametersDictionary objectForKey:@"chunkSize"] 
                              maxConcurrentUploads:[parametersDictionary objectForKey:@"maxConcurrentUploads"] 
                                maxNumberOfRetries:[parametersDictionary objectForKey:@"maxNumberOfRetries"]
      ]
     )
  {
    
    if(![[parametersDictionary objectForKey:@"setTheAssetStatusAtTheEnd"] boolValue]){
      successObject(@"Successfully uploaded file.");
    }else{
      
      // Set video status to uploaded
      
      id assetObject = [parametersDictionary objectForKey:@"assetObjectInstance"];
      [assetObject setStatus:@"uploaded"];
      NSData *jsonData = [NSData dataWithBytes:[@"{\"status\":\"uploaded\"}" UTF8String] length:[@"{\"status\":\"uploaded\"}" length]];
      NSHTTPURLResponse *response = nil;
      NSError *error = nil;
       
      [self PUTWithRequestPath:[NSString stringWithFormat:@"%@%@/upload_status",@"assets/",[assetObject resourceID]] queryStringParameters:[[[NSDictionary alloc]init]autorelease] requestBody:jsonData HTTPURLResponse:&response andError:&error];
      
      if([[assetObject OOResourceObject]_isResponseOk:response]){
        successObject(@"Successfully uploaded file and set the asset's status property to 'uploaded'.");
      }else{
        failureObject(@"Couldn't set the asset status property to uploaded, although the file was uploaded successfully.");
      }
    }
  }else{
    if(![[parametersDictionary objectForKey:@"setTheAssetStatusAtTheEnd"] boolValue]){
      failureObject(@"File couldn't be uploaded.");
    }else{
    
      // Set video status to failed
      
      id assetObject = [parametersDictionary objectForKey:@"assetObjectInstance"];
      [assetObject setStatus:@"failed"];
      NSData *jsonData = [NSData dataWithBytes:[@"{\"status\":\"failed\"}" UTF8String] length:[@"{\"status\":\"failed\"}" length]];
      
      NSHTTPURLResponse *response = nil;
      NSError *error = nil;    
      [self PUTWithRequestPath:[NSString stringWithFormat:@"%@%@/upload_status",@"assets/",[assetObject resourceID]] queryStringParameters:[[[NSDictionary alloc]init]autorelease] requestBody:jsonData HTTPURLResponse:&response andError:&error];
      
      if([[assetObject OOResourceObject]_isResponseOk:response]){
        // Were able to set the video status as failed 
        failureObject(@"File couldn't be uploaded, the asset status was set to failed."); 
      }else{
        // Weren't able to set the video status as failed
        failureObject(@"File coudn't be uploaded, and the asset status couldn't be set to failed");
      }
    }
    
  }
  [pool2 release];
}

#pragma mark -
#pragma mark Memory Management

- (void)dealloc {
  [APIKey release];
  [secretKey release];
  
  [numberOfChunksSucceeded release];
  [numberOfChunks release];
  [uploadProgressPercent release];
  
  [super dealloc];
}

@end
