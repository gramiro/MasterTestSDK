//
//  RMLinkedInSDK.m
//  MasterShareSDK
//
//  Created by Ramiro Guerrero & Marco Graciano on 5/2/13.
//    Copyright (c) 2013 Weston McBride
//
//    Permission is hereby granted, free of charge, to any
//    person obtaining a copy of this software and associated
//    documentation files (the "Software"), to deal in the
//    Software without restriction, including without limitation
//    the rights to use, copy, modify, merge, publish,
//    distribute, sublicense, and/or sell copies of the
//    Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice
//    shall be included in all copies or substantial portions of
//    the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
//    KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//    WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
//    PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//    OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//    OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//    OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "RMLinkedInSDK.h"
#import "AFXMLRequestOperation.h"

static NSString * const kOAuth2BaseURLString = @"https://www.linkedin.com/uas/oauth2/";
static NSString * const kServerAPIURL = @"https://api.linkedin.com/v1/";
static NSString * const kClientIDString = @"i1v2u6bu41lm";//FILL IN WITH YOUR OWN API KEY
static NSString * const kClientSecretString = @"RhiuoIbwBqA7qflg";//FILL IN WITH YOUR OWN API SECRET

@implementation RMLinkedInSDK
@synthesize params = _params;
@synthesize credential = _credential;

+ (RMLinkedInSDK *)sharedClient {
    static RMLinkedInSDK *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *url = [NSURL URLWithString:kOAuth2BaseURLString];
        _sharedClient = [RMLinkedInSDK clientWithBaseURL:url clientID:kClientIDString secret:kClientSecretString];
        
        _sharedClient.credential = [AFOAuthCredential retrieveCredentialWithIdentifier:_sharedClient.serviceProviderIdentifier];
        if (_sharedClient.credential != nil) {
            [_sharedClient setAuthorizationHeaderWithCredential:_sharedClient.credential];
        }
        
        
    });
    
    return _sharedClient;
}



-(void)authenticateWithScopes:(NSString *)scopes{
    
    [self authenticateUsingOAuthWithPath:@"authorization" scope:scopes redirectURI:@"http://www.google.com" success:^(AFOAuthCredential *credential) {
        
        NSLog(@"SUCCESS");
        
    } failure:^(NSError *error) {
        
        NSLog(@"FAILURE");

    }];
}

- (void)authenticateUsingOAuthWithPath:(NSString *)path
                                 scope:(NSString *)scope
                           redirectURI:(NSString *)uri
                               success:(void (^)(AFOAuthCredential *credential))success
                               failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:scope forKey:@"scope"];
    [mutableParameters setValue:uri forKey:@"redirect_uri"];
    [mutableParameters setValue:@"code" forKey:@"response_type"];
    [mutableParameters setValue:@"GFQWWEFrew5613379541ds" forKey:@"state"];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self authenticateUsingOAuthWithPath:path parameters:parameters success:success failure:failure];
}

- (void)authenticateUsingOAuthWithPath:(NSString *)path
                            parameters:(NSDictionary *)parameters
                               success:(void (^)(AFOAuthCredential *credential))success
                               failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [mutableParameters setObject:self.clientID forKey:@"client_id"];
    parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self clearAuthorizationHeader];
    
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:parameters];
    
    NSLog(@"REQUEST URL :%@", request.URL);
    
    self.webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 460)];
    self.webView.delegate = self;
    [self.webView loadRequest:request];

}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    NSURL *currentURL = self.webView.request.mainDocumentURL;
    NSLog(@"URL: %@", currentURL);
    
    NSString *query = [currentURL query];
    self.params = [self parseURLParams:query];
    NSString *code = [self.params valueForKey:@"code"];
    NSString *state = [self.params valueForKey:@"state"];
    
    if (![state isEqualToString:@"GFQWWEFrew5613379541ds"]) {
        NSLog(@"CSRF error.");
    }
    else {
        
        if (![code isEqualToString:@""]) {
            NSLog(@"CODE: %@", code);
            if (code.length > 0)
            {
                [self.webView removeFromSuperview];
                [self makeTokenRequestWithCode:code];
            }

        }
    }
}

