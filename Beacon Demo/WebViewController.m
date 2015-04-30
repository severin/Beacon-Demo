//
//  WebViewController.m
//  Beacon Demo
//
//  Created by Severin Schoepke on 29/04/15.
//  Copyright (c) 2015 Shortcut Media AG. All rights reserved.
//

#import "WebViewController.h"

@interface WebViewController () <UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation WebViewController

- (void)setUrl:(NSURL *)url
{
    _url = url;
    
    if (self.webView) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:_url]];
    }
}

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    
    if (self) {
        self.url = url;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.webView.delegate = self;
    self.webView.hidden = YES;
    
    if (self.url) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.url]];
    }
}

#pragma mark - UIWebViewDelegate


- (void)webViewDidStartLoad:(UIWebView *)webView
{
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    webView.hidden = NO;
}

@end
