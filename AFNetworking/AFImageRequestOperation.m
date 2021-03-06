// AFImageRequestOperation.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFImageRequestOperation.h"
#import "AFImageCache.h"
#if __IPHONE_OS_VERSION_MIN_REQUIRED
typedef UIImage AFImage;
#elif __MAC_OS_X_VERSION_MIN_REQUIRED
typedef NSImage AFImage;
#endif

@interface AFImageRequestOperation ()
@property (readwrite, nonatomic, retain) AFImage *responseImage;

+ (NSSet *)defaultAcceptableContentTypes;
+ (NSSet *)defaultAcceptablePathExtensions;
@end

@implementation AFImageRequestOperation
@synthesize responseImage = _responseImage;
@synthesize imageProcessingBlock=_imageProcessingBlock;
@synthesize cacheName=_cacheName;

+ (AFImageRequestOperation *)imageRequestOperationWithRequest:(NSURLRequest *)urlRequest                
                                                      success:(void (^)(AFImage *image))success
{
    return [self imageRequestOperationWithRequest:urlRequest imageProcessingBlock:nil cacheName:nil success:^(NSURLRequest __unused *request, NSHTTPURLResponse __unused *response, AFImage *image) {
        if (success) {
            success(image);
        }
    } failure:nil];
}


+ (AFImageRequestOperation *)imageRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                         imageProcessingBlock:(AFImage *(^)(AFImage *))imageProcessingBlock
                                                    cacheName:(NSString *)cacheNameOrNil
                                                      success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, AFImage *image))success
                                                      failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    AFImageRequestOperation *operation = [[[AFImageRequestOperation alloc] initWithRequest:urlRequest] autorelease];
    
    operation.cacheName = cacheNameOrNil;
    operation.responseProcessedBlock  = ^ {
        if (operation.error) {
            if (failure) {
                failure(operation.request, operation.response, operation.error);
            }
        } else {                
            
            if (success) {
                success(operation.request, operation.response, operation.responseImage);
            }
        }   
    };
    
    return operation;
}


+ (NSSet *)defaultAcceptableContentTypes {
    return [NSSet setWithObjects:@"image/tiff", @"image/jpeg", @"image/gif", @"image/png", @"image/ico", @"image/x-icon" @"image/bmp", @"image/x-bmp", @"image/x-xbitmap", @"image/x-win-bitmap", nil];
}

+ (NSSet *)defaultAcceptablePathExtensions {
    return [NSSet setWithObjects:@"tif", @"tiff", @"jpg", @"jpeg", @"gif", @"png", @"ico", @"bmp", @"cur", nil];
}

- (id)initWithRequest:(NSURLRequest *)urlRequest {
    self = [super initWithRequest:urlRequest];
    if (!self) {
        return nil;
    }
    
    self.acceptableContentTypes = [[self class] defaultAcceptableContentTypes];
    
    self.responseProcessedBlock = ^{
        
    };
    
    return self;
}

- (void)processResponse {
    if (!_responseImage && [self isFinished]) {
        if ([[UIScreen mainScreen] scale] == 2.0) {
            CGImageRef imageRef = [[UIImage imageWithData:self.responseData] CGImage];
            //This seems like the wrong way to handle this. shouldn't the guy at the end handle this?
            self.responseImage = [UIImage imageWithCGImage:imageRef scale:2.0 orientation:UIImageOrientationUp];
        } else {
            self.responseImage = [UIImage imageWithData:self.responseData]; 
        }
        
        if (self.imageProcessingBlock) {
            self.responseImage = self.imageProcessingBlock(self.responseImage);
        }
        
        if ([self.request cachePolicy] != NSURLCacheStorageNotAllowed) {
            [[AFImageCache sharedImageCache] cacheImageData:self.responseData forURL:[self.request URL] cacheName:self.cacheName];
        }
    }
}

- (void)dealloc {
    [_imageProcessingBlock release];
    [_cacheName release];
    [_responseImage release];
    [super dealloc];
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED
//synthized method is enough
#elif __MAC_OS_X_VERSION_MIN_REQUIRED 
- (NSImage *)responseImage {
    if (!_responseImage && [self isFinished]) {
        self.responseImage = [[[NSImage alloc] initWithData:self.responseData] autorelease];
    }
    
    return [[_responseImage retain] autorelease];
}
#endif

#pragma mark - AFHTTPClientOperation

+ (BOOL)canProcessRequest:(NSURLRequest *)request {
    return [[self defaultAcceptableContentTypes] containsObject:[request valueForHTTPHeaderField:@"Accept"]] || [[self defaultAcceptablePathExtensions] containsObject:[[request URL] pathExtension]];
}

//? why.
+ (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                    success:(void (^)(id object))success 
                                                    failure:(void (^)(NSHTTPURLResponse *response, NSError *error))failure
{
    return [self imageRequestOperationWithRequest:urlRequest imageProcessingBlock:nil cacheName:nil success:^(NSURLRequest __unused *request, NSHTTPURLResponse __unused *response, AFImage *image) {
        success(image);
    } failure:^(NSURLRequest __unused *request, NSHTTPURLResponse *response, NSError *error) {
        failure(response, error);
    }];
}


@end