- (NSDictionary*)parseURLParams:(NSString *)query {
	NSArray *pairs = [query componentsSeparatedByString:@"&"];
	NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
	for (NSString *pair in pairs) {
		NSArray *kv = [pair componentsSeparatedByString:@"="];
		NSString *val = [[kv objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
		[params setObject:val forKey:[kv objectAtIndex:0]];
	}
    return params;
}



-(void)makeTokenRequestWithCode:(NSString *)code{
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:code, @"code",
                            kClientIDString, @"client_id",
                            kClientSecretString, @"client_secret",
                            @"http://www.google.com", @"redirect_uri",
                            @"authorization_code", @"grant_type",nil];
    [self postPath:@"https://api.linkedin.com/uas/oauth2/accessToken" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        
        NSLog(@"Response: %@", json);
        
        NSString *accessToken = [json objectForKey:@"access_token"];
        //NSString *refresh_token = [json objectForKey:@"refresh_token"];
        //NSString *expires = [json objectForKey:@"expires_in"];
        
        
        if (accessToken)
        {
            self.credential = [AFOAuthCredential credentialWithOAuthToken:accessToken tokenType:nil];
            //[self.credential setRefreshToken:refresh_token expiration:[NSDate dateWithTimeIntervalSinceNow:[expires integerValue]]];
            
            [AFOAuthCredential storeCredential:self.credential withIdentifier:self.serviceProviderIdentifier];
            
            [self setAuthorizationHeaderWithCredential:self.credential];
            
            NSLog(@"ACCESS TOKEN: %@", self.credential.accessToken);
            
            //Store the accessToken on userDefaults
            [[NSUserDefaults standardUserDefaults] setObject:self.credential.accessToken forKey:@"accessToken"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [_loginDelegate performLinkedInLoginFromHandle];
        }
        else {
            NSString *errorReason = [self.params valueForKey:@"error_description"];

            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                message:errorReason
                                                               delegate:nil
                                                      cancelButtonTitle:@"Ok"
                                                      otherButtonTitles:nil];
            [alertView show];
        }
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"Token request error.");
    }];
}


//PEOPLE
//Profile API
-(void)getCurrentUserProfileWithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~", kServerAPIURL];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}


-(void)getUserProfileWithMemberId:(NSString *)memberID WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate{
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~", kServerAPIURL];
    }
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];

}


-(void)getUserProfileWithProfileURL:(NSString *)profileURL WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    static NSString * const kAFCharactersToBeEscaped = @":/?&=;+!@#$()~',*";
    static NSString * const kAFCharactersToLeaveUnescaped = @"[].";
    
	NSString * escapedProfileURL = (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)profileURL, (__bridge CFStringRef)kAFCharactersToLeaveUnescaped, (__bridge CFStringRef)kAFCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    
    NSLog(@"escaped string: %@", escapedProfileURL);
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~", kServerAPIURL];
    }
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}


//Connections API
-(void)getCurrentUserConnectionsWithParameters:(NSDictionary *)params WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~/connections%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~/connections", kServerAPIURL];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:params];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}


//People Search API
-(void)getPeopleSearchWithParameters:(NSDictionary *)params WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people-search%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people-search", kServerAPIURL];
    }

    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:params];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}


//GROUPS
//Groups API
-(void)getGroupProfileDetailsWithGroupId:(NSString *)groupID WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@groups/%@%@", kServerAPIURL, groupID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@groups/%@", kServerAPIURL, groupID];
    }
    
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}


-(void)getCurrentUserGroupMembershipsWithFieldSelectors:(NSString *)fieldSelectors WithParameters:(NSDictionary *)params AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~/group-memberships%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~/group-memberships", kServerAPIURL];
    }
    
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:params];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];

}


-(void)getCurrentUserShowGroupSettingsWithGroupId:(NSString *)groupID WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~/group-memberships/%@%@", kServerAPIURL, groupID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~/group-memberships/%@", kServerAPIURL, groupID];
    }
    
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];

}

#warning terminar y probar
-(void)putJoinGroupWithGroupId:(NSString *)groupID AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@people/~/group-memberships/%@", kServerAPIURL, groupID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self putPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);

    }];

}

#warning terminar y probar
-(void)deleteLeaveGroupWithGroupId:(NSString *)groupID AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    NSString *path = [NSString stringWithFormat:@"%@people/~/group-memberships/%@", kServerAPIURL, groupID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self deletePath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}


-(void)getGroupPostsWithGroupId:(NSString *)groupID WithParameters:(NSDictionary *)params WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@groups/%@/posts%@", kServerAPIURL, groupID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@groups/%@/posts", kServerAPIURL, groupID];
    }
    
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];

}


-(void)getCurrentUserGroupPostsWithGroupId:(NSString *)groupID WithParameters:(NSDictionary *)params WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~/group-memberships/%@/posts%@", kServerAPIURL, groupID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~/group-memberships/%@/posts", kServerAPIURL, groupID];
    }
    
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:params];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}


#warning terminar y probar
-(void)postCreateDiscussionPostInGroupWithGroupId:(NSString *)groupID WithBody:(NSString *)body AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
}


-(void)getPostDetailsWithPostId:(NSString *)postID WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@posts/%@%@", kServerAPIURL, postID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@posts/%@", kServerAPIURL, postID];
    }
    
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];

}


-(void)getPostCommentsWithPostId:(NSString *)postID WithFieldSelectors:(NSString *)fieldSelectors WithParameters:(NSDictionary *)params AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@posts/%@/comments%@", kServerAPIURL, postID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@posts/%@/comments", kServerAPIURL, postID];
    }
    
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:params];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}


#warning terminar y probar
-(void)putLikeUnlikePostWithPostId:(NSString *)postID WithIsLiked:(NSString *)isLiked AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@posts/%@/relation-to-viewer/is-liked", kServerAPIURL, postID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self putPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

#warning terminar y probar
-(void)putFollowUnfollowPostWithPostId:(NSString *)postID WithIsFollowing:(NSString *)isFollowing AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@posts/%@/relation-to-viewer/is-following", kServerAPIURL, postID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self putPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

#warning terminar y probar
-(void)putFlagPostWithPostId:(NSString *)postID WithFlag:(NSString *)flag AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@posts/%@/category/code", kServerAPIURL, postID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self putPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

#warning terminar y probar
-(void)deletePostOrFlagAsInappropriateWithPostId:(NSString *)postID AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@posts/%@", kServerAPIURL, postID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self deletePath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];
}

-(void)getCommentWithCommentId:(NSString *)commentID WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@comments/%@%@", kServerAPIURL, commentID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@comments/%@", kServerAPIURL, commentID];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];
}

#warning terminar y probar
-(void)postAddCommentToPostWithPostId:(NSString *)postID WithComment:(NSString *)comment AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@posts/%@/comments", kServerAPIURL, postID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self postPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

#warning terminar y probar
-(void)deleteCommentOrFlagAsInappropriateWithCommentId:(NSString *)commentID AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@comments/%@", kServerAPIURL, commentID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self deletePath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}


-(void)getCurrentUserSuggestedGroupsWithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    NSString *path;
    
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~/suggestions/groups%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~/suggestions/groups", kServerAPIURL];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];
}


-(void)deleteCurrentUserGroupSuggestionWithGroupId:(NSString *)groupID AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@people/~/suggestions/groups/%@", kServerAPIURL, groupID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    self.parameterEncoding = AFJSONParameterEncoding;
    
    [self deletePath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"SUCCESS");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}


//JOBS
//Job Lookup API
-(void)getJobDetailsWithJobId:(NSString *)jobID WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@jobs/%@%@", kServerAPIURL, jobID, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@jobs/%@", kServerAPIURL, jobID];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

//Job Bookmarks
-(void)getCurrentUserJobBookmarksWithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    NSString *path;
    
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~/job-bookmarks%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~/job-bookmarks", kServerAPIURL];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

#warning terminar y probar
-(void)postBookmarkJobWithJobId:(NSString *)jobID AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@people/~/job-bookmarks", kServerAPIURL];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self postPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

#warning terminar y probar
-(void)deleteJobBookmarkWithJobId:(NSString *)jobID AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path = [NSString stringWithFormat:@"%@people/~/job-bookmarks/%@", kServerAPIURL, jobID];
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self deletePath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"SUCCESS");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];
}


-(void)getCurrentUserJobSuggestionsWithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
    
    NSString *path;
    
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@people/~/suggestions/job-suggestions%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@people/~/suggestions/job-suggestions", kServerAPIURL];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}


-(void)getSearchJobWithParameters:(NSDictionary *)params WithFieldSelectors:(NSString *)fieldSelectors AndWithDelegate:(NSObject<LinkedInDelegate> *)delegate {
 
    NSString *path;
    
    if (fieldSelectors) {
        path = [NSString stringWithFormat:@"%@job-search%@", kServerAPIURL, fieldSelectors];
    }
    else {
        path = [NSString stringWithFormat:@"%@job-search", kServerAPIURL];
    }
    
    NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionary];
    [mutableParameters setValue:self.credential.accessToken forKey:@"oauth2_access_token"];
    [mutableParameters setValue:@"json" forKey:@"format"];
    NSDictionary *parameters = [NSDictionary dictionaryWithDictionary:mutableParameters];
    
    [self getPath:path parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
        NSLog(@"Response JSON: %@", json);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];

}

@end
